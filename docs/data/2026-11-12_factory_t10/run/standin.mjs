// standin.mjs: a stand-in model server that plays back a fixed conversation in the llama.cpp server's format, as the
// engine's own tests do (factory/test/eab/pi_docker_test.exs). No model runs; the replies are written below.
//   GET  /health, /v1/models, /props            what Eab.Model.discover/2 reads
//   POST /v1/chat/completions/input_tokens      the prompt's size: its JSON bytes / 4, rounded up
//   POST /v1/chat/completions                   the next step of SCRIPT as one streamed answer, with its usage
// The step is the number of assistant messages already in the request. Every chat request is saved whole as
// OUT/request-NNNN.json, so the first one is the proof of what a model is shown.
// Environment: PORT (18110), BIND (127.0.0.1), SCRIPT (good or wrong), OUT (/out).
import http from "node:http";
import fs from "node:fs";
import path from "node:path";

const PORT = Number(process.env.PORT || 18110);
const BIND = process.env.BIND || "127.0.0.1";
const SCRIPT = process.env.SCRIPT || "good";
const OUT = process.env.OUT || "/out";
const MODEL = "stand-in-replay";
fs.mkdirSync(OUT, { recursive: true });

const props = {
  model_alias: MODEL,
  model_path: "stand-in-replay-F16.gguf",
  build_info: "stand-in replay server (task factory job T10)",
  default_generation_settings: { n_ctx: 262144 },
  total_slots: 1,
};

const ledger = "lib/ledgerette.ex";
const format = "lib/ledgerette/format.ex";
const debitOld = "      {:debit, amount}, total -> total + amount";
const debitNew = "      {:debit, amount}, total -> total - amount";
const formatOld = "defmodule Ledgerette.Format do\n";
const formatNew =
  'defmodule Ledgerette.Format do\n  def amount(cents) when cents < 0, do: "-" <> amount(-cents)\n\n';

const goodTest = `defmodule Ledgerette.DebitTest do
  use ExUnit.Case

  test "a debit lowers the balance" do
    assert Ledgerette.balance([{:credit, 10}, {:debit, 4}]) == 6
  end

  test "a negative amount prints one minus sign" do
    assert Ledgerette.Format.amount(-150) == "-1.50"
  end
end
`;

const wrongTest = `defmodule Ledgerette.FormatSignTest do
  use ExUnit.Case

  test "a negative amount prints one minus sign" do
    assert Ledgerette.Format.amount(-150) == "-1.50"
  end
end
`;

// Each step is a tool call [name, arguments(tools)] or the final text.
const scripts = {
  good: [
    ["read", () => ({ path: ledger })],
    ["edit", (tools) => editArgs(tools, ledger, debitOld, debitNew)],
    ["read", () => ({ path: format })],
    ["edit", (tools) => editArgs(tools, format, formatOld, formatNew)],
    ["write", () => ({ path: "test/debit_test.exs", content: goodTest })],
    ["bash", () => ({ command: "mix test test/debit_test.exs test/ledgerette_test.exs" })],
    "Debits now subtract from the balance, and negative amounts print with one leading minus sign. " +
      "test/debit_test.exs covers both and passes with the existing tests.",
  ],
  wrong: [
    ["read", () => ({ path: format })],
    ["edit", (tools) => editArgs(tools, format, formatOld, formatNew)],
    ["write", () => ({ path: "test/format_sign_test.exs", content: wrongTest })],
    "Negative amounts now print with one leading minus sign; test/format_sign_test.exs covers it.",
  ],
};

// Pi's edit tool, by the parameters it declares: one old and new text, or a list of them.
function editArgs(tools, file, oldText, newText) {
  const tool = (tools || []).map((t) => t.function || t).find((t) => t.name === "edit");
  const params = tool?.parameters?.properties || tool?.input_schema?.properties || {};
  const names = (p) => [
    Object.keys(p).find((k) => /old/i.test(k)) || "oldText",
    Object.keys(p).find((k) => /new/i.test(k)) || "newText",
  ];
  const pathKey = Object.keys(params).find((k) => /path/i.test(k)) || "path";
  if (params.edits) {
    const [o, n] = names(params.edits.items?.properties || {});
    return { [pathKey]: file, edits: [{ [o]: oldText, [n]: newText }] };
  }
  const [o, n] = names(params);
  return { [pathKey]: file, [o]: oldText, [n]: newText };
}

const count = (body) => Math.max(1, Math.ceil(Buffer.byteLength(JSON.stringify(body)) / 4));
let saved = 0;

function answer(body) {
  const script = scripts[SCRIPT];
  const step = (body.messages || []).filter((m) => m.role === "assistant").length;
  const item = script[Math.min(step, script.length - 1)];
  const id = `chatcmpl-standin-${step}`;
  let delta, finish, text;
  if (typeof item === "string") {
    delta = { role: "assistant", content: item };
    finish = "stop";
    text = item;
  } else {
    const args = JSON.stringify(item[1](body.tools));
    delta = {
      role: "assistant",
      tool_calls: [
        { index: 0, id: `call_${step}`, type: "function", function: { name: item[0], arguments: args } },
      ],
    };
    finish = "tool_calls";
    text = item[0] + args;
  }
  const output = Math.min(Math.ceil(text.length / 4) + 1, body.max_tokens || 8192);
  const base = { id, object: "chat.completion.chunk", created: 1762905600, model: MODEL };
  const events = [
    { ...base, choices: [{ index: 0, delta, finish_reason: null }] },
    {
      ...base,
      choices: [{ index: 0, delta: {}, finish_reason: finish }],
      usage: { prompt_tokens: count(body), completion_tokens: output, total_tokens: count(body) + output },
    },
  ];
  return events.map((e) => `data: ${JSON.stringify(e)}\n\n`).join("") + "data: [DONE]\n\n";
}

function send(res, status, type, body) {
  res.writeHead(status, { "content-type": type });
  res.end(typeof body === "string" ? body : JSON.stringify(body));
}

http
  .createServer((req, res) => {
    let raw = "";
    req.on("data", (c) => (raw += c));
    req.on("end", () => {
      const url = req.url.split("?")[0];
      console.log(new Date().toISOString(), req.method, url, raw.length);
      try {
        if (req.method === "GET" && url === "/health") return send(res, 200, "application/json", { status: "ok" });
        if (req.method === "GET" && url === "/v1/models")
          return send(res, 200, "application/json", {
            object: "list",
            data: [{ id: MODEL, object: "model", owned_by: "stand-in" }],
          });
        if (req.method === "GET" && url === "/props") return send(res, 200, "application/json", props);
        if (req.method === "POST" && url === "/v1/chat/completions/input_tokens")
          return send(res, 200, "application/json", { input_tokens: count(JSON.parse(raw)) });
        if (req.method === "POST" && url === "/v1/chat/completions") {
          const body = JSON.parse(raw);
          const file = path.join(OUT, `request-${String(saved++).padStart(4, "0")}.json`);
          fs.writeFileSync(file, JSON.stringify(body, null, 2) + "\n");
          return send(res, 200, "text/event-stream", answer(body));
        }
        send(res, 404, "application/json", { error: { message: "not found" } });
      } catch (error) {
        console.log("error", error);
        send(res, 500, "application/json", { error: { message: String(error) } });
      }
    });
  })
  .listen(PORT, BIND, () => console.log(`stand-in ${SCRIPT} on ${BIND}:${PORT}`));
