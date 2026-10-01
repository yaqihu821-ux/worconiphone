import http from "node:http";
import { timingSafeEqual } from "node:crypto";

const port = Number(process.env.PORT || 8787);
const apiKey = process.env.GROQ_API_KEY;
const accessToken = process.env.WORCON_ACCESS_TOKEN;
if (process.env.NODE_ENV === "production" && (!accessToken || accessToken.length < 32)) {
  throw new Error("A WORCON_ACCESS_TOKEN of at least 32 characters is required in production.");
}
const allowedModels = new Set(["openai/gpt-oss-20b", "openai/gpt-oss-120b", "qwen/qwen3.8-27b"]);
const requestTimes = new Map();
const maxBodyBytes = 64 * 1024;
const maxMessages = 24;
const maxMessageCharacters = 8_000;

function json(res, status, body) {
  res.writeHead(status, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" });
  res.end(JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > maxBodyBytes) {
        reject(Object.assign(new Error("Request is too large."), { status: 413 }));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      try { resolve(JSON.parse(Buffer.concat(chunks).toString("utf8"))); }
      catch { reject(Object.assign(new Error("Invalid JSON."), { status: 400 })); }
    });
    req.on("error", reject);
  });
}

function isRateLimited(ip) {
  const now = Date.now();
  const recent = (requestTimes.get(ip) || []).filter((time) => now - time < 60_000);
  if (recent.length >= 20) return true;
  recent.push(now);
  requestTimes.set(ip, recent);
  return false;
}

function isAuthorized(req) {
  if (!accessToken) return true; // Local development keeps its existing setup.
  const supplied = req.headers.authorization?.replace(/^Bearer\s+/i, "") || "";
  const expected = Buffer.from(accessToken);
  const actual = Buffer.from(supplied);
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

const server = http.createServer(async (req, res) => {
  if (req.method === "GET" && req.url === "/health") {
    if (!isAuthorized(req)) {
      json(res, 401, { error: "Worcon access token is missing or invalid." });
      return;
    }
    json(res, 200, { status: "ok", groqConfigured: Boolean(apiKey), authRequired: Boolean(accessToken) });
    return;
  }
  if (req.method !== "POST" || req.url !== "/v1/chat/completions") {
    json(res, 404, { error: "Not found." });
    return;
  }
  if (!isAuthorized(req)) {
    json(res, 401, { error: "Worcon access token is missing or invalid." });
    return;
  }
  if (!apiKey) {
    json(res, 503, { error: "Groq is not configured on this Mac backend." });
    return;
  }
  if (isRateLimited(req.socket.remoteAddress || "unknown")) {
    json(res, 429, { error: "Too many requests. Please wait a minute and try again." });
    return;
  }

  let body;
  try { body = await readBody(req); }
  catch (error) {
    if (!res.headersSent) json(res, error.status || 400, { error: error.message || "Invalid request." });
    return;
  }
  const { model, messages } = body || {};
  if (!allowedModels.has(model)) {
    json(res, 400, { error: "Choose an available model in Worcon settings." });
    return;
  }
  if (!Array.isArray(messages) || messages.length === 0 || messages.length > maxMessages ||
      messages.some((item) => !["system", "user", "assistant"].includes(item?.role) ||
        typeof item?.content !== "string" || item.content.length > maxMessageCharacters)) {
    json(res, 400, { error: "Messages are invalid or exceed the size limit." });
    return;
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 60_000);
  res.on("close", () => { if (!res.writableEnded) controller.abort(); });
  try {
    const upstream = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: { authorization: `Bearer ${apiKey}`, "content-type": "application/json" },
      body: JSON.stringify({ model, messages, max_completion_tokens: 2048, stream: true, store: false }),
      signal: controller.signal,
    });
    if (!upstream.ok || !upstream.body) {
      await upstream.text().catch(() => "");
      console.error(`Groq request failed with HTTP ${upstream.status}; provider details were not logged.`);
      json(res, upstream.status === 429 ? 429 : 502, {
        error: upstream.status === 429 ? "Groq usage limit reached. Please retry later." : "Groq could not complete this request. Check model availability and backend configuration.",
      });
      return;
    }

    res.writeHead(200, {
      "content-type": "text/event-stream; charset=utf-8",
      "cache-control": "no-store, no-transform",
      connection: "keep-alive",
      "x-accel-buffering": "no",
    });
    const reader = upstream.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";
      for (const line of lines) {
        if (!line.startsWith("data:")) continue;
        const data = line.slice(5).trim();
        if (data === "[DONE]") continue;
        try {
          const text = JSON.parse(data)?.choices?.[0]?.delta?.content;
          if (typeof text === "string" && text.length) res.write(`data: ${JSON.stringify({ text })}\n\n`);
        } catch { /* Ignore non-content chunks. */ }
      }
    }
    res.write("data: [DONE]\n\n");
    res.end();
  } catch (error) {
    if (!res.headersSent) json(res, error.name === "AbortError" ? 504 : 502, { error: "The model request timed out or could not reach Groq." });
    else res.destroy(error);
  } finally {
    clearTimeout(timeout);
  }
});

server.listen(port, "0.0.0.0", () => {
  console.log(`Worcon local backend listening on port ${port}; request bodies are not logged.`);
  if (!apiKey) console.log("GROQ_API_KEY is missing. Set it in this shell and restart the backend.");
});
