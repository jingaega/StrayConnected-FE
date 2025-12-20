import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnon = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !supabaseAnon) {
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

  const supabase = createClient(supabaseUrl, supabaseAnon, {
    global: {
      headers: { Authorization: authHeader },
    },
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

  // If you want only rescuers to see rescuer list, you could check role here:
  // const { data: profile } = await supabase
  //   .from("user")
  //   .select("role")
  //   .eq("id", user.id)
  //   .maybeSingle();
  // if (!profile || profile.role !== "rescuer") { ... }

  const { data, error } = await supabase.from("rescuer").select("*");

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
