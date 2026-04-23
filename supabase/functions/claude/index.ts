/**
 * FlowDay — Supabase Edge Function: /functions/v1/claude
 *
 * Single endpoint used by both AI features, distinguished by the `feature` field:
 *   - "flowAI"           → Flow AI chat assistant (plan day, create task, break down goal, general chat)
 *   - "templateGenerator" → AI Template Generator (generates a task template from a user prompt)
 *
 * Security:
 *   - Validates the caller's Supabase JWT. Unauthenticated requests are rejected.
 *   - The ANTHROPIC_API_KEY lives only as a Supabase secret — never shipped in the iOS app.
 *
 * Prompt caching:
 *   - Each feature has a stable, reusable system prompt marked with cache_control: ephemeral.
 *   - Cache hits/misses are logged to the console and surfaced in response headers
 *     (X-Cache-Read-Tokens, X-Cache-Creation-Tokens) so you can verify in Supabase logs.
 *
 * Deploy:
 *   supabase functions deploy claude --no-verify-jwt=false
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ─── Types ────────────────────────────────────────────────────────────────────

type Feature = "flowAI" | "templateGenerator" | "emailToTask";

interface ClaudeRequestBody {
  feature: Feature;
  /** The caller-supplied user message(s). system prompt is added server-side. */
  messages: { role: "user" | "assistant"; content: string }[];
  temperature?: number;
  maxTokens?: number;
}

interface AnthropicMessage {
  role: "user" | "assistant";
  content: string;
}

interface AnthropicRequest {
  model: string;
  max_tokens: number;
  temperature: number;
  system: {
    type: "text";
    text: string;
    cache_control: { type: "ephemeral" };
  }[];
  messages: AnthropicMessage[];
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
};

// ─── Constants ────────────────────────────────────────────────────────────────

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
// claude-sonnet-4-5 supports prompt caching and is the latest Sonnet at time of writing
const ANTHROPIC_MODEL = "claude-sonnet-4-5";
const ANTHROPIC_VERSION = "2023-06-01";
const ANTHROPIC_BETA = "prompt-caching-2024-07-31";

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

  // ── Auth: validate Supabase JWT ──────────────────────────────────────────
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return errorResponse(401, "Missing or invalid Authorization header");
  }

  const supabaseClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    { global: { headers: { Authorization: authHeader } } }
  );

  const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
  if (authError || !user) {
    console.error("[claude] Auth failed:", authError?.message);
    return errorResponse(401, "Unauthorized");
  }

  // ── Parse request body ───────────────────────────────────────────────────
  let body: ClaudeRequestBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, "Invalid JSON body");
  }

  const { feature, messages, temperature = 0.7, maxTokens = 2048 } = body;

  if (!feature || !["flowAI", "templateGenerator", "emailToTask"].includes(feature)) {
    return errorResponse(400, `Invalid feature: "${feature}". Must be "flowAI", "templateGenerator", or "emailToTask".`);
  }

  if (!Array.isArray(messages) || messages.length === 0) {
    return errorResponse(400, "messages must be a non-empty array");
  }

  // ── Build Anthropic request with prompt caching ──────────────────────────
  const systemPrompt = SYSTEM_PROMPTS[feature];

  const anthropicRequest: AnthropicRequest = {
    model: ANTHROPIC_MODEL,
    max_tokens: maxTokens,
    temperature,
    system: [
      {
        type: "text",
        text: systemPrompt,
        // cache_control marks this text block as a caching breakpoint.
        // Anthropic will cache the tokenized system prompt after the first call.
        // Subsequent calls with the same system prompt text pay ~10% of the original cost
        // and see ~50% latency reduction for the cached portion.
        cache_control: { type: "ephemeral" },
      },
    ],
    messages,
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
        "anthropic-beta": ANTHROPIC_BETA,
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
    return errorResponse(502, `Anthropic API error: ${anthropicResponse.status}`);
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

  console.log(
    `[claude] feature=${feature} user=${user.id} ` +
    `cache=${cacheStatus} input=${inputTokens} output=${outputTokens}`
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
      },
    }
  );
});

// ─── Helpers ──────────────────────────────────────────────────────────────────

function corsHeaders(): Record<string, string> {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };
}

function errorResponse(status: number, message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders(), "Content-Type": "application/json" },
  });
}
