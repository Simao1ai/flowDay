/**
 * FlowDay — Supabase Edge Function: /functions/v1/claude
 *
 * Single endpoint for all AI features, distinguished by the `feature` field.
 *
 * Prompt caching strategy (saves up to 90% on input token costs):
 *   1. System prompt — cached per feature (stable, identical across all users)
 *   2. Multi-turn messages — earlier conversation turns cached incrementally
 *      so only the newest message pays full input price
 *   3. Per-feature maxTokens defaults — avoids over-allocating output tokens
 *
 * Up to 4 cache breakpoints are supported. We use:
 *   - 1 on the system prompt
 *   - Up to 3 on conversation messages (the last 3 messages before the final one)
 *
 * Auth: JWT verified via SUPABASE_JWT_SECRET. Falls back to X-FlowDay-User-ID
 * header when the bearer token is the anon key (no authenticated Supabase sub).
 *
 * Rate limits: 5 calls/day per feature for free users, 200/day for Pro.
 * Tracked in-memory — resets on cold start (good enough for launch).
 *
 * Deploy:
 *   supabase functions deploy claude --no-verify-jwt=false
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import * as jose from "https://esm.sh/jose@5.2.0";

// ─── Types ────────────────────────────────────────────────────────────────────

type Feature = "flowAI" | "templateGenerator" | "emailToTask" | "dayRecap";

interface ClaudeRequestBody {
  feature: Feature;
  /** The caller-supplied user message(s). System prompt is added server-side. */
  messages: { role: "user" | "assistant"; content: string }[];
  temperature?: number;
  maxTokens?: number;
}

interface AnthropicContentBlock {
  type: "text";
  text: string;
  cache_control?: { type: "ephemeral" };
}

interface AnthropicMessage {
  role: "user" | "assistant";
  content: string | AnthropicContentBlock[];
}

interface AnthropicRequest {
  model: string;
  max_tokens: number;
  temperature: number;
  system: AnthropicContentBlock[];
  messages: AnthropicMessage[];
}

// ─── Rate Limiting ────────────────────────────────────────────────────────────
//
// In-memory map; resets on every cold start. Key: "userId:feature:YYYY-MM-DD".
// This is intentionally simple — good enough until we have a persistent store.

const rateLimitMap = new Map<string, number>();
const FREE_DAILY_LIMIT = 5;
const PRO_DAILY_LIMIT = 200;

function checkRateLimit(userId: string, feature: string, limit: number): boolean {
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
  const key = `${userId}:${feature}:${today}`;
  const prev = rateLimitMap.get(key) ?? 0;
  if (prev >= limit) return false;
  rateLimitMap.set(key, prev + 1);
  return true;
}

// ─── System Prompts ───────────────────────────────────────────────────────────
//
// These are STABLE and REUSABLE — the cache_control breakpoint on each one
// means Anthropic will cache the tokenized system prompt after the first call.
// A cache HIT saves ~50 % latency and costs 10× less than a cache CREATION.

