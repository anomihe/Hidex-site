// supabase/edge_functions/submit_hunt_answer.ts
//
// Server-side grading for treasure hunt tasks. This is what closes the
// known gap where `hunt_tasks.answer` was readable by any group member
// through RLS: the schema now revokes SELECT on that column for the
// `authenticated` role entirely (see schema.sql, "Grants & column
// privileges"), so grading MUST happen here, with the service role key,
// never on the client.
//
// Deploy: supabase functions deploy submit_hunt_answer
// Invoke: POST /functions/v1/submit_hunt_answer
//         { "task_id": "<uuid>", "answer": "user's guess" }
// Auth:   requires the caller's Supabase JWT (Authorization: Bearer <token>)

import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders, jsonResponse } from "./_shared/cors.ts";

function normalize(value: string): string {
  return value.trim().toLowerCase().replace(/\s+/g, " ");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return jsonResponse({ error: "Missing Authorization header" }, 401);
    }

    const { task_id, answer } = await req.json();
    if (!task_id || typeof answer !== "string") {
      return jsonResponse({ error: "task_id and answer are required" }, 400);
    }

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

    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    const { data: task, error: taskError } = await adminClient
      .from("hunt_tasks")
      .select("id, hunt_id, answer, points")
      .eq("id", task_id)
      .single();

    if (taskError || !task) {
      return jsonResponse({ error: "Task not found" }, 404);
    }

    const { data: hunt, error: huntError } = await adminClient
      .from("treasure_hunts")
      .select("id, group_id, status, ends_at")
      .eq("id", task.hunt_id)
      .single();

    if (huntError || !hunt) {
      return jsonResponse({ error: "Hunt not found" }, 404);
    }

    const { data: membership } = await adminClient
      .from("group_members")
      .select("user_id")
      .eq("group_id", hunt.group_id)
      .eq("user_id", user.id)
      .maybeSingle();

    if (!membership) {
      return jsonResponse({ error: "Not a member of this hunt's group" }, 403);
    }

    if (hunt.status !== "active") {
      return jsonResponse({ error: "This hunt is not currently active" }, 409);
    }

    const { data: existing } = await adminClient
      .from("hunt_progress")
      .select("id, is_correct, attempts")
      .eq("task_id", task_id)
      .eq("user_id", user.id)
      .maybeSingle();

    if (existing?.is_correct) {
      return jsonResponse({ is_correct: true, already_solved: true });
    }

    const isCorrect = normalize(answer) === normalize(task.answer);
    const attempts = (existing?.attempts ?? 0) + 1;

    const { error: progressError } = await adminClient
      .from("hunt_progress")
      .upsert(
        {
          id: existing?.id,
          hunt_id: hunt.id,
          task_id,
          user_id: user.id,
          is_correct: isCorrect,
          attempts,
          submitted_at: new Date().toISOString(),
        },
        { onConflict: "task_id,user_id" },
      );

    if (progressError) {
      return jsonResponse({ error: progressError.message }, 500);
    }

    if (isCorrect) {
      const { error: pointsError } = await adminClient.rpc(
        "award_hunt_points",
        { p_user_id: user.id, p_points: task.points },
      );
      if (pointsError) {
        return jsonResponse({ error: pointsError.message }, 500);
      }
    }

    return jsonResponse({
      is_correct: isCorrect,
      attempts,
      points_awarded: isCorrect ? task.points : 0,
    });
  } catch (err) {
    return jsonResponse(
      { error: err instanceof Error ? err.message : "Unexpected error" },
      500,
    );
  }
});
