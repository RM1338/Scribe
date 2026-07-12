// Proxies audio transcription to Groq Whisper so the API key never ships in the
// app. Only signed-in users may call it. The app POSTs multipart form-data with
// a `file` (and optional `language`); the model and response format are fixed
// server-side.
//
// Deploy:  supabase functions deploy groq-transcribe
// Secret:  supabase secrets set GROQ_API_KEY=sk_...
import { corsHeaders, jsonResponse } from "../_shared/cors.ts";
import { getRequestUser } from "../_shared/auth.ts";

const GROQ_TRANSCRIBE_URL =
  "https://api.groq.com/openai/v1/audio/transcriptions";

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

  let incoming: FormData;
  try {
    incoming = await req.formData();
  } catch (_) {
    return jsonResponse({ error: "Expected multipart form-data" }, 400);
  }

  const file = incoming.get("file");
  if (!(file instanceof File)) {
    return jsonResponse({ error: "Missing audio file" }, 400);
  }

  const groqForm = new FormData();
  groqForm.append("file", file, file.name || "audio.wav");
  groqForm.append("model", "whisper-large-v3-turbo");
  groqForm.append("response_format", "verbose_json");

  const language = incoming.get("language");
  if (typeof language === "string" && language.length > 0) {
    groqForm.append("language", language);
  }

  const groqRes = await fetch(GROQ_TRANSCRIBE_URL, {
    method: "POST",
    headers: { "Authorization": `Bearer ${groqKey}` },
    body: groqForm,
  });

  const text = await groqRes.text();
  return new Response(text, {
    status: groqRes.status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
