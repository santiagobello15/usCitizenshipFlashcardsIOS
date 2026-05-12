import { serve } from "https://deno.land/std@0.224.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.46.1"

serve(async (req) => {
  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    return new Response("Missing Authorization header", { status: 401 })
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } }
  )

  const token = authHeader.replace("Bearer ", "")
  const { data: { user }, error: userError } = await supabase.auth.getUser(token)
  if (userError || !user) {
    return new Response("Unauthorized", { status: 401 })
  }

  await supabase.from("user_settings").delete().eq("user_id", user.id)

  const { error } = await supabase.auth.admin.deleteUser(user.id)
  if (error) {
    return new Response(error.message, { status: 500 })
  }

  return new Response("Account deleted", { status: 200 })
})
