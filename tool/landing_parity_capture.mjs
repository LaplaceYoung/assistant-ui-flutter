// Captures the live page and the replica frame by frame for the parity check.
//
//   bun tool/landing_parity_capture.mjs --port 8181 --cdp 9401 --out docs/landing/parity
//
// The live page scrolls with `window.scrollTo`; the replica is a Flutter canvas
// whose own scroll view owns the offset, so it scrolls by wheel events of the
// same delta. No dependencies: Bun's global WebSocket speaks CDP directly.

const args = new Map();
for (let i = 2; i < process.argv.length; i += 2) {
  args.set(process.argv[i].replace(/^--/, ""), process.argv[i + 1]);
}

const replicaUrl = args.get("replica") ?? "http://127.0.0.1:8181/";
const liveUrl = args.get("live") ?? "https://www.assistant-ui.com/";
const cdpPort = Number(args.get("cdp") ?? 9401);
const out = args.get("out") ?? "docs/landing/parity";
const width = Number(args.get("width") ?? 1280);
const height = Number(args.get("height") ?? 1000);
const step = Number(args.get("step") ?? 560);
const frames = Number(args.get("frames") ?? 8);
const settleMs = Number(args.get("settle") ?? 900);
const bootMs = Number(args.get("boot") ?? 11000);

/** A minimal CDP client: one socket, one page target, promise per call. */
class Cdp {
  constructor(ws) {
    this.ws = ws;
    this.id = 0;
    this.pending = new Map();
    ws.addEventListener("message", (event) => {
      const message = JSON.parse(event.data);
      const entry = this.pending.get(message.id);
      if (!entry) return;
      this.pending.delete(message.id);
      message.error ? entry.reject(new Error(JSON.stringify(message.error))) : entry.resolve(message.result);
    });
  }

  static async attach(port) {
    const res = await fetch(`http://127.0.0.1:${port}/json/version`);
    const { webSocketDebuggerUrl } = await res.json();
    const ws = new WebSocket(webSocketDebuggerUrl);
    await new Promise((resolve, reject) => {
      ws.addEventListener("open", resolve, { once: true });
      ws.addEventListener("error", reject, { once: true });
    });
    return new Cdp(ws);
  }

  send(method, params = {}, sessionId) {
    const id = ++this.id;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(JSON.stringify({ id, method, params, sessionId }));
    });
  }

  close() {
    this.ws.close();
  }
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function openPage(cdp, url) {
  const { targetId } = await cdp.send("Target.createTarget", { url: "about:blank" });
  const { sessionId } = await cdp.send("Target.attachToTarget", { targetId, flatten: true });
  await cdp.send("Emulation.setDeviceMetricsOverride", {
    width,
    height,
    deviceScaleFactor: 1,
    mobile: false,
  }, sessionId);
  await cdp.send("Page.enable", {}, sessionId);
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true }, sessionId);
  await cdp.send("Page.navigate", { url }, sessionId);
  await sleep(bootMs);
  return { targetId, sessionId };
}

async function evaluate(cdp, sessionId, expression) {
  const { result } = await cdp.send("Runtime.evaluate", {
    expression,
    returnByValue: true,
    awaitPromise: true,
  }, sessionId);
  return result?.value;
}

async function shot(cdp, sessionId, path) {
  const { data } = await cdp.send("Page.captureScreenshot", { format: "png" }, sessionId);
  await Bun.write(path, Buffer.from(data, "base64"));
}

async function wheel(cdp, sessionId, deltaY) {
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mouseMoved",
    x: Math.floor(width / 2),
    y: Math.floor(height / 2),
  }, sessionId);
  await cdp.send("Input.dispatchMouseEvent", {
    type: "mouseWheel",
    x: Math.floor(width / 2),
    y: Math.floor(height / 2),
    deltaX: 0,
    deltaY,
  }, sessionId);
}

const cdp = await Cdp.attach(cdpPort);
const results = [];

// --- the live page: document scrolling ---------------------------------------
const live = await openPage(cdp, liveUrl);
const liveHeight = await evaluate(cdp, live.sessionId, "document.documentElement.scrollHeight");
for (let i = 0; i < frames; i++) {
  await evaluate(cdp, live.sessionId, `window.scrollTo(0, ${i * step}); 'ok'`);
  await sleep(settleMs);
  await shot(cdp, live.sessionId, `${out}/src_${i}.png`);
  const y = await evaluate(cdp, live.sessionId, "Math.round(window.scrollY)");
  results.push(`src_${i}:y=${y}`);
}

// --- the replica: the app's own scroll view ----------------------------------
const rep = await openPage(cdp, replicaUrl);
for (let i = 0; i < frames; i++) {
  if (i > 0) await wheel(cdp, rep.sessionId, step);
  await sleep(settleMs);
  await shot(cdp, rep.sessionId, `${out}/rep_${i}.png`);
  results.push(`rep_${i}`);
}

console.log(JSON.stringify({ liveScrollHeight: liveHeight, frames: results }, null, 1));
cdp.close();
