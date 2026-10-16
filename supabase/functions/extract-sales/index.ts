import { createClient } from "npm:@supabase/supabase-js@2";

const LLAMA_API = "https://api.cloud.llamaindex.ai";
const PARSE_TIER = "agentic";
const MAX_IMAGE_BYTES = 12 * 1024 * 1024;
const POLL_INTERVAL_MS = 2500;
const POLL_TIMEOUT_MS = 120000;

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

const CUSTOM_PROMPT = `This is a handwritten sales register page from a water plant business.
The page is a table with columns, typically: Time | Details (product) | Qty | Cash amount | Credit amount | Paid/Unpaid status | Name of the Party.

Rewrite the page content as a single GitHub-flavored markdown pipe table with exactly these columns (header row required):
Time | Product | Quantity | Amount | Paid | Customer

Rules:
- One markdown table row per real sales row on the page.
- Product = Details column text (short, e.g. "Bags", "500ml").
- Quantity = numeric qty only.
- Amount = Cash column number if present, else Credit column number (no currency symbols).
- Paid = "yes" only when the Paid/Unpaid column clearly says paid/received; otherwise "no".
- Customer = party name from the last column.
- Skip header/title rows, crossed-out rows, totals/summary rows (e.g. "316", "134 bags"), and free-text notes.
- Put the page date (if any, convert dd/mm/yy to YYYY-MM-DD) on its own line BEFORE the table, like: Date: YYYY-MM-DD
- If there are no sales rows, output only "Date: " (if unknown) and no table.`;

function extForMime(mime: string): string {
  if (mime.includes("png")) return "png";
  if (mime.includes("webp")) return "webp";
  if (mime.includes("heic") || mime.includes("heif")) return "heic";
  return "jpg";
}

function parseAmount(raw: string): number {
  const cleaned = raw.replace(/[₹,\s]/g, "").replace(/[^\d.]/g, "");
  const n = Number.parseFloat(cleaned);
  return Number.isFinite(n) ? n : 0;
}

function looksLikeHeader(cells: string[]): boolean {
  const joined = cells.join(" ").toLowerCase();
  return (
    joined.includes("time") ||
    joined.includes("details") ||
    joined.includes("party") ||
    joined.includes("qty") ||
    joined.includes("cash")
  );
}

function looksLikeTotal(cells: string[]): boolean {
  const joined = cells.join(" ").toLowerCase();
  return joined.includes("total") || joined.includes("carry");
}

function paidFromCell(cell: string): boolean {
  const c = cell.toLowerCase();
  if (c.includes("unpaid") || c.includes("credit") || c.includes("due")) {
    return false;
  }
  return c.includes("paid") || c.includes("received") || c === "yes";
}

function rowsFromMarkdown(markdown: string): Array<{
  time: string;
  product: string;
  quantity: number;
  amount: number;
  paid: boolean;
  customer: string;
}> {
  const rows: Array<{
    time: string;
    product: string;
    quantity: number;
    amount: number;
    paid: boolean;
    customer: string;
  }> = [];
  const lines = markdown.split(/\r?\n/);
  let lastTime = "";

  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line.startsWith("|")) continue;
    const cells = line
      .split("|")
      .map((c) => c.replace(/<br\s*\/?>/gi, " ").trim())
      .filter((c, i, arr) => !(c === "" && (i === 0 || i === arr.length - 1)));
    if (cells.length < 5) continue;
    if (cells.every((c) => /^[-: ]*$/.test(c))) continue;
    if (looksLikeHeader(cells)) continue;
    if (looksLikeTotal(cells)) continue;

    let time = cells[0];
    const productCell = cells[1];
    const qtyCell = cells[2];
    const amountCell = cells[3];
    const paidCell = cells.length >= 6 ? cells[4] : "";
    const customerCell = cells[cells.length - 1];

    if (/^\d{1,2}:\d{2}/.test(time)) {
      lastTime = time;
    } else if (time.trim() === "" || /^[-—–.]+$/.test(time)) {
      time = lastTime;
    } else if (time.length > 12) {
      time = lastTime;
    }

    const quantity = parseAmount(qtyCell);
    const amount = parseAmount(amountCell) || parseAmount(paidCell);
    const product = productCell.replace(/\s+/g, " ").trim();
    const customer = customerCell.replace(/\s+/g, " ").trim();

    if (!product || quantity <= 0 || amount <= 0) continue;
    if (/^[\d.,\s]*$/.test(product) && customer.length === 0) continue;

    let paid = paidFromCell(paidCell);
    if (cells.length >= 6) {
      paid = paidFromCell(paidCell);
    } else {
      paid = paidFromCell(customerCell) || paidFromCell(paidCell);
      if (paid && /credit/i.test(customerCell)) paid = false;
    }

    rows.push({
      time: /^\d{1,2}:\d{2}/.test(time) ? time : "",
      product,
      quantity,
      amount,
      paid,
      customer: customer.replace(/\s*\(.*$/, "").trim(),
    });
  }

  return rows;
}

