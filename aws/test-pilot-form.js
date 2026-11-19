// Local test of the form receiver (the inline Lambda code in aws/regatta-website.yaml).
// Runs the code straight from the template, with a fake SNS client: nothing is sent, no AWS needed.
//   node aws/test-pilot-form.js
"use strict";
const fs = require("fs");
const path = require("path");
const vm = require("vm");
const assert = require("assert");

// 1. Pull the ZipFile block of PilotFunction out of the template.
const yaml = fs.readFileSync(path.join(__dirname, "regatta-website.yaml"), "utf8").split("\n");
const start = yaml.findIndex((l, i) => /^\s*ZipFile: \|\s*$/.test(l) && yaml.slice(Math.max(0, i - 20), i).some((x) => /PilotFunction:/.test(x)));
assert(start > 0, "ZipFile block of PilotFunction not found");
const indent = yaml[start + 1].match(/^ */)[0].length;
const code = [];
for (let i = start + 1; i < yaml.length; i++) {
  const l = yaml[i];
  if (l.trim() !== "" && l.match(/^ */)[0].length < indent) break;
  code.push(l.slice(indent));
}

// 2. Load it with a fake @aws-sdk/client-sns that records what would be published.
let published = [];
class PublishCommand { constructor(input) { this.input = input; } }
class SNSClient { async send(cmd) { published.push(cmd.input); return {}; } }
const mod = { exports: {} };
const sandbox = {
  module: mod, exports: mod.exports, Buffer, URLSearchParams,
  console: { log() {}, error() {} },
  process: { env: { SITE_URL: "https://regatta.tech", TOPIC_ARN: "arn:test" } },
  require: (name) => { if (name === "@aws-sdk/client-sns") return { SNSClient, PublishCommand }; throw new Error("unexpected require " + name); },
};
vm.runInNewContext(code.join("\n"), sandbox, { filename: "pilot-form.js" });
const handler = mod.exports.handler;

function post(fields) {
  return { requestContext: { http: { method: "POST" } }, isBase64Encoded: false, body: new URLSearchParams(fields).toString() };
}

// 3. Cases: [name, event, expected redirect, notification sent?, subject tagged?]
const good = { "bot-field": "", email: "ana@pharma-example.com", organization: "Acme Bio", elapsed: "15234" };
const cases = [
  ["good submit", post(good), "/thanks/", true, false],
  ["too fast (1200 ms): dropped", post({ ...good, elapsed: "1200" }), "/thanks/", false, null],
  ["just under 3 s (2999 ms): dropped", post({ ...good, elapsed: "2999" }), "/thanks/", false, null],
  ["exactly 3 s: kept", post({ ...good, elapsed: "3000" }), "/thanks/", true, false],
  ["no elapsed field (old cached page): kept, tagged", post({ "bot-field": "", email: good.email, organization: good.organization }), "/thanks/", true, true],
  ["empty elapsed (no JavaScript): kept, tagged", post({ ...good, elapsed: "" }), "/thanks/", true, true],
  ["unreadable elapsed: kept, tagged", post({ ...good, elapsed: "abc" }), "/thanks/", true, true],
  ["negative elapsed (clock change): kept, tagged", post({ ...good, elapsed: "-50" }), "/thanks/", true, true],
  ["honeypot filled: silent", post({ ...good, "bot-field": "x" }), "/thanks/", false, null],
  ["bad email", post({ ...good, email: "not-an-email" }), "/home/?error=email#meet", false, null],
  ["bad email and too fast: still the email error", post({ ...good, email: "nope", elapsed: "500" }), "/home/?error=email#meet", false, null],
  ["Gmail with many dots: kept, tagged", post({ ...good, email: "a.b.c.d@gmail.com" }), "/thanks/", true, true],
  ["random-letter organization: kept, tagged", post({ ...good, organization: "Xqzvjkpl" }), "/thanks/", true, true],
  ["body too large", post({ ...good, organization: "a".repeat(5000) }), "/home/?error=send#meet", false, null],
  ["GET", { requestContext: { http: { method: "GET" } } }, "/home/", false, null],
];

(async () => {
  let failed = 0;
  for (const [name, event, where, sent, tagged] of cases) {
    published = [];
    const res = await handler(event);
    const loc = res.headers.Location.replace("https://regatta.tech", "");
    let ok = res.statusCode === 303 && loc === where && (published.length === 1) === sent;
    if (ok && sent) {
      const s = published[0].Subject;
      ok = s.length < 100 && s.startsWith("[Possible spam] ") === tagged && published[0].Message.includes("Possible spam:") === tagged;
    }
    console.log((ok ? "PASS " : "FAIL ") + name + " -> " + res.statusCode + " " + loc + (sent ? " | " + (published[0] && published[0].Subject) : " | no email"));
    if (!ok) failed++;
  }
  console.log(failed ? failed + " FAILED" : "All " + cases.length + " cases passed");
  process.exit(failed ? 1 : 0);
})();
