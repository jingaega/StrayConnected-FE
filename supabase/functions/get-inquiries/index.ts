import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ---------- ENV ----------
const supabaseUrl = Deno.env.get("SUPABASE_URL");
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

// Google service account env (from Firebase service account JSON)
const googleProjectId = Deno.env.get("GOOGLE_PROJECT_ID");
const googleClientEmail = Deno.env.get("GOOGLE_CLIENT_EMAIL");
const googlePrivateKeyRaw = Deno.env.get("GOOGLE_PRIVATE_KEY"); // with \n escaped

if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
  throw new Error("SUPABASE_URL / ANON / SERVICE_ROLE env not set");
}
if (!googleProjectId || !googleClientEmail || !googlePrivateKeyRaw) {
  console.warn(
    "[WARN] GOOGLE_PROJECT_ID / GOOGLE_CLIENT_EMAIL / GOOGLE_PRIVATE_KEY not fully set. FCM will be disabled.",
  );
}

// turn JSON-style private key into real PEM
const googlePrivateKey = googlePrivateKeyRaw?.replace(/\\n/g, "\n");

// ---------- HELPERS ----------
function b64url(input: string | Uint8Array): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;
  return btoa(String.fromCharCode(...bytes))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function getAccessToken(): Promise<string> {
  if (!googleClientEmail || !googlePrivateKey) {
    throw new Error("Missing Google service account envs");
  }

  const now = Math.floor(Date.now() / 1000);

  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: googleClientEmail,
    sub: googleClientEmail,
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  };

  const encHeader = b64url(JSON.stringify(header));
  const encPayload = b64url(JSON.stringify(claimSet));
  const unsignedJwt = `${encHeader}.${encPayload}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(googlePrivateKey),
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsignedJwt),
  );

  const encSig = b64url(new Uint8Array(signature));
  const jwt = `${unsignedJwt}.${encSig}`;

  const body = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion: jwt,
  });

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: body.toString(),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Google token error: ${res.status} ${text}`);
  }

  const json = await res.json() as { access_token: string };
  return json.access_token;
}

// ---------- MAIN HANDLER ----------
Deno.serve(async (req) => {
  try {
    // 1) Check Authorization header from Flutter
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

    // 2) Client A: anon key + forwarded JWT  → only for auth check / RLS things
    const supabaseAuth = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    // 3) Validate current user
    const {
      data: { user },
      error: userError,
    } = await supabaseAuth.auth.getUser();

    if (userError || !user) {
      return new Response(
        JSON.stringify({ code: "UNAUTHORIZED", message: "Unauthorized" }),
        { status: 401, headers: { "Content-Type": "application/json" } },
      );
    }

    // 4) Client B: service role key → bypass RLS just for reading inquiry + user
    const supabaseService = createClient(supabaseUrl, supabaseServiceRoleKey);

    // Load inquiries + sender/receiver (this is where RLS used to block you)
    const { data, error } = await supabaseService
      .from("inquiry")
      .select(`
        inquiry_id,
        message,
        date,
        sender_id,
        receiver_id,
        read_at,
        sender:sender_id (name, email, device_token),
        receiver:receiver_id (name, email, device_token)
      `);

    if (error) {
      return new Response(
        JSON.stringify({ code: "DB_ERROR", message: error.message }),
        { status: 400, headers: { "Content-Type": "application/json" } },
      );
    }

    // 5) Prepare FCM access token (if configured)
    let accessToken: string | null = null;
    if (googleProjectId && googleClientEmail && googlePrivateKeyRaw) {
      try {
        accessToken = await getAccessToken();
      } catch (e) {
        console.error("Error getting FCM access token", e);
      }
    }

    // 6) Build notifications + optionally send to FCM
    const processed = await Promise.all(
      (data ?? []).map(async (row: any) => {
        const senderName =
          row.sender?.name ||
          row.sender?.email ||
          "Someone";
        const msg = row.message ?? "";
        const deviceToken = (row.receiver?.device_token ?? "").trim();

        const notificationPayload = {
          message: {
            token: deviceToken,
            data: {
              sender_name: senderName,
              body: msg,
            },
            notification: {
              title: `New chat from ${senderName}`,
              body: msg,
            },
          },
        };

        // simple logging to debug:
        console.log("Noti payload:", notificationPayload);

        if (accessToken && deviceToken) {
          try {
            const fcmRes = await fetch(
              `https://fcm.googleapis.com/v1/projects/${googleProjectId}/messages:send`,
              {
                method: "POST",
                headers: {
                  "Content-Type": "application/json",
                  Authorization: `Bearer ${accessToken}`,
                },
                body: JSON.stringify(notificationPayload),
              },
            );

            const fcmJson = await fcmRes.json();
            row.fcm_response = fcmJson;
          } catch (err) {
            console.error("FCM send error", err);
            row.fcm_error = String(err);
          }
        } else {
          row.fcm_warning =
            "Missing access token or device_token, push not sent";
        }

        return {
          ...row,
          notificationPayload,
        };
      }),
    );

    return new Response(JSON.stringify(processed), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("Function error", e);
    return new Response(
      JSON.stringify({
        code: "EXCEPTION",
        message: e instanceof Error ? e.message : String(e),
      }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
