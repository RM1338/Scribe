// Proxies chat-completion requests to Groq so the API key never ships in the
// app. Only signed-in users may call it, and only a whitelisted model is
// allowed, capping how the key can be abused.
//
// Deploy:  supabase functions deploy groq-chat
// Secret:  supabase secrets set GROQ_API_KEY=sk_...
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { getRequestUser } from "../_shared/auth.ts";

const GROQ_CHAT_URL = "https://api.groq.com/openai/v1/chat/completions";

// Models the app is allowed to invoke through the proxy.
const ALLOWED_MODELS = new Set([
  "openai/gpt-oss-120b",
  "llama-3.3-70b-versatile",
  "llama-3.1-8b-instant",
]);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const user = await getRequestUser(req);
  if (!user) return jsonResponse({ error: "Unauthorized" }, 401);

  const groqKey = Deno.env.get("GROQ_API_KEY");
  if (!groqKey) return jsonResponse({ error: "Server missing GROQ_API_KEY" }, 500);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch (_) {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const model = body["model"];
  if (typeof model !== "string" || !ALLOWED_MODELS.has(model)) {
    return jsonResponse({ error: "Model not allowed" }, 400);
  }

  const groqRes = await fetch(GROQ_CHAT_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${groqKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  // Pass Groq's response straight back to the app, status and all.
  const text = await groqRes.text();
  return new Response(text, {
    status: groqRes.status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
