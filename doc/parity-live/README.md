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
| Reasoning effort | Low / Medium / High / **Max**, with `13,920 / 24,000` spent against the budget | Low / Med / High / Max, spent from `ThreadState.thinkingTokens` | **Aligned** — `Max` was added to the default set, the playground's levels and the landing's pill |
| Streaming text | Tokens land in blue and settle into ink as the run advances | The thread's text does the same: `AssistantStreamingMarkdown` tints what arrived since the last frame and settles it after 600ms | **Aligned** — the element already existed; the thread now uses its treatment |
| Element count | The catalogue says **144 interface pieces** | `doc/official_elements.txt` holds **140 files**, **125 unique** after the 25 `.aui` variants are folded in | **Checked, not a gap** — the inventory matches upstream file for file (see below); the catalogue counts its sections its own way |
| Loader | Described as a pixel matrix that keeps time | `AssistantLoadingState` draws a 3×2 grid that pulses | Same idea, different pattern — check the matrix shape |

Everything else the first screen shows lines up: the typing indicator's three
dots in a pill, the guardrail notice's policy chip with "try instead"
alternatives, the thinking indicator's elapsed time, the message branches and
actions, the terminal block, the code diff, the reviewable diff, the file tree,
the error state, the feedback dialog, the regenerate menu, the attachment rows.

## The count, checked

The catalogue's "144 interface pieces" is not the inventory's unit. The upstream
elements directory holds 140 files; 25 of them are `.aui` variants of an element
that also ships in its base form, which is why `doc/element-coverage.md` walks
125:

```bash
curl -s "https://api.github.com/repos/assistant-ui/assistant-ui/contents/\
packages/ui/src/components/react/assistant-ui/elements" \
  | jq -r '.[] | select(.type=="file") | .name' | grep -vE '\.(test|radix)\b' \
  | sed 's/\.tsx$//' | sort > /tmp/live_ids.txt
diff <(sort doc/official_elements.txt) <(sort /tmp/live_ids.txt)   # no output
```

Running that diff now prints nothing: the inventory is current. The catalogue's
number spans its fourteen sections, including the three primitives it lists
separately, so it is a different count, not a missing one.

## Method

Headless Chrome writes one full-page PNG per URL, so a reference is one command
and no browser session. Scroll-state-dependent sections need a taller window
rather than a scroll script.