const SYSTEM_PROMPTS: Record<Feature, string> = {
  flowAI: `You are Flow, FlowDay's AI productivity assistant. FlowDay is a task management app that helps users get more done by matching their work to their energy levels throughout the day.

You help users with:
1. Planning their day — scheduling tasks into time slots based on their current energy level (high/normal/low) and calendar gaps
2. Creating tasks — parsing natural language into structured tasks with title, priority (1=urgent, 2=high, 3=medium, 4=low), due date, estimated time, labels
3. Breaking down goals — turning a high-level goal into 5–7 actionable subtasks with priorities and time estimates
4. General productivity guidance — answering questions about focus, habits, and getting things done

Rules:
- When asked to create or parse a task, always return a JSON object with this exact shape:
  { "title": "string", "priority": 2, "dueDate": "YYYY-MM-DD or null", "scheduledTime": "HH:mm or null", "estimatedMinutes": 30, "project": "string or null", "labels": [] }
- When asked to plan a day, return a JSON object: { "scheduledTasks": [{ "taskTitle": "string", "suggestedTime": "HH:MM AM/PM", "reason": "string" }], "summary": "string", "tips": ["string"] }
- When asked to break down a goal, return a JSON object: { "originalGoal": "string", "subtasks": [{ "title": "string", "priority": 2, "estimatedMinutes": 30, "reasoning": "string" }], "projectSuggestion": "string or null" }
- For general conversation, reply naturally in plain text (no JSON).
- Be concise, actionable, and warm. You know the user's tasks and energy level from their context.
- Never mention competitors. Never mention other AI models or that you are Claude.`,

  emailToTask: `You are FlowDay's Email Task Parser. Extract the single most actionable task from an email.

Rules:
- Always return a single JSON object — no prose, no markdown fences, just raw JSON.
- The JSON must match this exact shape:
  {
    "title": "Action-oriented task title starting with a verb, under 80 chars",
    "priority": 2,
    "dueDate": "YYYY-MM-DD or null",
    "scheduledTime": "HH:mm or null",
    "estimatedMinutes": 30,
    "notes": "1–2 sentence context: who sent it, what it's about, any deadline",
    "labels": []
  }
- Priority: 1=urgent (today/ASAP), 2=high (this week), 3=medium (eventually), 4=low.
- dueDate: Extract only if explicitly stated (e.g. "by Friday June 6" → "2026-06-06"). Use null if ambiguous.
- estimatedMinutes: Realistic effort estimate (15–120 min typical).
- title: The action YOU need to take, not a summary of the email. Start with a verb.
- If there are multiple action items, return only the single most important one.`,

  templateGenerator: `You are FlowDay's AI Template Generator. Your job is to create structured task templates from a user's description of a project or workflow.

A template is a reusable project starter: it has a name, a short description, and a list of tasks that someone would need to do to complete this type of project.

Rules:
- Always return a single JSON object — no prose, no markdown, just the JSON.
- The JSON must match this exact shape:
  {
    "name": "Template Name (3–5 words)",
    "description": "One-sentence description of what this template is for",
    "icon": "SF Symbol name (e.g. waveform, briefcase, cart, graduationcap)",
    "colorHex": "#RRGGBB",
    "tasks": [
      { "title": "Task title", "priority": 2, "estimatedMinutes": 30, "notes": "optional extra detail" }
    ]
  }
- Generate 6–12 tasks. More complex projects can have up to 15.
- Priority: 1=urgent (must-do first), 2=high, 3=medium, 4=low/nice-to-have.
- Estimated minutes should be realistic: admin tasks 15–30 min, focused work 45–120 min.
- Choose an SF Symbol icon that visually represents the project domain.
- Choose a hex color that fits the domain (e.g. green for health, blue for software, orange for creative).
- Order tasks in the logical sequence someone would actually do them.
- Keep task titles concise (under 60 characters) and action-oriented (start with a verb).`,

  dayRecap: `You are Flow, FlowDay's end-of-day recap writer. Given the user's completed tasks, habits, and energy level for the day, write a warm 3-sentence evening summary.

Rules:
- First sentence: acknowledge what they accomplished (mention specific task names if provided).
- Second sentence: note their energy pattern and any habits completed.
- Third sentence: a brief encouraging or reflective thought about tomorrow.
- Keep it concise, warm, and personal. No generic motivational quotes.
- Reply in plain text only — no JSON, no markdown, no bullet points.`,
};

// ─── Per-feature token limits ────────────────────────────────────────────────
// Smarter defaults reduce output costs. Client can still override.

const DEFAULT_MAX_TOKENS: Record<Feature, number> = {
  flowAI: 1024,          // Chat responses are concise; JSON plans are ~500 tokens
  emailToTask: 300,      // Single JSON object, always small
  templateGenerator: 1200, // Can have 12-15 tasks, needs room
  dayRecap: 200,         // 3 sentences max
};

// ─── Constants ────────────────────────────────────────────────────────────────

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_MODEL = "claude-sonnet-4-6";
const ANTHROPIC_VERSION = "2023-06-01";

// ─── Multi-turn Cache Helper ─────────────────────────────────────────────────
//
// Marks earlier conversation turns with cache_control so Anthropic caches them.
// On subsequent calls in the same conversation, only the newest message pays
// full input price — earlier cached turns cost 10% of normal.
//
// Strategy: mark up to 3 message breakpoints (we use 1 on system = 4 total max).
// We cache the last message of each "pair" (user+assistant) before the final message.

