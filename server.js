// server.js
// Node/Express server used when deploying via Docker (e.g. Alibaba Cloud
// Container Registry + ECS/ACK/SAE, or any other Docker host). It serves the
// compiled Flutter web build AND exposes POST /api/chat, mirroring
// api/chat.js so the same Flutter client code works unmodified on both
// Vercel and a plain Docker deployment.
const express = require("express");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 8080;

const DASHSCOPE_BASE_URL =
  process.env.DASHSCOPE_ENDPOINT || "https://dashscope-intl.aliyuncs.com/api/v1";

app.use(express.json({ limit: "2mb" }));

// --- API: chat proxy (same contract as api/chat.js on Vercel) -------------
app.post("/api/chat", async (req, res) => {
  const apiKey = process.env.QWEN_API_KEY;
  if (!apiKey) {
    return res.status(500).json({ error: "Missing QWEN_API_KEY environment variable" });
  }

  try {
    const response = await fetch(
      `${DASHSCOPE_BASE_URL}/services/aigc/text-generation/generation`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify(req.body),
      },
    );

    const data = await response.json();
    res.status(response.status).json(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/healthz", (_req, res) => res.status(200).send("ok"));

// --- Static Flutter web build ----------------------------------------------
const WEB_ROOT = path.join(__dirname, "build", "web");

app.use(
  express.static(WEB_ROOT, {
    maxAge: "1y",
    setHeaders: (res, filePath) => {
      // Never cache the HTML entry point, otherwise browsers/CDNs can pin
      // users to a stale bundle after a redeploy.
      if (filePath.endsWith("index.html")) {
        res.setHeader("Cache-Control", "no-cache");
      }
    },
  }),
);

// SPA fallback: any route that isn't a static file or /api/* goes to
// index.html so Flutter's router (go_router) can handle client-side routes
// like /home or /profile without a 404 on refresh/deep link.
app.get("*", (req, res) => {
  if (req.path.startsWith("/api/")) {
    return res.status(404).json({ error: "Not found" });
  }
  res.sendFile(path.join(WEB_ROOT, "index.html"));
});

app.listen(PORT, () => {
  console.log(`Memory Agent server listening on port ${PORT}`);
});
