import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error("SUPABASE_URL or SUPABASE_ANON_KEY is not set");
}

Deno.serve(async (req) => {
  const authHeader = req.headers.get("Authorization") ?? "";

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({ error: "Missing or invalid Authorization header" }),
      { status: 401, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // 🔹 Get role from user/profile table
  const { data: profile, error: profileError } = await supabase
    .from("user")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();

  if (profileError || !profile) {
    return new Response(
      JSON.stringify({ error: "User profile not found" }),
      { status: 403, headers: { "Content-Type": "application/json" } },
    );
  }

  let query = supabase
    .from("adoption_meeting")
    .select("*");

  // 🔹 Admin can see all, others only related meetings
  if (profile.role !== "admin") {
    query = query.or(
      `adopter_id.eq.${user.id},rescuer_id.eq.${user.id},shelter_id.eq.${user.id}`,
    );
  }

  const { data, error } = await query;

  if (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