function addCacheBreakpoints(messages: AnthropicMessage[]): AnthropicMessage[] {
  if (messages.length <= 2) {
    // Too few messages to benefit from conversation caching
    return messages;
  }

  const result: AnthropicMessage[] = [...messages];

  // Find up to 3 breakpoint positions: we want to cache as much of the
  // conversation prefix as possible. Mark the 2nd-to-last, 4th-to-last,
  // and 6th-to-last messages (counting from end) as cache breakpoints.
  const breakpointOffsets = [2, 4, 6]; // positions from end
  let breakpointsUsed = 0;

  for (const offset of breakpointOffsets) {
    const idx = messages.length - offset;
    if (idx < 0 || breakpointsUsed >= 3) break;

    const msg = messages[idx];
    // Convert string content to content block array with cache_control
    result[idx] = {
      role: msg.role,
      content: [
        {
          type: "text",
          text: typeof msg.content === "string" ? msg.content : (msg.content as AnthropicContentBlock[])[0]?.text ?? "",
          cache_control: { type: "ephemeral" },
        },
      ],
    };
    breakpointsUsed++;
  }

  return result;
}

// ─── Handler ──────────────────────────────────────────────────────────────────

serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders(),
    });
  }

  if (req.method !== "POST") {
    return errorResponse(405, "Method not allowed");
  }

  // ── Auth: Verify Supabase JWT ────────────────────────────────────────────
  let userId = "anon";
  let isPro = false;

  const jwtSecret = Deno.env.get("SUPABASE_JWT_SECRET");
  if (!jwtSecret) {
    console.error("[claude] SUPABASE_JWT_SECRET not set");
    return errorResponse(500, "Server configuration error");
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return errorResponse(401, "Authentication required.");
  }

  const token = authHeader.slice(7);
  try {
    const secretKey = new TextEncoder().encode(jwtSecret);
    const { payload } = await jose.jwtVerify(token, secretKey);

    const sub = payload.sub as string | undefined;
    if (sub) {
      // Authenticated user — extract sub and pro claim
      userId = sub;
      const appMeta = (payload as Record<string, unknown>).app_metadata as Record<string, unknown> ?? {};
      isPro = appMeta.plan === "pro";
    } else {
      // Anon JWT (no sub) — fall back to device-level identifier
      const fallbackId = req.headers.get("X-FlowDay-User-ID");
      userId = fallbackId ? `anon:${fallbackId}` : "anon";
    }
  } catch (err) {
    console.warn("[claude] JWT verification failed:", (err as Error).message);
    return errorResponse(401, "Invalid or expired token. Please sign in again.");
  }

  console.log(`[claude] user=${userId.slice(0, 8)} isPro=${isPro}`);

  // ── Parse request body ───────────────────────────────────────────────────
  let body: ClaudeRequestBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, "Invalid JSON body");
  }

  const { feature, messages, temperature = 0.7 } = body;
  // Use per-feature default if client doesn't specify maxTokens
  const maxTokens = body.maxTokens ?? DEFAULT_MAX_TOKENS[feature as Feature] ?? 1024;

  if (!feature || !["flowAI", "templateGenerator", "emailToTask", "dayRecap"].includes(feature)) {
    return errorResponse(400, `Invalid feature: "${feature}". Must be "flowAI", "templateGenerator", "emailToTask", or "dayRecap".`);
  }

  if (!Array.isArray(messages) || messages.length === 0) {
    return errorResponse(400, "messages must be a non-empty array");
  }

  // ── Rate limiting ────────────────────────────────────────────────────────
  const dailyLimit = isPro ? PRO_DAILY_LIMIT : FREE_DAILY_LIMIT;
  if (!checkRateLimit(userId, feature, dailyLimit)) {
    const limitLabel = isPro ? `${PRO_DAILY_LIMIT}/day (Pro)` : `${FREE_DAILY_LIMIT}/day (free)`;
    console.log(`[claude] rate limited user=${userId.slice(0, 8)} feature=${feature}`);
    return errorResponse(429, `Daily AI limit reached (${limitLabel} per feature). Upgrade to Pro for unlimited access.`);
  }

  // ── Build Anthropic request with prompt caching ──────────────────────────
  const systemPrompt = SYSTEM_PROMPTS[feature as Feature];

  // Add cache breakpoints to conversation history for multi-turn caching
  const cachedMessages = feature === "flowAI"
    ? addCacheBreakpoints(messages as AnthropicMessage[])
    : messages as AnthropicMessage[];

  const anthropicRequest: AnthropicRequest = {
    model: ANTHROPIC_MODEL,
    max_tokens: maxTokens,
    temperature,
    system: [
      {
        type: "text",
        text: systemPrompt,
        // Breakpoint 1: system prompt cached after first call per feature.
        // All users share this cache — biggest cost saver.
        cache_control: { type: "ephemeral" },
      },
    ],
    messages: cachedMessages,
  };

  // ── Call Anthropic ───────────────────────────────────────────────────────
  const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!anthropicKey) {
    console.error("[claude] ANTHROPIC_API_KEY secret not set");
    return errorResponse(500, "Server configuration error");
  }

  let anthropicResponse: Response;
  try {
    anthropicResponse = await fetch(ANTHROPIC_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": anthropicKey,
        "anthropic-version": ANTHROPIC_VERSION,
      },
      body: JSON.stringify(anthropicRequest),
    });
  } catch (networkErr) {
    console.error("[claude] Network error calling Anthropic:", networkErr);
    return errorResponse(502, "Failed to reach Anthropic API");
  }

  if (!anthropicResponse.ok) {
    const errText = await anthropicResponse.text();
    console.error(`[claude] Anthropic error ${anthropicResponse.status}:`, errText);
    return errorResponse(502, `Anthropic API error ${anthropicResponse.status}: ${errText}`);
  }

  const anthropicData = await anthropicResponse.json();

  // ── Extract content ──────────────────────────────────────────────────────
  const content: string = anthropicData.content?.[0]?.text ?? "";

  // ── Log + surface cache metrics ──────────────────────────────────────────
  const usage = anthropicData.usage ?? {};
  const cacheReadTokens: number = usage.cache_read_input_tokens ?? 0;
  const cacheCreationTokens: number = usage.cache_creation_input_tokens ?? 0;
  const inputTokens: number = usage.input_tokens ?? 0;
  const outputTokens: number = usage.output_tokens ?? 0;

  const cacheStatus = cacheReadTokens > 0
    ? `HIT (${cacheReadTokens} cached tokens saved)`
    : cacheCreationTokens > 0
    ? `CREATION (${cacheCreationTokens} tokens written to cache)`
    : "MISS (no cache data)";

  // Calculate estimated cost savings
  const savedTokens = cacheReadTokens;
  const savingsPercent = inputTokens + cacheReadTokens > 0
    ? Math.round((savedTokens / (inputTokens + cacheReadTokens)) * 90)
    : 0;

  console.log(
    `[claude] feature=${feature} user=${userId.slice(0, 8)} maxTokens=${maxTokens} ` +
    `cache=${cacheStatus} input=${inputTokens} output=${outputTokens} ` +
    `savings=~${savingsPercent}%`
  );

  // ── Return response ──────────────────────────────────────────────────────
  return new Response(
    JSON.stringify({ content }),
    {
      status: 200,
      headers: {
        ...corsHeaders(),
        "Content-Type": "application/json",
        // Expose cache metrics in response headers for client-side debugging
        "X-Cache-Status": cacheReadTokens > 0 ? "HIT" : cacheCreationTokens > 0 ? "CREATION" : "MISS",
        "X-Cache-Read-Tokens": String(cacheReadTokens),
        "X-Cache-Creation-Tokens": String(cacheCreationTokens),
        "X-Input-Tokens": String(inputTokens),
        "X-Output-Tokens": String(outputTokens),
        "X-Max-Tokens": String(maxTokens),
      },
    }
  );
});

// ─── Helpers ──────────────────────────────────────────────────────────────────

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-flowday-user-id",
  };
}

function errorResponse(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}
