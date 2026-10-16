import { createClient } from "npm:@supabase/supabase-js@2";

const GEMINI_MODEL = "gemini-3.8-flash";
const MAX_IMAGE_BYTES = 12 * 1024 * 1024;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

const SYSTEM_PROMPT = `You are reading a photo of a handwritten sales register page from a water plant business.

The page is a table. Typical columns, left to right:
Time | Details (product) | Qty | Cash amount | Credit amount | Paid/Unpaid status | Name of the Party

A date is written at the top of the page, usually as dd/mm/yy (for example 12/10/26 means 2026-10-12). Convert it to YYYY-MM-DD. Ignore machine labels such as "Machine A" or notes such as "Jumbo Filters changed".

For EACH real sales row on the page, extract:
- "time": text from the Time column (for example "11:00", "4:20"). If a time cell is blank, carry down the nearest time written above it in the same column. Use "" only when no time appears at all.
- "product": the Details column text, kept short (for example "Bags", "500ml", "300ml").
- "quantity": the Qty as a number (strip leading zeros, for example "01" -> 1).
- "amount": the money for that row. Use the Cash column value if it has a number, otherwise the Credit column value. Do not include crossed-out numbers.
- "paid": true ONLY when the Paid/Unpaid status column clearly says paid or received. If it says credit, unpaid, is blank, or is ambiguous, set false.
- "customer": the party/customer name from the last column. Transcribe it as faithfully as you can.

SKIP these kinds of rows entirely:
- title, header, and column-header rows
- crossed-out or struck-through rows
- total or summary rows (for example "316", "134 bags")
- free-text notes that are not sales entries

Rules:
- Be conservative. A wrong guess is worse than a missing row.
- If the image is not a handwritten sales register page, return an empty rows array and "" for date.
- If no date can be read, return "" for date.
- quantity and amount must be numbers, never null.`;

const responseSchema = {
  type: "OBJECT",
  properties: {
    date: { type: "STRING" },
    rows: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          time: { type: "STRING" },
          product: { type: "STRING" },
          quantity: { type: "NUMBER" },
          amount: { type: "NUMBER" },
          paid: { type: "BOOLEAN" },
          customer: { type: "STRING" },
        },
        required: ["product", "quantity", "amount", "paid", "customer"],
      },
    },
  },
  required: ["date", "rows"],
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "");
  if (!jwt) {
    return json({ error: "Missing authorization" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const supabase = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });
  const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
  if (userError || !userData?.user) {
    return json({ error: "Invalid or expired session" }, 401);
  }

  const apiKey =
    Deno.env.get("GEMINI_API_KEY") ?? Deno.env.get("gemini_api_key");
  if (!apiKey) {
    return json({ error: "GEMINI_API_KEY is not configured" }, 500);
  }

  let imageBase64 = "";
  let mimeType = "image/jpeg";
  try {
    const body = await req.json();
    imageBase64 = typeof body?.image_base64 === "string" ? body.image_base64.trim() : "";
    if (typeof body?.mime_type === "string" && body.mime_type.trim()) {
      mimeType = body.mime_type.trim();
    }
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  if (!imageBase64) {
    return json({ error: "image_base64 is required" }, 400);
  }
  const approxBytes = Math.floor(imageBase64.length * 0.75);
  if (approxBytes > MAX_IMAGE_BYTES) {
    return json({ error: "Image is too large. Please use a smaller photo." }, 400);
  }

  const geminiUrl =
    `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`;

  let geminiResponse: Response;
  try {
    geminiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: SYSTEM_PROMPT },
              {
                inlineData: {
                  mimeType: mimeType,
                  data: imageBase64,
                },
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0,
          responseMimeType: "application/json",
          responseSchema,
        },
      }),
    });
  } catch {
    return json({ error: "Failed to reach the AI service" }, 502);
  }

  if (!geminiResponse.ok) {
    const detail = await geminiResponse.text().catch(() => "");
    console.error("Gemini error", geminiResponse.status, detail.slice(0, 500));
    let hint = "";
    try {
      const parsedDetail = JSON.parse(detail);
      hint =
        parsedDetail?.error?.message ??
        parsedDetail?.error?.status ??
        "";
    } catch {
      hint = detail.slice(0, 200);
    }
    return json(
      {
        error: `AI service error (${geminiResponse.status})`,
        detail: hint,
      },
      502,
    );
  }

  let geminiData: {
    candidates?: Array<{
      content?: { parts?: Array<{ text?: string }> };
      finishReason?: string;
    }>;
  };
  try {
    geminiData = await geminiResponse.json();
  } catch {
    return json({ error: "AI service returned an unreadable response" }, 502);
  }

  const text = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    const finish = geminiData.candidates?.[0]?.finishReason;
    if (finish && finish !== "STOP") {
      return json({ error: `AI stopped early (${finish}). Please try again.` }, 502);
    }
    return json({ error: "No data extracted from the image" }, 502);
  }

  let parsed: { date?: string; rows?: Array<Record<string, unknown>> };
  try {
    parsed = JSON.parse(text);
  } catch {
    return json({ error: "AI returned invalid data. Please try again." }, 502);
  }

  const rawRows = Array.isArray(parsed.rows) ? parsed.rows : [];
  const rows = rawRows
    .map((r) => {
      const product = typeof r?.product === "string" ? r.product.trim() : "";
      const customer = typeof r?.customer === "string" ? r.customer.trim() : "";
      const time = typeof r?.time === "string" ? r.time.trim() : "";
      const quantity = Number(r?.quantity);
      const amount = Number(r?.amount);
      const paid = r?.paid === true || r?.paid === "true";
      return { time, product, quantity, amount, paid, customer };
    })
    .filter(
      (r) =>
        r.product.length > 0 &&
        Number.isFinite(r.quantity) &&
        r.quantity > 0 &&
        Number.isFinite(r.amount) &&
        r.amount > 0,
    );

  const date = typeof parsed.date === "string" ? parsed.date.trim() : "";
  return json({ date, rows });
});
