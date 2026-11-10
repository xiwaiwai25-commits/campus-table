import { createClient } from "npm:@supabase/supabase-js@2";

const allowedOrigins = new Set([
  "https://xiwaiwai25-commits.github.io",
  "http://localhost:4173",
  "http://127.0.0.1:4173",
  "http://localhost:5500",
  "http://127.0.0.1:5500",
]);
const usernamePattern = /^[a-z0-9](?:[a-z0-9._-]{1,30}[a-z0-9])$/;
const signupAttempts = new Map<string, { start: number; count: number }>();

function jsonResponse(value: unknown, status: number, headers: Record<string, string>) {
  return new Response(JSON.stringify(value), {
    status,
    headers: { ...headers, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request) => {
  const origin = request.headers.get("origin") ?? "";
  if (!allowedOrigins.has(origin)) return new Response("Origin not allowed", { status: 403 });

  const corsHeaders = {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info, x-supabase-api-version",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405, corsHeaders);

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid request" }, 400, corsHeaders);
  }

  const action = String(body.action ?? "login");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const publicKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  if (!supabaseUrl || !serviceRoleKey || !publicKey) {
    return jsonResponse({ error: "Server is not configured" }, 500, corsHeaders);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  if (action === "check-registration") {
    const email = String(body.email ?? "").trim().toLowerCase();
    const username = String(body.username ?? "").trim();
    const usernameKey = username.toLowerCase();
    const role = body.role === "student" || body.role === "vendor" ? body.role : "";
    const tpNumber = String(body.tp_number ?? "").trim().toUpperCase();
    if (!/^\S+@\S+\.\S+$/.test(email) || email.length > 254) {
      return jsonResponse({ error: "Enter a valid email address." }, 400, corsHeaders);
    }
    if (!usernamePattern.test(usernameKey)) {
      return jsonResponse({ error: "Username must be 3–32 characters using letters, numbers, dots, hyphens or underscores." }, 400, corsHeaders);
    }
    if (!role) return jsonResponse({ error: "Choose Student or Vendor." }, 400, corsHeaders);
    if (role === "student" && !/^TP\d{6}$/.test(tpNumber)) {
      return jsonResponse({ error: "Enter a TP number in the format TP089876." }, 400, corsHeaders);
    }

    const ip = request.headers.get("cf-connecting-ip") ?? request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
    const now = Date.now();
    const bucket = signupAttempts.get(ip);
    if (bucket && now - bucket.start < 60_000 && bucket.count >= 5) {
      return jsonResponse({ error: "Too many sign-up attempts. Please wait a minute." }, 429, corsHeaders);
    }
    if (!bucket || now - bucket.start >= 60_000) signupAttempts.set(ip, { start: now, count: 1 });
    else bucket.count += 1;

    const [emailResult, usernameResult, tpResult] = await Promise.all([
      admin.from("profiles").select("id").eq("email", email).maybeSingle(),
      admin.from("profiles").select("id").eq("username_key", usernameKey).maybeSingle(),
      role === "student"
        ? admin.from("profiles").select("id").eq("tp_number", tpNumber).maybeSingle()
        : Promise.resolve({ data: null, error: null }),
    ]);
    if (emailResult.error || usernameResult.error || tpResult.error) {
      return jsonResponse({ error: "Could not check account availability. Please try again." }, 500, corsHeaders);
    }
    if (emailResult.data) return jsonResponse({ error: "That email already has an account. Please log in." }, 409, corsHeaders);
    if (usernameResult.data) return jsonResponse({ error: "That username already has an account. Please choose another or log in." }, 409, corsHeaders);
    if (tpResult.data) return jsonResponse({ error: "That TP number already has an account. Please log in." }, 409, corsHeaders);
    return jsonResponse({ available: true }, 200, corsHeaders);
  }

  // New accounts must be created through Supabase Auth so email verification is enforced.
  if (action === "register") {
    return jsonResponse({ error: "Please refresh MealSync and register with your email address." }, 410, corsHeaders);
  }
  if (action !== "login") return jsonResponse({ error: "Invalid account action." }, 400, corsHeaders);

  const identifier = String(body.identifier ?? "").trim();
  const password = String(body.password ?? "");
  if (!identifier || password.length < 8 || password.length > 128) {
    return jsonResponse({ error: "Enter your email or username and password." }, 400, corsHeaders);
  }

  let profileQuery = admin.from("profiles").select("email");
  profileQuery = identifier.includes("@")
    ? profileQuery.eq("email", identifier.toLowerCase())
    : profileQuery.eq("username_key", identifier.toLowerCase());
  const { data: profile, error: lookupError } = await profileQuery.maybeSingle();
  if (lookupError || !profile?.email) {
    return jsonResponse({ error: "Incorrect email or username. Please check both fields and try again." }, 401, corsHeaders);
  }

  const authResponse = await fetch(`${supabaseUrl}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: publicKey, "Content-Type": "application/json" },
    body: JSON.stringify({ email: profile.email, password }),
  });
  if (!authResponse.ok) {
    let authError = "";
    try {
      const details = await authResponse.clone().json();
      authError = String(details.code ?? details.error_code ?? details.msg ?? details.message ?? "");
    } catch { /* Keep a generic message for unknown auth errors. */ }
    if (/email_not_confirmed/i.test(authError)) {
      return jsonResponse({ error: "Please confirm your email using the link we sent before logging in." }, 401, corsHeaders);
    }
    return jsonResponse({ error: "Incorrect email or username, or password. Please try again." }, 401, corsHeaders);
  }
  return new Response(await authResponse.text(), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
