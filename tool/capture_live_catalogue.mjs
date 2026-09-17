// Captures the live catalogue's later sections, which only lay out once scrolled
// into view.
//
//   bun tool/capture_live_catalogue.mjs --out doc/parity-live/deep --frames 8
//
// Same CDP approach as the parity check, minus the replica: one Chrome, one
// page, scroll and shoot.

const args = new Map();
for (let i = 2; i < process.argv.length; i += 2) {
  args.set(process.argv[i].replace(/^--/, ""), process.argv[i + 1]);
}

const url = args.get("url") ?? "https://www.assistant-ui.com/elements";
const out = args.get("out") ?? "doc/parity-live/deep";
const cdpPort = Number(args.get("cdp") ?? 9401);
const width = Number(args.get("width") ?? 1440);
const height = Number(args.get("height") ?? 1400);
const step = Number(args.get("step") ?? 1200);
const frames = Number(args.get("frames") ?? 8);
const settleMs = Number(args.get("settle") ?? 1200);
const bootMs = Number(args.get("boot") ?? 9000);

/** A minimal CDP client: one socket, promise per call. */
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
      message.error
        ? entry.reject(new Error(JSON.stringify(message.error)))
        : entry.resolve(message.result);
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

async function main() {
  const cdp = await Cdp.attach(cdpPort);
  const { targetId } = await cdp.send("Target.createTarget", { url: "about:blank" });
  const { sessionId } = await cdp.send("Target.attachToTarget", { targetId, flatten: true });
  await cdp.send(
    "Emulation.setDeviceMetricsOverride",
    { width, height, deviceScaleFactor: 1, mobile: false },
    sessionId,
  );
  await cdp.send("Page.enable", {}, sessionId);
  await cdp.send("Network.setCacheDisabled", { cacheDisabled: true }, sessionId);
  await cdp.send("Page.navigate", { url }, sessionId);
  await sleep(bootMs);

  const total = await cdp.send(
    "Runtime.evaluate",
    { expression: "document.documentElement.scrollHeight", returnByValue: true },
    sessionId,
  );
  console.log("page height:", total.result?.value);

  for (let i = 0; i < frames; i++) {
    const y = 24000 + i * step;
    await cdp.send(
      "Runtime.evaluate",
      { expression: `window.scrollTo(0, ${y}); 'ok'`, returnByValue: true },
      sessionId,
    );
    await sleep(settleMs);
    const { data } = await cdp.send("Page.captureScreenshot", { format: "png" }, sessionId);
    await Bun.write(`${out}/${String(i).padStart(2, "0")}.png`, Buffer.from(data, "base64"));
    const after = await cdp.send(
      "Runtime.evaluate",
      { expression: "document.documentElement.scrollHeight", returnByValue: true },
      sessionId,
    );
    console.log(`frame ${i} at y=${y}, height now ${after.result?.value}`);
  }

  cdp.close();
}

await main();
