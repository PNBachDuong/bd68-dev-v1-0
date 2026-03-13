#!/usr/bin/env node
"use strict";

const http = require("http");
const fs = require("fs");
const path = require("path");
const { pipeline } = require("stream/promises");

const PORT = parseInt(process.env.CONTEXT_GUARD_PROXY_PORT || "8787", 10);
const UPSTREAM_BASE_URL = process.env.CONTEXT_GUARD_UPSTREAM_BASE_URL || "https://llmgate.app/v1";
const SOFT_THRESHOLD = parseInt(process.env.CONTEXT_GUARD_SOFT_THRESHOLD || "200000", 10);
const ESCALATE_THRESHOLD = parseInt(process.env.CONTEXT_GUARD_ESCALATE_THRESHOLD || "240000", 10);
const HARD_THRESHOLD = parseInt(process.env.CONTEXT_GUARD_HARD_THRESHOLD || "250000", 10);
const APPLY_AT_SOFT = /^(1|true|yes)$/i.test(process.env.CONTEXT_GUARD_APPLY_AT_SOFT || "false");
const LOG_FILE = process.env.CONTEXT_GUARD_LOG_FILE || "";

if (!(SOFT_THRESHOLD <= ESCALATE_THRESHOLD && ESCALATE_THRESHOLD <= HARD_THRESHOLD)) {
  throw new Error("Invalid thresholds: require soft <= escalate <= hard.");
}

function estimateTokensFromChars(chars) {
  return Math.round(chars / 4);
}

function safeJsonParse(raw) {
  try {
    return { ok: true, value: JSON.parse(raw) };
  } catch (err) {
    return { ok: false, error: String(err) };
  }
}

function toSafeNumber(value) {
  if (value === null || value === undefined) return null;
  const n = Number(value);
  if (!Number.isFinite(n)) return null;
  return Math.trunc(n);
}

function extractUsageTokens(parsedBody) {
  if (!parsedBody || typeof parsedBody !== "object") {
    return { modelInputTokens: null, modelOutputTokens: null };
  }

  const usage =
    parsedBody.usage ||
    (parsedBody.response && parsedBody.response.usage) ||
    (parsedBody.data && parsedBody.data.usage) ||
    null;

  if (!usage || typeof usage !== "object") {
    return { modelInputTokens: null, modelOutputTokens: null };
  }

  const modelInputTokens =
    toSafeNumber(usage.input_tokens) ??
    toSafeNumber(usage.prompt_tokens) ??
    toSafeNumber(usage.input) ??
    toSafeNumber(usage.prompt) ??
    null;

  const modelOutputTokens =
    toSafeNumber(usage.output_tokens) ??
    toSafeNumber(usage.completion_tokens) ??
    toSafeNumber(usage.output) ??
    toSafeNumber(usage.completion) ??
    null;

  return { modelInputTokens, modelOutputTokens };
}

function flattenText(content) {
  if (typeof content === "string") {
    return content;
  }
  if (Array.isArray(content)) {
    const parts = [];
    for (const chunk of content) {
      if (!chunk || typeof chunk !== "object") continue;
      if (typeof chunk.text === "string") parts.push(chunk.text);
      if (chunk.image_url && typeof chunk.image_url.url === "string") parts.push(chunk.image_url.url);
    }
    return parts.join(" ");
  }
  if (content && typeof content === "object" && Array.isArray(content.multiple_content)) {
    const parts = [];
    for (const chunk of content.multiple_content) {
      if (!chunk || typeof chunk !== "object") continue;
      if (typeof chunk.text === "string") parts.push(chunk.text);
      if (chunk.image_url && typeof chunk.image_url.url === "string") parts.push(chunk.image_url.url);
    }
    return parts.join(" ");
  }
  return "";
}

function truncateToolOutput(text, maxChars) {
  if (typeof text !== "string" || text.length <= maxChars) {
    return text;
  }
  const head = Math.floor(maxChars * 0.65);
  const tail = maxChars - head;
  return text.slice(0, head) + "\n... [truncated by context guard proxy] ...\n" + text.slice(text.length - tail);
}

function replaceInlineBase64InArray(chunks) {
  if (!Array.isArray(chunks)) return chunks;
  return chunks.map((chunk) => {
    if (!chunk || typeof chunk !== "object") return chunk;
    if (
      chunk.image_url &&
      typeof chunk.image_url.url === "string" &&
      chunk.image_url.url.startsWith("data:image/")
    ) {
      return {
        type: "text",
        text: `[image omitted by context guard proxy; inline data url length=${chunk.image_url.url.length}]`,
      };
    }
    return chunk;
  });
}

