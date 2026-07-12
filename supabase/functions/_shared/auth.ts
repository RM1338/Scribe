import { createClient } from "jsr:@supabase/supabase-js@2";

/// Resolves the signed-in user from the request's Authorization header, or null
/// if the caller is anonymous / unauthenticated. Used to gate the Groq proxy to
/// real, logged-in users so the server-side key can't be driven by anyone who
/// merely has the public anon key.
export async function getRequestUser(req: Request) {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return null;

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } },
  );

  const { data, error } = await supabase.auth.getUser();
  if (error || !data.user) return null;
  return data.user;
}
