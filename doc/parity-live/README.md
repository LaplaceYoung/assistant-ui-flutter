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
| Loader | A 3×3 matrix of round cells with a wave walking through it, captioned `Generating` | Was a 3×2 grid of rounded squares with no caption | **Aligned** — the matrix is 3×3 round cells with the caption; cell colour, size and the wave were already the same |

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

## Second read: the messages and composer cards

| Where | Live | Port | Status |
|---|---|---|---|
| Stopped run | `stopped by you`, then **Continue** and **Discard** | Continue only, with no note | **Discard added** — the note, the pill and the discard action, so a half-written answer can be dropped |
| Draft restore | The behaviour and a card that shows the restored draft as an underline diff | The behaviour is ported into the runtime (drafts survive a thread switch); the diff-underlined card is not | **Open** — the card is a view over a draft the runtime already keeps |
| Feedback dialog | Reason chips, a note, `Send feedback` | Same | Aligned |
| Timestamps | Day rules with times on hover | Same (`AssistantDaySeparator`) | Aligned |
| Speaker identity | Avatars with the name, the model and per-turn durations | Same shape | Aligned |
| Regenerate menu | Rows with `slower / current / fastest` hints | Same, with the detail line | Aligned |

## Third read: tool use and the agent sections

The reference is now the whole catalogue (`elements-live-full.png`, 1440×13000);
the first capture stopped around card 21.

| Where | Live | Port | Status |
|---|---|---|---|
| Tool call | One invocation with its request and result behind a disclosure | `AssistantToolCallCard` | Aligned |
| Tool timeline | `4 steps · 2 files changed`, verb rows with their target, then file chips with `+14 −3` | `AssistantToolTimeline` takes the same steps, stats and labels | Aligned |
| Terminal block | Command, streamed lines, `exit 0`, the summary line | Same | Aligned |
| Reviewable diff | `0 of 2 kept`, hunk, Discard / Keep | Same | Aligned |
| File tree | `4 files changed +78 −9` over per-file counts | Same | Aligned |
| Score breakdown | `4.1 / 5` with `approve`, weighted criteria and the note that pulled one down | `AssistantScoreBreakdown` has the verdict band and the weighted rows | Aligned |
| Plan | `5 of 5` with a checklist and per-step states | `AssistantAgentPlan` | Aligned |
| Agent status | Name, model tag, progress bar, done rows with their model | `AssistantAgentStatus` | Aligned |

## Fourth read: the agent tail

| Card in the catalogue | Port | Status |
|---|---|---|
| Handoff | `agent-handoff` — from → to pills, the reason, what came along | Aligned |
| Background runs | `background-inbox` — ready versus in-flight | Aligned |
| Checkpoints | `checkpoint-history` — the current mark and what each point gives back | Aligned |
| Schedule | `schedule-card` — cadence, next run, recent runs with their outcomes | Aligned |

The catalogue names a few elements by what they show rather than by the port's
file names (`Background runs` is `background-inbox`, `Checkpoints` is
`checkpoint-history`, `Schedule` is `schedule-card`); comparing by name alone
reads as three missing elements when they are three ported ones.

## Method

Headless Chrome writes one full-page PNG per URL, so a reference is one command
and no browser session. Scroll-state-dependent sections need a taller window
rather than a scroll script.
