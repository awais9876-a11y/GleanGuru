// api/chat.js
// Vercel Edge Function: proxies chat requests to Alibaba Cloud Dashscope
// (Qwen) so the API key never has to be shipped to the browser/client.
export const config = {
  runtime: "edge",
};

// Use the international Dashscope endpoint by default. If your API key was
// issued in the Mainland China console, set DASHSCOPE_ENDPOINT to
// "https://dashscope.aliyuncs.com/api/v1" instead.
const DASHSCOPE_BASE_URL =
  process.env.DASHSCOPE_ENDPOINT || "https://dashscope-intl.aliyuncs.com/api/v1";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

export default async function handler(req) {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return new Response("Method not allowed", {
      status: 405,
      headers: CORS_HEADERS,
    });
  }

  const apiKey = process.env.QWEN_API_KEY;
  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: "Missing QWEN_API_KEY environment variable" }),
      { status: 500, headers: { "Content-Type": "application/json", ...CORS_HEADERS } },
    );
  }

  try {
    const body = await req.json();

    const response = await fetch(
      `${DASHSCOPE_BASE_URL}/services/aigc/text-generation/generation`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify(body),
      },
    );

    const data = await response.json();
    return new Response(JSON.stringify(data), {
      status: response.status,
      headers: { "Content-Type": "application/json", ...CORS_HEADERS },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json", ...CORS_HEADERS },
    });
  }
}
