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
| Draft restore | `Add a regression test for draft…`, `unsent draft · 2 minutes ago`, **Restore** and a dismiss | `AssistantDraftRestore` — the text, the age in the same units, Restore and dismiss; the host supplies the draft and its timestamp | **Aligned** |
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

## Fifth read: knowledge and structured output

| Card in the catalogue | Port | Status |
|---|---|---|
| Research report | `research-report` — per-section state and source counts | Aligned |
| Map | `map-answer` — pins, a route, the list they came from | Aligned |
| Data table | `data-table` — model / context / cost with provider initials | Aligned |
| Number ticker | `number-ticker` — rolling digits, grouped figures | Aligned |
| Chart | `chart` — area over one x-scale, the delta in the corner | Aligned |
| Web preview | `web-preview` — the URL bar and the chrome; the element says it draws the chrome only and the host supplies the frame | Aligned, including the caveat upstream states in the card |
| Flow graph | `flow-graph` — labelled nodes over bezier edges | Aligned |
| Diagram | `diagram` — zoom, reset and expand over a host figure | Aligned |

## Sixth read: observability

| Card in the catalogue | Port | Status |
|---|---|---|
| Trace waterfall | `trace-waterfall` — span bars by status, durations to the right, a running pulse | Aligned |
| Cost meter | `cost-meter` — this run over the session, per-model token split and cost | Aligned |
| Quota banner | `quota-banner` — what is left, the reset time, `47 of 50 used`, upgrade | Aligned |

## Seventh read: the composer

| Card in the catalogue | Port | Status |
|---|---|---|
| Composer | `composer.dart` — attach, the model chip, dictation, send, and the context ring from `context-display` | Aligned |
| Slash commands | `command-palette` — the menu above the input, filtered as you type, arrow wrap, enter | Aligned |
| Mentions | No upstream element file backs this card; it is a behaviour of the unified composer, which the port mirrors | Aligned by construction |
| Attachments | `attachments` and the composer's chips — per-file progress before the message sends | Aligned |

## Eighth read: voice

| Card in the catalogue | Port | Status |
|---|---|---|
| Voice conversation | Orb, caption (`Listening · Listening for you`), `you` / `ai` transcript rows, mic, the red end button | `AssistantVoiceConversation` takes the mode, the amplitude, the transcript and the three controls | Aligned |
| Read aloud | The answer with the spoken words lit, pause, progress, `0:00 / 0:05`, speed, volume | `AssistantReadAloud` reads the same values | Aligned |

## Ninth read: the thread

