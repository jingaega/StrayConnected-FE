import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const notifyWebhookUrl = Deno.env.get("NOTIFY_WEBHOOK_URL") ?? undefined; // optional

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error("SUPABASE_URL or SUPABASE_ANON_KEY is not set");
}

type Action = "approve" | "reject" | "complete";

type RequestBody = {
  meetingId?: number;
  action?: Action;
  reason?: string;
  updateAnimal?: boolean; // set to false to skip auto-adopt on complete
};

type JsonValue =
  | string
  | number
  | boolean
  | null
  | JsonValue[]
  | { [key: string]: JsonValue };

function jsonResponse(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function logAudit(
  supabase: ReturnType<typeof createClient>,
  entry: {
    actorId: string;
    action: string;
    targetType: string;
    targetId: string | number;
    details?: Record<string, JsonValue>;
  },
) {
  const { error } = await supabase.from("audit_log").insert({
    actor_id: entry.actorId,
    action: entry.action,
    target_type: entry.targetType,
    target_id: entry.targetId,
    details: entry.details ?? {},
    created_at: new Date().toISOString(),
  });
  if (error) {
    console.error("Audit log insert failed", error);
  }
}

async function sendNotification(payload: Record<string, JsonValue>) {
  if (!notifyWebhookUrl) return;
  try {
    await fetch(notifyWebhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
  } catch (err) {
    console.error("Notification send failed", err);
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method Not Allowed" }, 405);
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const meetingId = body.meetingId;
  const action = body.action;
  if (!meetingId || !action) {
    return jsonResponse({ error: "meetingId and action are required" }, 400);
  }

  // --- AUTH HEADER ---
  const authHeader = req.headers.get("Authorization") ?? "";

  if (!authHeader.startsWith("Bearer ")) {
    return jsonResponse(
      { error: "Missing or invalid Authorization header" },
      401,
    );
  }

  // Create Supabase client with forwarded Authorization
  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { Authorization: authHeader },
    },
  });

  // --- AUTH: get current user ---
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  const userId = user.id;

  // --- PROFILE / ROLE ---
  const { data: profile, error: profileError } = await supabase
    .from("user")
    .select("role, name")
    .eq("id", userId)
    .maybeSingle();

  if (profileError || !profile) {
    return jsonResponse({ error: "User profile not found" }, 403);
  }

  const role: string = profile.role;

  // --- FETCH MEETING ---
  const { data: meeting, error: meetingError } = await supabase
    .from("adoption_meeting")
    .select(
      "meeting_id, status, adopter_id, rescuer_id, shelter_id, animal_id",
    )
    .eq("meeting_id", meetingId)
    .maybeSingle();

  if (meetingError || !meeting) {
    return jsonResponse({ error: "Meeting not found" }, 404);
  }

  // --- PERMISSION CHECK ---
  const isOwner =
    (role === "rescuer" && meeting.rescuer_id === userId) ||
    (role === "shelter" && meeting.shelter_id === userId) ||
    (role === "adopter" && meeting.adopter_id === userId);

  const isAdmin = role === "admin";
  const isAllowedActor = isAdmin || role === "rescuer" || role === "shelter";
  // 👉 if adopter should also be allowed to act, change to:
  // const isAllowedActor = isAdmin || role === "rescuer" || role === "shelter" || role === "adopter";

  if (!isAllowedActor || (!isAdmin && !isOwner)) {
    return jsonResponse({ error: "Forbidden" }, 403);
  }

  const transitions: Record<string, Partial<Record<Action, string>>> = {
    Pending: { approve: "Approved", reject: "Rejected" },
    Approved: { complete: "Completed", reject: "Rejected" },
    Rejected: {},
    Completed: {},
  };

  const nextStatus = transitions[meeting.status]?.[action];
  if (!nextStatus) {
    return jsonResponse(
      { error: `Action '${action}' not allowed from status '${meeting.status}'` },
      400,
    );
  }

  // --- UPDATE MEETING ---
  const { data: updatedMeeting, error: updateError } = await supabase
    .from("adoption_meeting")
    .update({ status: nextStatus })
    .eq("meeting_id", meetingId)
    .select(
      "meeting_id, status, adopter_id, rescuer_id, shelter_id, animal_id",
    )
    .maybeSingle();

  if (updateError || !updatedMeeting) {
    return jsonResponse(
      { error: updateError?.message ?? "Failed to update meeting" },
      400,
    );
  }

  // --- OPTIONAL: update animal status on complete ---
  if (action === "complete" && body.updateAnimal !== false) {
    const { error: animalError } = await supabase
      .from("animal")
      .update({ status: "adopted" })
      .eq("animal_id", updatedMeeting.animal_id);

    if (animalError) {
      return jsonResponse(
        {
          error: "Failed to update animal status. Ensure 'status' column exists on animal.",
          details: animalError.message,
        },
        400,
      );
    }
  }

  await logAudit(supabase, {
    actorId: userId,
    action,
    targetType: "adoption_meeting",
    targetId: meetingId,
    details: {
      from_status: meeting.status,
      to_status: nextStatus,
      reason: body.reason ?? null,
    },
  });

  await sendNotification({
    type: "adoption_meeting",
    action,
    meeting_id: meetingId,
    status: nextStatus,
    actor_id: userId,
    recipient_ids: [
      meeting.adopter_id,
      meeting.rescuer_id,
      meeting.shelter_id,
    ].filter(Boolean),
  });

  return jsonResponse({
    meeting: updatedMeeting,
    message: `Meeting ${meetingId} set to ${nextStatus}`,
  });
});
