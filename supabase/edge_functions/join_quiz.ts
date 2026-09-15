// supabase/edge_functions/join_quiz.ts
//
// Server-enforced quiz join window. Clients must call this function to
// join a live quiz instead of inserting into `quiz_participants`
// directly — the join window (starts_at - join_window_seconds .. starts_at)
// is only trustworthy when checked against the server's clock, not the
// device's.
//
// Deploy: supabase functions deploy join_quiz
// Invoke: POST /functions/v1/join_quiz  { "quiz_id": "<uuid>" }
// Auth:   requires the caller's Supabase JWT (Authorization: Bearer <token>)

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "./_shared/cors.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Missing Authorization header" }, 401);
    }

    const { quiz_id } = await req.json();
    if (!quiz_id || typeof quiz_id !== "string") {
      return jsonResponse({ error: "quiz_id is required" }, 400);
    }

    // Client bound to the caller's own JWT — used only to identify the
    // user and to check group membership through their own RLS view.
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const {
      data: { user },
      error: userError,
    } = await userClient.auth.getUser();

    if (userError || !user) {
      return jsonResponse({ error: "Invalid or expired session" }, 401);
    }

    // Service-role client — bypasses RLS so we can read the quiz row
    // and write the participant row with a server-verified timestamp.
    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: quiz, error: quizError } = await adminClient
      .from("quizzes")
      .select("id, group_id, starts_at, join_window_seconds, status")
      .eq("id", quiz_id)
      .single();

    if (quizError || !quiz) {
      return jsonResponse({ error: "Quiz not found" }, 404);
    }

    const { data: membership } = await adminClient
      .from("group_members")
      .select("user_id")
      .eq("group_id", quiz.group_id)
      .eq("user_id", user.id)
      .maybeSingle();

    if (!membership) {
      return jsonResponse({ error: "Not a member of this quiz's group" }, 403);
    }

    const now = new Date();
    const startsAt = new Date(quiz.starts_at);
    const joinOpensAt = new Date(
      startsAt.getTime() - quiz.join_window_seconds * 1000,
    );

    if (now < joinOpensAt) {
      return jsonResponse(
        {
          error: "Join window has not opened yet",
          join_opens_at: joinOpensAt.toISOString(),
        },
        409,
      );
    }

    if (now >= startsAt) {
      return jsonResponse(
        { error: "Join window has closed — quiz has already started" },
        409,
      );
    }

    const { data: participant, error: joinError } = await adminClient
      .from("quiz_participants")
      .upsert(
        { quiz_id: quiz.id, user_id: user.id },
        { onConflict: "quiz_id,user_id", ignoreDuplicates: true },
      )
      .select()
      .single();

    if (joinError) {
      return jsonResponse({ error: joinError.message }, 500);
    }

    return jsonResponse({ participant, quiz_starts_at: quiz.starts_at });
  } catch (err) {
    return jsonResponse(
      { error: err instanceof Error ? err.message : "Unexpected error" },
      500,
    );
  }
});