| Card in the catalogue | Port | Status |
|---|---|---|
| Chat panel | The whole family working together | Aligned (the port's chat panel draws the same) |
| Empty state | `What are we building?`, three prompt pills, the composer centred | `AssistantEmptyState` takes the greeting, the suggestions and the composer | Aligned |
| Scroll anchor | Pinning pauses while tokens arrive; a jump pill appears once content lands out of view | `AssistantThread(showScrollToLatest:)` over the scroll-to-bottom primitive | Aligned |
| Canvas | The document takes the room with `v3 saved`, copy and close | `AssistantCanvasSplit` takes the title, version, saved flag, lines and both actions | Aligned |
| Connection state | `Picked the stream back up · +184 tokens` after a drop | `AssistantConnectionState` | Aligned |
| Shared conversation | Shared by and when, the read-only turn, `Continue in your own chat` | `AssistantSharedConversation` | Aligned |
| Search in conversation | `1 / 3` with step arrows and hits marked down the scrollbar | `AssistantConversationSearch` takes the hits with their positions | Aligned |
| Thread search | Pinned first, then grouped by day | `AssistantThreadSearch` | Aligned |
| Launcher | The floating entry point and the panel it opens into | `AssistantLauncherBubble` | Aligned |
| Settings | Model, system prompt, temperature, and the tool / memory switches | `AssistantSettingsPanel` | Aligned |
| Onboarding | `1 of 3` with Skip and Next | `AssistantOnboarding` | Aligned |
| Mobile composer | Quick actions above, thumb-sized targets, the mic | `AssistantMobileComposer` | Aligned |

## Tenth read: the connected block's first cards

| Card in the catalogue | Port | Status |
|---|---|---|
| Thread (AUI) | Messages, composer, auto-scroll and accessibility in one container | `AssistantThread` | Aligned |
| Assistant modal (AUI) | The floating bubble, a thread list, a resizable window | `AssistantModal` | Aligned |
| Assistant sidebar (AUI) | `New Thread`, `Search threads`, the active row, the product header and its source link | `AssistantThreadListSidebar` | Aligned |
| Thread list (AUI) | The sidebar beside the thread: search, active selection, thread actions | `AssistantThreadList` with `AssistantShell` | Aligned |
| Orb (AUI) | The voice orb with connection, mute and speaking states | `AssistantVoiceConversation` | Aligned |
| Reasoning (AUI) | A collapsible renderer that follows the active part | `AssistantReasoning`, hidden on request by `showReasoning` | Aligned |
| Message timing (AUI) | First token, total, speed, chunks | `AssistantMessageTiming` reads the same four fields | Aligned |
| Conversation map (AUI) | One tick per turn, the read turn marked, on-screen ones deepened, hover preview, click to jump | `AssistantConversationMap` | Aligned |
| Context display | Three presentations: Ring, Bar, Text | `AssistantContextRing`, `AssistantContextBar`, and — added in this pass — `AssistantContextText` for the third | **Text added** |

The connected block is the composed elements — the ones the port's styled layer
builds on its primitives — so the comparison is between two assemblies of the same
parts. Its remaining cards, and the renderer, primitive and generative sections,
are still unread.

## Eleventh to fourteenth read: the connected tail, renderers' first card

| Card in the catalogue | Port | Status |
|---|---|---|
| Context display | Ring, bar, text, with a detailed hover view | `AssistantContextRing` / `AssistantContextBar` / `AssistantContextText` | Aligned (the text form added in this pass) |
| MCP config dialog | Connectors and custom servers, authentication, connection state | `AssistantMcpConfig` | Aligned |
| Attachment | Previews, progress and removal for composer and message attachments | `attachments`, `AssistantAttachmentCard` | Aligned |
| Follow-up suggestions | Chips populated from the runtime's generated suggestions | `AssistantFollowUpSuggestions` | Aligned |
| Sources | Favicon links for URLs, file badges for documents | `sources` | Aligned |
| Image | Preview, loading state, actions, fullscreen | `ImagePart`, `AuiMessagePartImage`, `AssistantImageGeneration` | Aligned |
| File | Type-aware icons, filename, size, download | `FilePart` chip — the download action stays the host's, as upstream documents | Aligned |
| Model selector | Outline / Ghost / Muted, with the effort beside the model | `AssistantModelSelector` with the same three `ModelSelectorVariant`s | Aligned |
| Composer trigger popover | Mentions, slash commands, the nested BACK level | `AssistantMentionPopover`, `AssistantSlashCommandMenu` | Aligned |
| Directive text | Mention directives rendered into inline runtime-aware chips | `AssistantDirectiveText` | Aligned |
| Markdown text | Headings, lists, links, tables and code blocks | `AssistantMarkdown` | Aligned |

## The tail, read with a scrolling capture

A tall window stopped around `Markdown text` because the catalogue lays its later
sections out lazily. `tool/capture_live_catalogue.mjs` scrolls the page over CDP
and shoots frames (`doc/parity-live/deep/*.png`), which reaches the end:

| Section | What the cards are | Port | Status |
|---|---|---|---|
| Renderers | Markdown, syntax highlighting, Mermaid, math, code blocks | `AssistantMarkdown`, `AssistantSyntaxHighlighter`, `AssistantMermaidDiagram`, `AssistantMath`, `AssistantCodeBlock` | Aligned |
| Primitives | The pieces the styled layer builds on | The port's `primitives/` layer | Aligned |
| Generative | A heat graph, then eighteen **Card** and **Form** model samples (a stay card, a booking form, an order tracker, a flight tracker, a portfolio, an event card, a channel message, a receipt, a two-series chart, a player card, a session card, a confirm dialog, a line chart, a task form, a plan form …) | `generative-ui`'s registry with its Card/Form models renders them; the samples themselves are not separate elements upstream | Aligned by construction |
| Heat graph | Month labels, day labels, legend, per-cell tooltips | `heat-graph` | Aligned |

With that, all fourteen sections of the catalogue have been read against the port.

## Method

Headless Chrome writes one full-page PNG per URL, so a reference is one command
and no browser session. Scroll-state-dependent sections need a taller window
rather than a scroll script.