function sanitizeMessage(message, cfg) {
  if (!message || typeof message !== "object") return null;
  const msg = structuredClone(message);
  const role = String(msg.role || "");
  const flatText = flattenText(msg.content);

  if (role === "user" && flatText.startsWith('{"content":null,"encrypted_content"')) {
    return null;
  }
  if (role === "user" && flatText.startsWith('{"action":')) {
    return null;
  }

  if (role === "tool" && typeof msg.content === "string") {
    msg.content = truncateToolOutput(msg.content, cfg.toolMaxChars);
  }

  if (Array.isArray(msg.content)) {
    msg.content = replaceInlineBase64InArray(msg.content);
  } else if (msg.content && typeof msg.content === "object" && Array.isArray(msg.content.multiple_content)) {
    msg.content.multiple_content = replaceInlineBase64InArray(msg.content.multiple_content);
  }

  return msg;
}

function sanitizeMessageArray(messages, cfg) {
  const sanitized = [];
  for (const msg of messages) {
    const cleaned = sanitizeMessage(msg, cfg);
    if (cleaned) sanitized.push(cleaned);
  }

  const dialogIdx = [];
  sanitized.forEach((m, idx) => {
    const role = String(m.role || "");
    if (role !== "system" && role !== "developer") {
      dialogIdx.push(idx);
    }
  });

  const keepSet = new Set();
  const start = Math.max(0, dialogIdx.length - cfg.keepLastDialogMessages);
  for (let i = start; i < dialogIdx.length; i += 1) {
    keepSet.add(dialogIdx[i]);
  }

  const finalMessages = [];
  sanitized.forEach((m, idx) => {
    const role = String(m.role || "");
    if (role === "system" || role === "developer" || keepSet.has(idx)) {
      finalMessages.push(m);
    }
  });

  return finalMessages;
}

function profileForMode(mode) {
  if (mode === "Safe") {
    return { keepLastDialogMessages: 200, toolMaxChars: 3000, dropAltRepresentation: false };
  }
  if (mode === "Balanced") {
    return { keepLastDialogMessages: 120, toolMaxChars: 1200, dropAltRepresentation: true };
  }
  if (mode === "Aggressive") {
    return { keepLastDialogMessages: 80, toolMaxChars: 600, dropAltRepresentation: true };
  }
  throw new Error(`Unsupported mode: ${mode}`);
}

function autoDecision(tokensEstimate) {
  if (tokensEstimate >= HARD_THRESHOLD) {
    return { trigger: "hard_active", mode: "Aggressive", apply: true, reason: ">= hard threshold" };
  }
  if (tokensEstimate >= ESCALATE_THRESHOLD) {
    return { trigger: "soft_escalated", mode: "Balanced", apply: true, reason: ">= escalate threshold" };
  }
  if (tokensEstimate >= SOFT_THRESHOLD) {
    if (APPLY_AT_SOFT) {
      return { trigger: "soft_prepare", mode: "Balanced", apply: true, reason: ">= soft threshold and apply_at_soft enabled" };
    }
    return { trigger: "soft_prepare", mode: "N/A", apply: false, reason: ">= soft threshold, prepare next heavy turn" };
  }
  return { trigger: "inactive", mode: "N/A", apply: false, reason: "< soft threshold" };
}

function applyGuardTransform(payload, mode) {
  const cfg = profileForMode(mode);
  const out = structuredClone(payload);
  let touchedCollections = 0;

  if (Array.isArray(out.messages)) {
    out.messages = sanitizeMessageArray(out.messages, cfg);
    touchedCollections += 1;
  }

  if (out.extra_body && Array.isArray(out.extra_body.messages)) {
    out.extra_body.messages = sanitizeMessageArray(out.extra_body.messages, cfg);
    touchedCollections += 1;
  }

  if (Array.isArray(out.input)) {
    const looksLikeMessages = out.input.every((item) => item && typeof item === "object" && ("role" in item || "content" in item));
    if (looksLikeMessages) {
      out.input = sanitizeMessageArray(out.input, cfg);
      touchedCollections += 1;
    }
  }

  if (
    cfg.dropAltRepresentation &&
    Array.isArray(out.messages) &&
    out.extra_body &&
    Array.isArray(out.extra_body.messages) &&
    out.extra_body.messages.length > 0 &&
    out.messages.length > 0
  ) {
    out.messages = [];
  }

  return { payload: out, touchedCollections };
}

