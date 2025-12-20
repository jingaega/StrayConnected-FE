import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !supabaseAnonKey) {
    return new Response(
      JSON.stringify({
        code: "MISSING_ENV",
        message: "SUPABASE_URL or SUPABASE_ANON_KEY is not set",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  // Forward Authorization header from client (contains user JWT when logged in)
  const authHeader = req.headers.get("Authorization") ?? "";

  if (!authHeader.startsWith("Bearer ")) {
    return new Response(
      JSON.stringify({
        code: "MISSING_BEARER",
        message: "Missing or invalid Authorization header",
      }),
      { status: 401, headers: { "Content-Type": "application/json" } },
    );
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { Authorization: authHeader },
    },
  });

  // Validate user
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser();

  if (userError || !user) {
    return new Response(
      JSON.stringify({ code: "UNAUTHORIZED", message: "Unauthorized" }),
      { status: 401, headers: { "Content-Type": "application/json" } },
    );
  }

  // ✅ Check role from "user" table – only real admins allowed
  const { data: profile, error: profileError } = await supabase
    .from("user")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();

  if (profileError || !profile || profile.role !== "admin") {
    return new Response(
      JSON.stringify({ code: "FORBIDDEN", message: "Admins only" }),
      { status: 403, headers: { "Content-Type": "application/json" } },
    );
  }

  // Query "admin" table
  const { data, error } = await supabase
    .from("admin")
    .select("*");

  if (error) {
    return new Response(
      JSON.stringify({ code: "DB_ERROR", message: error.message }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  return new Response(JSON.stringify(data), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
