import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  try {
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

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: { Authorization: authHeader },
      },
    });

    const {
      data: { user },
      error: userError,
    } = await supabase.auth.getUser();

    if (userError) {
      return new Response(
        JSON.stringify({ code: "GET_USER_ERROR", message: userError.message }),
        { status: 401, headers: { "Content-Type": "application/json" } },
      );
    }

    if (!user) {
      return new Response(
        JSON.stringify({ code: "UNAUTHORIZED", message: "User not found" }),
        { status: 401, headers: { "Content-Type": "application/json" } },
      );
    }

    // Only return this user's profile
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
  } catch (e: any) {
    return new Response(
      JSON.stringify({
        code: "EXCEPTION",
        message: e?.message ?? String(e),
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
