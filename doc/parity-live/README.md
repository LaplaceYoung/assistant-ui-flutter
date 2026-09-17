# The live catalogue, captured

`elements-live.png` is `https://www.assistant-ui.com/elements`, captured on
2026-09-18 with headless Chrome:

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --hide-scrollbars \
  --window-size=1440,5200 --virtual-time-budget=12000 \
  --screenshot=doc/parity-live/elements-live.png \
  "https://www.assistant-ui.com/elements"
```

It is the reference the port's own pages (`doc/gallery/*.png`) are read against.
The two are not pixel-diffed: the live page is a catalogue of small cards, the
port's pages are demos, so the comparison is by element and by eye.

## What the reference shows that the port does not, yet

| Where | Live | Port | Status |
|---|---|---|---|
| Reasoning effort | Low / Medium / **High / Max**, with `13,920 / 24,000` spent against the budget | Low / Med / High, spent from `ThreadState.thinkingTokens` | **`Max` is missing** — add it to the default effort set |
| Streaming text | Tokens land in blue and settle into ink as the run advances | Text streams in one colour; only the cursor marks progress | **Not ported** — needs a per-token age in the markdown renderer |
| Element count | The catalogue says **144 interface pieces** | `doc/element-coverage.md` walks **125** | **The inventory is behind** — refresh it from the live list before claiming coverage |
| Loader | Described as a pixel matrix that keeps time | `AssistantLoadingState` draws a 3×2 grid that pulses | Same idea, different pattern — check the matrix shape |

Everything else the first screen shows lines up: the typing indicator's three
dots in a pill, the guardrail notice's policy chip with "try instead"
alternatives, the thinking indicator's elapsed time, the message branches and
actions, the terminal block, the code diff, the reviewable diff, the file tree,
the error state, the feedback dialog, the regenerate menu, the attachment rows.

## Method

Headless Chrome writes one full-page PNG per URL, so a reference is one command
and no browser session. Scroll-state-dependent sections need a taller window
rather than a scroll script.
