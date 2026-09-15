// supabase/edge_functions/send_push.ts
//
// Fills the "no FCM send-side function yet" gap: device registration
// already writes to `device_tokens`, but nothing calls the FCM API.
// This function sends a push to every registered device for a given
// user (or list of users) using Firebase's HTTP v1 API.
//
// Deploy: supabase functions deploy send_push
// Invoke (service-to-service only — see auth note below):
//   POST /functions/v1/send_push
//   {
//     "user_ids": ["<uuid>", ...],
//     "title": "Quiz starting soon",
//     "body": "Your group's quiz opens for joining in 2 minutes",
//     "data": { "type": "quiz_join_open", "quiz_id": "<uuid>" }
//   }
//
// This function is meant to be called from other edge functions /
// triggers with the service role key, or from a scheduled job — NOT
// directly from client apps (it has no per-user authorization checks
// beyond "does this user have device tokens"). Restrict it further with
// a shared secret header if you expose it publicly.
//
// Required secrets (supabase secrets set ...):
//   FCM_SERVICE_ACCOUNT_JSON   — full JSON of a Firebase service account
//                                 with the "Firebase Cloud Messaging API"
//                                 role, as a single-line string
//   SUPABASE_URL
//   SUPABASE_SERVICE_ROLE_KEY

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "./_shared/cors.ts";

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

let cachedAccessToken: { token: string; expiresAt: number } | null = null;

// Minimal RS256 JWT signer + OAuth2 token exchange, so this function has
// no dependency beyond the Deno runtime's WebCrypto and the Supabase SDK.
async function getAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60) {
    return cachedAccessToken.token;
  }

  const header = { alg: "RS256", typ: "JWT" };
  const claims = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encode = (obj: unknown) =>
    btoa(JSON.stringify(obj)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const unsigned = `${encode(header)}.${encode(claims)}`;

  const pemBody = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const keyData = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsigned),
  );
  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const jwt = `${unsigned}.${encodedSignature}`;

  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenResponse.ok) {
    throw new Error(`OAuth token exchange failed: ${await tokenResponse.text()}`);
  }

  const tokenJson = await tokenResponse.json();
  cachedAccessToken = {
    token: tokenJson.access_token,
    expiresAt: now + tokenJson.expires_in,
  };
  return cachedAccessToken.token;
}

async function sendToToken(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string>,
): Promise<{ ok: boolean; token: string; error?: string }> {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          data,
        },
      }),
    },
  );

  if (res.ok) return { ok: true, token };
  return { ok: false, token, error: await res.text() };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { user_ids, title, body, data } = await req.json();

    if (!Array.isArray(user_ids) || user_ids.length === 0) {
      return jsonResponse({ error: "user_ids (non-empty array) is required" }, 400);
    }
    if (!title || !body) {
      return jsonResponse({ error: "title and body are required" }, 400);
    }

    const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
    if (!serviceAccountJson) {
      return jsonResponse({ error: "FCM_SERVICE_ACCOUNT_JSON is not configured" }, 500);
    }
    const serviceAccount: ServiceAccount = JSON.parse(serviceAccountJson);

    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: tokens, error: tokensError } = await adminClient
      .from("device_tokens")
      .select("fcm_token")
      .in("user_id", user_ids);

    if (tokensError) {
      return jsonResponse({ error: tokensError.message }, 500);
    }
    if (!tokens || tokens.length === 0) {
      return jsonResponse({ sent: 0, failed: 0, results: [] });
    }

    const accessToken = await getAccessToken(serviceAccount);
    const stringData: Record<string, string> = {};
    for (const [key, value] of Object.entries(data ?? {})) {
      stringData[key] = String(value);
    }

    const results = await Promise.all(
      tokens.map((t) =>
        sendToToken(accessToken, serviceAccount.project_id, t.fcm_token, title, body, stringData)
      ),
    );

    const sent = results.filter((r) => r.ok).length;
    const failed = results.length - sent;

    // Prune tokens FCM reports as no longer registered.
    const deadTokens = results.filter((r) => !r.ok && r.error?.includes("UNREGISTERED")).map((r) => r.token);
    if (deadTokens.length > 0) {
      await adminClient.from("device_tokens").delete().in("fcm_token", deadTokens);
    }

    return jsonResponse({ sent, failed, results });
  } catch (err) {
    return jsonResponse(
      { error: err instanceof Error ? err.message : "Unexpected error" },
      500,
    );
  }
});
