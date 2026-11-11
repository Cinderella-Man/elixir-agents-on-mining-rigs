import { run } from 'node:test';
import { relative, resolve } from 'node:path';

// Run outside the editable project. Test stdout is never interpreted as trusted
// protocol, and missing completion/duplicate identities fail the controller parser.
const encode = value => Buffer.from(value).toString('base64');
const files = process.argv.slice(2).map(file => resolve(file));
let count = 0;
let failed = false;
let summary = false;
for await (const event of run({ files, concurrency: 1 })) {
  const { type, data } = event;
  if (type === 'test:stdout' || type === 'test:stderr') {
    for (const line of data.message.split('\n')) process.stdout.write(`TEST_OUTPUT ${line}\n`);
  }
  if (type === 'test:summary' && data.file === undefined) summary = true;
  if (type !== 'test:pass' && type !== 'test:fail') continue;
  if (type === 'test:fail') failed = true;
  if (data.details?.type === 'suite') continue;
  // A file exiting without registering tests is not a passing test body.
  if (!data.file || files.includes(resolve(data.name))) continue;
  const id = encode(`${relative(process.cwd(), data.file)}::${data.name}`);
  const state = data.skip || data.todo ? 'skipped' : type === 'test:pass' ? 'passed' : 'failed';
  process.stdout.write(`EAB_TEST:${state}:${id}\n`);
  count += 1;
  if (state === 'failed') {
    const error = data.details?.error;
    const phase = error?.failureType === 'testCodeFailure' ? 'test' : 'setup';
    process.stdout.write(`EAB_FAILURE_PHASE:${id}:${phase}\n`);
    process.stdout.write(`EAB_FAILURE_TYPES:${id}:${encode(error?.code || 'unknown')}\n`);
    for (const line of String(error?.cause?.stack || error?.stack || error).split('\n')) {
      process.stdout.write(`TEST_ERROR ${line}\n`);
    }
  }
}
if (summary) process.stdout.write(`EAB_SUITE_FINISHED:${count}\n`);
process.exitCode = failed || !summary ? 1 : 0;
