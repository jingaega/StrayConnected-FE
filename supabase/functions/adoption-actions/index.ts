import { serve } from "https://deno.land/std/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js";

const supabaseUrl = Deno.env.get("PROJECT_URL")!;
const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")!;
const notifyWebhookUrl = Deno.env.get("NOTIFY_WEBHOOK_URL"); // optional

const supabase = createClient(supabaseUrl, serviceRoleKey);

type Action = "approve" | "reject" | "complete";

type RequestBody = {
  meetingId?: number;
  action?: Action;
  reason?: string;
  updateAnimal?: boolean; // set to false to skip auto-adopt on complete
};

type JsonValue = string | number | boolean | null | JsonValue[] | { [key: string]: JsonValue };

function jsonResponse(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function logAudit(entry: {
  actorId: string;
  action: string;
  targetType: string;
  targetId: string | number;
  details?: Record<string, JsonValue>;
}) {
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

serve(async (req) => {
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

  const token = req.headers.get("Authorization")?.replace("Bearer ", "");
  if (!token) {
    return jsonResponse({ error: "Missing Authorization header" }, 401);
  }

  const { data: auth, error: authError } = await supabase.auth.getUser(token);
  if (authError || !auth?.user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  const userId = auth.user.id;

  const { data: profile, error: profileError } = await supabase
    .from("user")
    .select("role, name")
    .eq("id", userId)
    .maybeSingle();

  if (profileError || !profile) {
    return jsonResponse({ error: "User profile not found" }, 403);
  }

  const role: string = profile.role;

  const { data: meeting, error: meetingError } = await supabase
    .from("adoption_meeting")
    .select("meeting_id, status, adopter_id, rescuer_id, shelter_id, animal_id")
    .eq("meeting_id", meetingId)
    .maybeSingle();

  if (meetingError || !meeting) {
    return jsonResponse({ error: "Meeting not found" }, 404);
  }

  // Permission: admin can always act; rescuer/shelter must own the meeting.
  const isOwner =
    (role === "rescuer" && meeting.rescuer_id === userId) ||
    (role === "shelter" && meeting.shelter_id === userId) ||
    (role === "adopter" && meeting.adopter_id === userId);

  const isAdmin = role === "admin";
  const isAllowedActor = isAdmin || role === "rescuer" || role === "shelter";

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
    return jsonResponse({ error: `Action '${action}' not allowed from status '${meeting.status}'` }, 400);
  }

  // Update meeting status
  const { data: updatedMeeting, error: updateError } = await supabase
    .from("adoption_meeting")
    .update({ status: nextStatus })
    .eq("meeting_id", meetingId)
    .select("meeting_id, status, adopter_id, rescuer_id, shelter_id, animal_id")
    .maybeSingle();

  if (updateError || !updatedMeeting) {
    return jsonResponse({ error: updateError?.message ?? "Failed to update meeting" }, 400);
  }

  // If completing, optionally mark animal as adopted.
  if (action === "complete" && body.updateAnimal !== false) {
    const { error: animalError } = await supabase
      .from("animal")
      .update({ status: "adopted" })
      .eq("animal_id", updatedMeeting.animal_id);

    if (animalError) {
      return jsonResponse({
        error: "Failed to update animal status. Ensure 'status' column exists on animal.",
        details: animalError.message,
      }, 400);
    }
  }

  await logAudit({
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
    recipient_ids: [meeting.adopter_id, meeting.rescuer_id, meeting.shelter_id].filter(Boolean),
  });

  return jsonResponse({
    meeting: updatedMeeting,
    message: `Meeting ${meetingId} set to ${nextStatus}`,
  });
});
