import { serve } from "https://deno.land/std/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js";

const supabaseUrl = Deno.env.get("PROJECT_URL")!;
const serviceRoleKey = Deno.env.get("SERVICE_ROLE_KEY")!;

const supabase = createClient(supabaseUrl, serviceRoleKey);

serve(async (req) => {
  // Ambil access token dari header Authorization
  const authHeader = req.headers.get("Authorization");
  const token = authHeader?.replace("Bearer ", "");

  // Validasi token user
  const { data: { user } } = await supabase.auth.getUser(token);

  if (!user) {
    return new Response("Unauthorized", { status: 401 });
  }

  // Jika lolos auth → ambil data users
  const { data, error } = await supabase.from("users").select("*");

  if (error) {
    return new Response(error.message, { status: 400 });
  }

  return new Response(JSON.stringify(data), {
    headers: { "Content-Type": "application/json" },
  });
});