function dateFromMarkdown(markdown: string): string {
  const m = markdown.match(
    /(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})/,
  );
  if (!m) return "";
  let day = Number.parseInt(m[1], 10);
  let month = Number.parseInt(m[2], 10);
  let year = Number.parseInt(m[3], 10);
  if (year < 100) year += 2000;
  if (month > 12 && day <= 12) {
    const t = day;
    day = month;
    month = t;
  }
  if (day < 1 || day > 31 || month < 1 || month > 12) return "";
  const mm = String(month).padStart(2, "0");
  const dd = String(day).padStart(2, "0");
  return `${year}-${mm}-${dd}`;
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

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
    Deno.env.get("LLAMA_CLOUD_API_KEY") ??
    Deno.env.get("llama_cloud_api_key");
  if (!apiKey) {
    return json(
      { error: "LLAMA_CLOUD_API_KEY is not configured" },
      500,
    );
  }

  let imageBase64 = "";
  let mimeType = "image/jpeg";
  try {
    const body = await req.json();
    imageBase64 =
      typeof body?.image_base64 === "string" ? body.image_base64.trim() : "";
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
    return json(
      { error: "Image is too large. Please use a smaller photo." },
      400,
    );
  }

  const binary = Uint8Array.from(atob(imageBase64), (c) => c.charCodeAt(0));
  const filename = `register.${extForMime(mimeType)}`;

  const authHeaders = { Authorization: `Bearer ${apiKey}` };

  let fileId = "";
  try {
    const form = new FormData();
    form.set("purpose", "parse");
    form.set("file", new Blob([binary], { type: mimeType }), filename);
    const uploadRes = await fetch(`${LLAMA_API}/api/v1/beta/files`, {
      method: "POST",
      headers: authHeaders,
      body: form,
    });
    if (!uploadRes.ok) {
      const detail = await uploadRes.text().catch(() => "");
      console.error("Llama upload error", uploadRes.status, detail.slice(0, 400));
      let hint = "";
      try {
        const parsed = JSON.parse(detail);
        hint =
          parsed?.error?.message ??
          parsed?.message ??
          parsed?.detail ??
          parsed?.error ??
          "";
      } catch {
        hint = detail.slice(0, 200);
      }
      if (uploadRes.status === 401) {
        hint =
          hint ||
          "LlamaCloud rejected the API key. Re-set LLAMA_CLOUD_API_KEY with no spaces/newlines and check the key at cloud.llamaindex.ai.";
      }
      return json(
        {
          error: `Document upload failed (${uploadRes.status})`,
          detail: hint,
        },
        502,
      );
    }
    const uploadData = await uploadRes.json();
    fileId = uploadData?.id ?? "";
    if (!fileId) {
      return json(
        { error: "Document upload failed", detail: "No file id returned" },
        502,
      );
    }
  } catch {
    return json({ error: "Could not reach the document service" }, 502);
  }

  let jobId = "";
  try {
    const jobRes = await fetch(`${LLAMA_API}/api/v2/parse`, {
      method: "POST",
      headers: { ...authHeaders, "Content-Type": "application/json" },
      body: JSON.stringify({
        file_id: fileId,
        tier: PARSE_TIER,
        version: "latest",
        client_name: "wateros-scan-sales",
        agentic_options: { custom_prompt: CUSTOM_PROMPT },
        input_options: {
          image: { camera_photo_correction: true },
        },
        processing_options: {
          aggressive_table_extraction: true,
        },
        output_options: {
          markdown: {
            tables: {
              output_tables_as_markdown: true,
              compact_markdown_tables: true,
            },
          },
        },
      }),
    });
    if (!jobRes.ok) {
      const detail = await jobRes.text().catch(() => "");
      console.error("Llama parse create error", jobRes.status, detail.slice(0, 400));
      let hint = "";
      try {
        const parsed = JSON.parse(detail);
        hint = parsed?.error?.message ?? parsed?.message ?? parsed?.detail ?? "";
      } catch {
        hint = detail.slice(0, 200);
      }
      return json(
        {
          error: `Could not start parsing (${jobRes.status})`,
          detail: hint,
        },
        502,
      );
    }
    const jobData = await jobRes.json();
    jobId = jobData?.id ?? "";
    if (!jobId) {
      return json(
        { error: "Could not start parsing", detail: "No job id returned" },
        502,
      );
    }
  } catch {
    return json({ error: "Could not reach the document service" }, 502);
  }

  const deadline = Date.now() + POLL_TIMEOUT_MS;
  let status = "";
  let jobError = "";
  while (Date.now() < deadline) {
    await sleep(POLL_INTERVAL_MS);
    try {
      const pollRes = await fetch(
        `${LLAMA_API}/api/v2/parse/${jobId}?expand=markdown,markdown_full,text_full`,
        { headers: authHeaders },
      );
      if (!pollRes.ok) {
        continue;
      }
      const pollData = await pollRes.json();
      const job = pollData?.job ?? pollData;
      status = job?.status ?? "";
      if (status === "FAILED" || status === "CANCELLED") {
        jobError = job?.error_message ?? "Parsing failed";
        break;
      }
      if (status === "COMPLETED") {
        let markdown = "";
        if (typeof pollData?.markdown_full === "string") {
          markdown = pollData.markdown_full;
        } else if (typeof pollData?.text_full === "string") {
          markdown = pollData.text_full;
        } else if (Array.isArray(pollData?.markdown?.pages)) {
          markdown = pollData.markdown.pages
            .map((p: { markdown?: string }) => p?.markdown ?? "")
            .join("\n");
        } else if (typeof pollData?.markdown === "string") {
          markdown = pollData.markdown;
        }

        const rows = rowsFromMarkdown(markdown);
        let date = dateFromMarkdown(markdown);

        if (rows.length === 0 && markdown.trim().length > 0) {
          const plain = markdown.replace(/[#*`>]/g, "");
          const lines = plain.split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
          for (const line of lines) {
            if (!/\d/.test(line)) continue;
            const parts = line.split(/\s{2,}|\t/).map((p) => p.trim()).filter(Boolean);
            if (parts.length < 5) continue;
            const quantity = parseAmount(parts[2] ?? "");
            const amount = parseAmount(parts[3] ?? "");
            if (quantity <= 0 || amount <= 0) continue;
            rows.push({
              time: /^\d{1,2}:\d{2}/.test(parts[0] ?? "") ? parts[0] : "",
              product: (parts[1] ?? "").slice(0, 40),
              quantity,
              amount,
              paid: paidFromCell(parts[4] ?? ""),
              customer: (parts[parts.length - 1] ?? "").slice(0, 80),
            });
          }
          if (!date) date = dateFromMarkdown(plain);
        }

        if (!date) date = new Date().toISOString().slice(0, 10);
        return json({ date, rows, parser: "llamaparse" });
      }
    } catch {
      continue;
    }
  }

  if (status !== "COMPLETED") {
    return json(
      {
        error: "Parsing timed out",
        detail: jobError || `Job status: ${status || "unknown"}. Please try again.`,
      },
      504,
    );
  }

  return json({ error: "Parsing failed", detail: jobError }, 502);
});
