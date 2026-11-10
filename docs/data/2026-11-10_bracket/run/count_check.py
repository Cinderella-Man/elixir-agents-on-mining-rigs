import json, sys, urllib.request
base = sys.argv[1]
payload = {
    "messages": [
        {"role": "system", "content": "You are a coding agent. Use the tools."},
        {"role": "user", "content": "List the files in the current folder with the bash tool."},
    ],
    "tools": [{"type": "function", "function": {"name": "bash", "description": "Run a shell command",
               "parameters": {"type": "object", "properties": {"command": {"type": "string"}}, "required": ["command"]}}}],
    "max_tokens": 256, "seed": 101, "stream": True, "stream_options": {"include_usage": True},
}
def post(route, body):
    req = urllib.request.Request(base + route, json.dumps(body).encode(), {"Content-Type": "application/json"})
    return urllib.request.urlopen(req, timeout=300).read().decode()
count = json.loads(post("/v1/chat/completions/input_tokens", payload))["input_tokens"]
usage, finish, calls = {}, None, 0
for line in post("/v1/chat/completions", payload).splitlines():
    if line.startswith("data: {"):
        e = json.loads(line[6:])
        usage = e.get("usage") or usage
        for c in e.get("choices") or []:
            finish = c.get("finish_reason") or finish
            calls += len((c.get("delta") or {}).get("tool_calls") or [])
print(f"counted {count}, generation reported prompt_tokens {usage.get('prompt_tokens')}: "
      f"{'equal' if count == usage.get('prompt_tokens') else 'DIFFERENT'}; completion_tokens {usage.get('completion_tokens')}, "
      f"finish {finish}, tool-call chunks {calls}")