function buildUpstreamUrl(reqUrl) {
  const upstream = new URL(UPSTREAM_BASE_URL);
  let basePath = upstream.pathname || "";
  basePath = basePath.replace(/\/+$/, "");

  const parsedReq = new URL(reqUrl || "/", "http://127.0.0.1");
  let reqPath = parsedReq.pathname || "/";
  if (!reqPath.startsWith("/")) {
    reqPath = "/" + reqPath;
  }

  // Avoid duplicate /v1 when client already sends /v1/* and upstream base also ends with /v1.
  if (basePath.endsWith("/v1") && (reqPath === "/v1" || reqPath.startsWith("/v1/"))) {
    reqPath = reqPath.slice(3);
    if (!reqPath.startsWith("/")) {
      reqPath = "/" + reqPath;
    }
    if (reqPath.length === 0) {
      reqPath = "/";
    }
  }

  const joinedPath = (basePath + reqPath).replace(/\/{2,}/g, "/");
  return `${upstream.origin}${joinedPath}${parsedReq.search || ""}`;
}

function copyRequestHeaders(headers, contentLength) {
  const out = {};
  for (const [k, v] of Object.entries(headers)) {
    const key = k.toLowerCase();
    if (["host", "content-length", "connection", "transfer-encoding"].includes(key)) continue;
    if (v === undefined) continue;
    out[key] = v;
  }
  if (contentLength >= 0) {
    out["content-length"] = String(contentLength);
  }
  return out;
}

function copyResponseHeaders(headers) {
  const out = {};
  headers.forEach((v, k) => {
    const key = k.toLowerCase();
    if (["connection", "transfer-encoding", "content-encoding"].includes(key)) return;
    out[k] = v;
  });
  return out;
}

