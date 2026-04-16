# FlowDay — Supabase + Claude Setup Guide

Follow these steps **once** to wire up the backend before building or testing the
`feature/supabase-anthropic` branch. No secrets go in the repo at any point.

---

## Prerequisites

| Tool | Version |
|------|---------|
| Supabase CLI | `brew install supabase/tap/supabase` |
| Xcode | 15+ |
| A Supabase account | free tier is fine |
| An Anthropic account | need an API key from console.anthropic.com |

---

## Step 1 — Create your Supabase project

1. Go to [supabase.com](https://supabase.com) → **New project**
2. Choose a name, region close to your users, and a strong database password
3. Wait ~2 minutes for it to spin up

---

## Step 2 — Add your credentials to the app

1. In the Supabase dashboard → **Project Settings → API**
2. Copy the **Project URL** (looks like `https://xxxxxxxxxxxx.supabase.co`)
3. Copy the **anon public** key
4. In Xcode, duplicate `FlowDay/Config.example.swift` → `FlowDay/Config.swift`
   (it's already gitignored, so it will never be committed)
5. Fill in both values:

```swift
// FlowDay/Config.swift
enum FlowDayConfig {
    static let supabaseURL = "https://xxxxxxxxxxxx.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6..."
}
```

---

## Step 3 — Add the Supabase Swift SDK via SPM

1. In Xcode → **File → Add Package Dependencies…**
2. Paste: `https://github.com/supabase/supabase-swift`
3. Set **Dependency Rule** to **Up to Next Major Version**, starting from `2.0.0`
4. Add to the **FlowDay** target
5. Build once (`⌘B`) to confirm there are no import errors

---

## Step 4 — Run the database schema

1. In the Supabase dashboard → **SQL Editor → New query**
2. Paste the contents of `supabase/schema.sql` (in this repo)
3. Click **Run**

This creates the `profiles`, `projects`, `tasks`, `subtasks`, `templates`, and
`task_completions` tables with Row Level Security enabled on all of them.

---

## Step 5 — Enable Sign in with Apple in Supabase

1. Supabase dashboard → **Authentication → Providers**
2. Find **Apple** → toggle it on
3. Set the **Service ID** to your Apple Developer Services ID
   (Xcode → Signing & Capabilities → Sign in with Apple → Services ID)
4. Leave the other fields blank for now (they're only needed for web flows)

---

## Step 6 — Set the Anthropic API key as a Supabase secret

The API key must **never** be in the iOS app. It lives only as a server-side secret.

```bash
# From the repo root, with supabase CLI linked to your project:
supabase login
supabase link --project-ref YOUR_PROJECT_REF  # found in Supabase dashboard URL

supabase secrets set ANTHROPIC_API_KEY=sk-ant-api03-YOUR-KEY-HERE
```

To verify it was set:

```bash
supabase secrets list
# You should see: ANTHROPIC_API_KEY
```

---

## Step 7 — Deploy the Edge Function

```bash
supabase functions deploy claude --no-verify-jwt=false
```

This deploys `supabase/functions/claude/index.ts`. The `--no-verify-jwt=false`
flag ensures the JWT check is **active** — unauthenticated callers are rejected.

To verify it's working, call it with your service role key (for testing only):

```bash
curl -i \
  -H "Authorization: Bearer $(supabase status | grep 'service_role' | awk '{print $NF}')" \
  -H "Content-Type: application/json" \
  -d '{"feature":"flowAI","messages":[{"role":"user","content":"Say hello"}]}' \
  https://YOUR_PROJECT_REF.supabase.co/functions/v1/claude
```

A `200` response with `{"content":"..."}` means it's live. Check the response
headers for `X-Cache-Status` — first call will be `CREATION`, subsequent calls
with the same feature will be `HIT`.

---

## Step 8 — Build and test

1. Run the app in the simulator
2. Sign in with Apple or email
3. Go to **Flow AI** tab → send a message — the first response may be slow (~3 s)
   while Anthropic creates the cache; subsequent responses should be faster (~1–2 s)
4. Go to **Templates → AI Generate** → type a project description → tap **Generate Template**
5. Check Xcode console for `[ClaudeClient] feature=... cache=HIT` on the second call

---

## How prompt caching works

The Edge Function marks each feature's system prompt with `cache_control: { type: "ephemeral" }`.
After the **first** call for a feature, Anthropic caches the tokenized system prompt for up to 5 minutes.

Cache status is returned in response headers and logged by `ClaudeClient`:

| Header | Meaning |
|--------|---------|
| `X-Cache-Status: CREATION` | First call — cache was written |
| `X-Cache-Status: HIT` | Cache hit — saved ~50% latency + 90% cost on cached tokens |
| `X-Cache-Status: MISS` | Cache expired (>5 min since last call) |
| `X-Cache-Read-Tokens` | Tokens served from cache |
| `X-Cache-Creation-Tokens` | Tokens written to cache |

You can also see this in **Supabase → Edge Functions → claude → Logs**.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `401 Unauthorized` from Edge Function | User not signed in, or JWT expired — sign out and back in |
| `500 Server configuration error` | `ANTHROPIC_API_KEY` secret not set — redo Step 6 |
| App crashes on launch with "nil Config URL" | `Config.swift` is missing or has placeholder values |
| Supabase SDK not found | Redo Step 3 — make sure you added it to the FlowDay target |
| `syncAll` not running | Auth session not yet restored at launch — check Xcode console for `[SupabaseService]` logs |

---

## What's gitignored

| File | Why |
|------|-----|
| `FlowDay/Config.swift` | Contains your Supabase project URL and anon key |

The anon key is **safe to expose** (it's a public key — Row Level Security
enforces data isolation). It's gitignored anyway for consistency with the URL.
The `ANTHROPIC_API_KEY` never appears in the repo at all.
