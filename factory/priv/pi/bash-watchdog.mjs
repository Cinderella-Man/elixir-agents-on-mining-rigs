#!/opt/pi/node
// Pi's shellPath. Pi's bash tool has no default timeout, so a command that never
// exits (an Erlang VM without halt() piped into head) would stall the attempt.
// Pi starts this process as a process-group leader and kills that group on abort;
// the shell stays in the group, so the hang limit kills the same tree.
import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import { constants } from 'node:os';
import { join } from 'node:path';

const {EAB_BASH_TIMEOUT_SECONDS: limit, ...env} = process.env;
// Pi's own resolution when no shellPath is set.
const shell = ['/bin/bash', ...(env.PATH || '').split(':').filter(Boolean).map((dir) => join(dir, 'bash'))]
  .find((path) => existsSync(path)) || 'sh';
const child = spawn(shell, process.argv.slice(2), {stdio: 'inherit', env});
child.on('error', (error) => { process.stderr.write(`${error.message}\n`); process.exit(127); });
child.on('exit', (code, signal) => process.exit(code ?? 128 + (constants.signals[signal] ?? 0)));
setTimeout(() => {
  process.stderr.write(`\nCommand timed out after ${limit} seconds\n`);
  try { process.kill(-process.pid, 'SIGKILL'); } catch { child.kill('SIGKILL'); process.exit(137); }
}, Number(limit) * 1000);
