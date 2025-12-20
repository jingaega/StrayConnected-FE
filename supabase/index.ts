import { serve } from "https://deno.land/std/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Edge function that requires a logged-in user.
// Uses anon key + forwarded JWT (Authorization header) to enforce RLS.
serve(async (req) => {
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

  // Forward the JWT so RLS checks apply.
  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

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

  // Example query: current user's profile
  const { data, error } = await supabase
    .from("user")
    .select("*")
    .eq("id", user.id)
    .maybeSingle();

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
