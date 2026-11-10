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
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405, corsHeaders);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid request" }, 400, corsHeaders);
  }
  const action = body.action === "register" ? "register" : "login";
  const username = String(body.username ?? "").trim();
  const usernameKey = username.toLowerCase();
  const password = String(body.password ?? "");
  if (password.length < 8 || password.length > 128 || !usernameKey) {
    return jsonResponse({ error: "Enter a valid username and password." }, 400, corsHeaders);
  }

  if (action === "register") {
    if (!usernamePattern.test(usernameKey)) {
      return jsonResponse({ error: "Username must be 3–32 characters using letters, numbers, dots, hyphens or underscores." }, 400, corsHeaders);
    }
    const ip = request.headers.get("cf-connecting-ip") ?? request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
    const now = Date.now();
    const bucket = signupAttempts.get(ip);
    if (bucket && now - bucket.start < 60_000 && bucket.count >= 5) {
      return jsonResponse({ error: "Too many sign-up attempts. Please wait a minute." }, 429, corsHeaders);
    }
    if (!bucket || now - bucket.start >= 60_000) signupAttempts.set(ip, { start: now, count: 1 });
    else bucket.count += 1;
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const publicKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  if (!supabaseUrl || !serviceRoleKey || !publicKey) {
    return jsonResponse({ error: "Server is not configured" }, 500, corsHeaders);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  let email: string;
  if (action === "register") {
    const role = body.role === "vendor" ? "vendor" : body.role === "student" ? "student" : "";
    const tpNumber = String(body.tp_number ?? "").trim().toUpperCase();
    const storeName = String(body.store_name ?? "").trim();
    const categories = new Set(["Asian", "Cafe", "Local", "Other"]);
    const category = String(body.store_category ?? "Other");
    const description = String(body.store_description ?? "").trim();
    const image = String(body.store_image ?? "").trim();
    if (!role) return jsonResponse({ error: "Choose Student or Vendor." }, 400, corsHeaders);
    if (role === "student" && !/^TP\d{6}$/.test(tpNumber)) {
      return jsonResponse({ error: "Enter a TP number in the format TP089876." }, 400, corsHeaders);
    }
    if (role === "vendor" && (!storeName || storeName.length > 100)) {
      return jsonResponse({ error: "Enter a stall name under 100 characters." }, 400, corsHeaders);
    }
    if (description.length > 500 || image.length > 1000) {
      return jsonResponse({ error: "Stall details are too long." }, 400, corsHeaders);
    }
    if (image && !/^https?:\/\//i.test(image)) {
      return jsonResponse({ error: "Photo URL must start with http:// or https://." }, 400, corsHeaders);
    }
    if (role === "vendor" && !categories.has(category)) {
      return jsonResponse({ error: "Choose a valid stall category." }, 400, corsHeaders);
    }

    const { data: existing, error: lookupError } = await admin
      .from("profiles").select("id").eq("username_key", usernameKey).maybeSingle();
    if (lookupError) return jsonResponse({ error: "Could not check username availability." }, 500, corsHeaders);
    if (existing) return jsonResponse({ error: "That username is already taken." }, 409, corsHeaders);

    email = `${usernameKey}@accounts.mealsync.invalid`;
    const metadata = {
      role,
      username,
      full_name: role === "vendor" ? storeName : username,
      ...(role === "student" ? { tp_number: tpNumber } : {
        store_name: storeName,
        store_category: category,
        store_description: description,
        store_image: image,
      }),
    };
    const { error: createError } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: metadata,
    });
    if (createError) {
      const status = /already|exists|duplicate/i.test(createError.message) ? 409 : 400;
      return jsonResponse({ error: status === 409 ? "That username is already taken." : "Could not create this account. Check the details and try again." }, status, corsHeaders);
    }
  } else {
    const { data: profile, error: lookupError } = await admin
      .from("profiles").select("email").eq("username_key", usernameKey).maybeSingle();
    if (lookupError || !profile?.email) {
      return jsonResponse({ error: "Incorrect username or password." }, 401, corsHeaders);
    }
    email = profile.email;
  }

  const authResponse = await fetch(`${supabaseUrl}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { apikey: publicKey, "Content-Type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
  if (!authResponse.ok) {
    if (action === "register") {
      return jsonResponse({ created: true, message: "Account created. Log in with your username." }, 200, corsHeaders);
    }
    return jsonResponse({ error: "Incorrect username or password." }, 401, corsHeaders);
  }
  return new Response(await authResponse.text(), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