function logLine(line) {
  console.log(line);
  if (LOG_FILE) {
    try {
      fs.mkdirSync(path.dirname(LOG_FILE), { recursive: true });
      fs.appendFileSync(LOG_FILE, line + "\n", "utf8");
    } catch (_) {
      // ignore log file errors
    }
  }
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

const server = http.createServer(async (req, res) => {
  if (req.method === "GET" && req.url === "/__guard/health") {
    const payload = {
      ok: true,
      port: PORT,
      upstream: UPSTREAM_BASE_URL,
      thresholds: {
        soft: SOFT_THRESHOLD,
        escalate: ESCALATE_THRESHOLD,
        hard: HARD_THRESHOLD,
      },
      applyAtSoft: APPLY_AT_SOFT,
    };
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify(payload));
    return;
  }

  if (req.method === "GET" && req.url && req.url.startsWith("/__guard/map")) {
    const mapUrl = new URL(req.url, "http://127.0.0.1");
    const testPath = mapUrl.searchParams.get("path") || "/";
    const mapped = buildUpstreamUrl(testPath);
    const payload = {
      ok: true,
      upstreamBaseUrl: UPSTREAM_BASE_URL,
      inputPath: testPath,
      mappedUrl: mapped,
    };
    res.writeHead(200, { "content-type": "application/json" });
    res.end(JSON.stringify(payload));
    return;
  }

  const startedAt = Date.now();
  let rawBody = Buffer.alloc(0);
  let outgoingBody = Buffer.alloc(0);
  let parsedJson = null;
  let parseError = "";
  let preTokens = 0;
  let postTokens = 0;
  let decision = { trigger: "inactive", mode: "N/A", apply: false, reason: "no body" };
  let reductionPct = 0;
  let modelInputTokens = null;
  let modelOutputTokens = null;
  let responseStreamed = false;
  let responseUsageParse = "na";

  try {
    if (!["GET", "HEAD"].includes(req.method || "")) {
      rawBody = await readBody(req);
    }

    outgoingBody = rawBody;
    preTokens = estimateTokensFromChars(rawBody.length);
    postTokens = preTokens;

    const contentType = String(req.headers["content-type"] || "");
    const shouldParseJson = outgoingBody.length > 0 && contentType.includes("application/json");

    if (shouldParseJson) {
      const rawText = outgoingBody.toString("utf8");
      const parsed = safeJsonParse(rawText);
      if (parsed.ok) {
        parsedJson = parsed.value;
        decision = autoDecision(preTokens);
        if (decision.apply) {
          const transformed = applyGuardTransform(parsedJson, decision.mode);
          if (transformed.touchedCollections > 0) {
            const nextRaw = JSON.stringify(transformed.payload);
            outgoingBody = Buffer.from(nextRaw, "utf8");
            postTokens = estimateTokensFromChars(outgoingBody.length);
            if (preTokens > 0) {
              reductionPct = Math.round(((preTokens - postTokens) / preTokens) * 10000) / 100;
            }
          } else {
            decision = { ...decision, apply: false, mode: "N/A", reason: "no message collections found to sanitize" };
          }
        }
      } else {
        parseError = parsed.error;
        decision = { trigger: "parse_failed", mode: "N/A", apply: false, reason: "json parse failed" };
      }
    }

    const upstreamUrl = buildUpstreamUrl(req.url || "/");
    const headers = copyRequestHeaders(req.headers, outgoingBody.length);

    const upstreamResp = await fetch(upstreamUrl, {
      method: req.method,
      headers,
      body: ["GET", "HEAD"].includes(req.method || "") ? undefined : outgoingBody,
      duplex: "half",
    });

    const responseHeaders = copyResponseHeaders(upstreamResp.headers);
    responseHeaders["x-context-guard-mode"] = decision.mode;
    responseHeaders["x-context-guard-trigger"] = decision.trigger;
    responseHeaders["x-context-guard-applied"] = String(decision.apply);
    responseHeaders["x-context-guard-pretokens"] = String(preTokens);
    responseHeaders["x-context-guard-posttokens"] = String(postTokens);

    const upstreamContentType = String(upstreamResp.headers.get("content-type") || "");
    const isEventStream = upstreamContentType.includes("text/event-stream");
    responseStreamed = isEventStream;

    if (isEventStream) {
      responseHeaders["x-context-guard-model-input-tokens"] = "N/A";
      responseHeaders["x-context-guard-model-output-tokens"] = "N/A";
      responseHeaders["x-context-guard-response-streamed"] = "true";

      res.writeHead(upstreamResp.status, responseHeaders);
      if (upstreamResp.body) {
        await pipeline(upstreamResp.body, res);
      } else {
        res.end();
      }
    } else {
      let upstreamBuffer = Buffer.alloc(0);
      if (upstreamResp.body) {
        const ab = await upstreamResp.arrayBuffer();
        upstreamBuffer = Buffer.from(ab);
      }

      if (upstreamContentType.includes("application/json") && upstreamBuffer.length > 0) {
        const parsedResp = safeJsonParse(upstreamBuffer.toString("utf8"));
        if (parsedResp.ok) {
          const usageTokens = extractUsageTokens(parsedResp.value);
          modelInputTokens = usageTokens.modelInputTokens;
          modelOutputTokens = usageTokens.modelOutputTokens;
          responseUsageParse =
            modelInputTokens === null && modelOutputTokens === null ? "ok_no_usage" : "ok_with_usage";
        } else {
          responseUsageParse = "json_parse_failed";
        }
      } else if (upstreamBuffer.length > 0) {
        responseUsageParse = "non_json";
      }

      responseHeaders["x-context-guard-model-input-tokens"] =
        modelInputTokens === null ? "N/A" : String(modelInputTokens);
      responseHeaders["x-context-guard-model-output-tokens"] =
        modelOutputTokens === null ? "N/A" : String(modelOutputTokens);
      responseHeaders["x-context-guard-response-streamed"] = "false";
      responseHeaders["content-length"] = String(upstreamBuffer.length);

      res.writeHead(upstreamResp.status, responseHeaders);
      res.end(upstreamBuffer);
    }
  } catch (err) {
    res.writeHead(502, { "content-type": "application/json" });
    res.end(
      JSON.stringify({
        error: "context_guard_proxy_upstream_failure",
        detail: String(err),
      })
    );
  } finally {
    const durationMs = Date.now() - startedAt;
    const line = [
      new Date().toISOString(),
      `method=${req.method}`,
      `path=${req.url}`,
      `trigger=${decision.trigger}`,
      `mode=${decision.mode}`,
      `applied=${decision.apply}`,
      `pre=${preTokens}`,
      `post=${postTokens}`,
      `reduction_pct=${reductionPct}`,
      `model_in=${modelInputTokens === null ? "na" : modelInputTokens}`,
      `model_out=${modelOutputTokens === null ? "na" : modelOutputTokens}`,
      `resp_stream=${responseStreamed ? "yes" : "no"}`,
      `usage_parse=${responseUsageParse}`,
      `parse_error=${parseError ? "yes" : "no"}`,
      `duration_ms=${durationMs}`,
    ].join(" ");
    logLine(line);
  }
});

server.listen(PORT, "127.0.0.1", () => {
  logLine(
    `${new Date().toISOString()} context_guard_proxy_started port=${PORT} upstream=${UPSTREAM_BASE_URL} soft=${SOFT_THRESHOLD} escalate=${ESCALATE_THRESHOLD} hard=${HARD_THRESHOLD} apply_at_soft=${APPLY_AT_SOFT}`
  );
});
