import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

type PushEvent = "friend_request" | "fitness_challenge" | "challenge_completed";
type PushRequest = { event_type?: PushEvent; record_id?: string };
type NotificationCopy = { recipientId: string; title: string; body: string };

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    if (!jwt) return json({ error: "Authentication required." }, 401);

    const supabaseUrl = requiredEnv("SUPABASE_URL");
    const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");
    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: userError } = await admin.auth.getUser(jwt);
    if (userError || !userData.user) return json({ error: "Invalid session." }, 401);

    const body = await req.json() as PushRequest;
    if (!body.event_type || !body.record_id) return json({ error: "event_type and record_id are required." }, 400);

    const copy = await resolveNotification(admin, userData.user.id, body.event_type, body.record_id);
    if (!copy) return json({ error: "Notification event is unavailable." }, 403);

    const { data: preferences } = await admin
      .from("coach_user_settings")
      .select("social_notifications")
      .eq("user_id", copy.recipientId)
      .maybeSingle();
    if (preferences?.social_notifications === false) return json({ delivered: 0, configured: true });

    const { data: devices, error: deviceError } = await admin
      .from("push_device_tokens")
      .select("device_token, environment, app_bundle_id")
      .eq("user_id", copy.recipientId)
      .eq("is_active", true);
    if (deviceError) throw deviceError;

    const apnsKey = Deno.env.get("APNS_PRIVATE_KEY");
    const apnsKeyId = Deno.env.get("APNS_KEY_ID");
    const apnsTeamId = Deno.env.get("APNS_TEAM_ID");
    if (!apnsKey || !apnsKeyId || !apnsTeamId) {
      console.warn("APNs credentials are not configured; social action succeeded without push delivery.");
      return json({ delivered: 0, configured: false });
    }

    const providerToken = await makeProviderToken(apnsKey, apnsKeyId, apnsTeamId);
    let delivered = 0;
    for (const device of devices ?? []) {
      const result = await sendAPNs(device, providerToken, copy, body.event_type, body.record_id);
      if (result.ok) {
        delivered += 1;
      } else if (result.invalidate) {
        await admin.from("push_device_tokens")
          .update({ is_active: false, updated_at: new Date().toISOString() })
          .eq("device_token", device.device_token);
      }
    }

    return json({ delivered, configured: true });
  } catch (error) {
    console.error(error);
    return json({ error: error instanceof Error ? error.message : "Push delivery failed." }, 500);
  }
});

async function resolveNotification(
  admin: ReturnType<typeof createClient>,
  actorId: string,
  event: PushEvent,
  recordId: string,
): Promise<NotificationCopy | null> {
  const { data: actor } = await admin
    .from("social_profiles")
    .select("display_name")
    .eq("user_id", actorId)
    .maybeSingle();
  const actorName = actor?.display_name ?? "A friend";

  if (event === "friend_request") {
    const { data } = await admin.from("friendships").select("requester_id, addressee_id, status").eq("id", recordId).maybeSingle();
    if (!data || data.requester_id !== actorId || data.status !== "pending") return null;
    return { recipientId: data.addressee_id, title: "New Training Partner", body: `${actorName} sent you a friend request.` };
  }

  const { data } = await admin.from("fitness_challenges")
    .select("challenger_id, challenged_id, challenge_type, challenger_rep_count, challenged_rep_count, target_rep_count, winner_id, status")
    .eq("id", recordId)
    .maybeSingle();
  if (!data) return null;
  const exercise = exerciseName(data.challenge_type);
  const isTimedHold = data.challenge_type === "plank";
  const scoreDisplay = (score: number | null | undefined) => isTimedHold
    ? formatHoldSeconds(score ?? 0)
    : String(score ?? 0);
  const targetCopy = isTimedHold
    ? `hold for ${scoreDisplay(data.target_rep_count)}`
    : `hit ${scoreDisplay(data.target_rep_count)}`;

  if (event === "fitness_challenge") {
    if (data.challenger_id !== actorId || data.status !== "pending") return null;
    return {
      recipientId: data.challenged_id,
      title: `${exercise} Challenge`,
      body: isTimedHold
        ? `${actorName} held a plank for ${scoreDisplay(data.challenger_rep_count)}. Beat it: ${targetCopy}.`
        : `${actorName} did ${scoreDisplay(data.challenger_rep_count)}. Beat it with ${targetCopy}.`,
    };
  }

  if (data.challenged_id !== actorId || data.status !== "completed") return null;
  const responseScore = data.challenged_rep_count ?? 0;
  const won = data.winner_id === actorId;
  return {
    recipientId: data.challenger_id,
    title: won ? "Your Lead Is Gone" : "You Still Lead",
    body: won
      ? isTimedHold
        ? `${actorName} held for ${scoreDisplay(responseScore)}. Time for a rematch.`
        : `${actorName} answered with ${scoreDisplay(responseScore)} ${exercise.toLowerCase()}. Time for a rematch.`
      : isTimedHold
        ? `${actorName} held for ${scoreDisplay(responseScore)}. Your ${scoreDisplay(data.challenger_rep_count)} still holds.`
        : `${actorName} reached ${scoreDisplay(responseScore)}. Your ${scoreDisplay(data.challenger_rep_count)} still holds.`,
  };
}

function formatHoldSeconds(seconds: number): string {
  const wholeSeconds = Math.max(Math.floor(seconds), 0);
  return `${Math.floor(wholeSeconds / 60)}:${String(wholeSeconds % 60).padStart(2, "0")}`;
}

async function sendAPNs(
  device: { device_token: string; environment: string; app_bundle_id: string },
  providerToken: string,
  copy: NotificationCopy,
  event: PushEvent,
  recordId: string,
): Promise<{ ok: boolean; invalidate: boolean }> {
  const host = device.environment === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com";
  const response = await fetch(`https://${host}/3/device/${device.device_token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${providerToken}`,
      "apns-topic": device.app_bundle_id,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-collapse-id": recordId,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      aps: { alert: { title: copy.title, body: copy.body }, sound: "default", badge: 1, "thread-id": "social-challenges" },
      route: "competition",
      event_type: event,
      record_id: recordId,
    }),
  });
  if (response.ok) return { ok: true, invalidate: false };
  const errorBody = await response.text();
  console.error(`APNs ${response.status}: ${errorBody}`);
  return { ok: false, invalidate: response.status === 410 || errorBody.includes("BadDeviceToken") || errorBody.includes("Unregistered") };
}

async function makeProviderToken(privateKeyPEM: string, keyId: string, teamId: string): Promise<string> {
  const header = base64url(new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: keyId })));
  const claims = base64url(new TextEncoder().encode(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) })));
  const input = new TextEncoder().encode(`${header}.${claims}`);
  const keyBytes = pemBytes(privateKeyPEM.replace(/\\n/g, "\n"));
  const key = await crypto.subtle.importKey("pkcs8", keyBytes, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, input);
  return `${header}.${claims}.${base64url(new Uint8Array(signature))}`;
}

function pemBytes(pem: string): Uint8Array {
  const body = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, "");
  return Uint8Array.from(atob(body), (character) => character.charCodeAt(0));
}

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function exerciseName(type: string): string {
  if (type === "push_up") return "Push-Up";
  if (type === "jumping_jack") return "Jumping Jack";
  return "Squat";
}

function requiredEnv(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is not configured.`);
  return value;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
