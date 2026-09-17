# assistant-ui-flutter

[![Flutter](https://img.shields.io/badge/Flutter-3.47-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%5E3.9-0175C2?logo=dart)](https://dart.dev)
[![tests](https://img.shields.io/badge/tests-394-brightgreen)](test/)
[![elements](https://img.shields.io/badge/elements-119%2F125%20ported-blue)](docs/element-coverage.md)
[![packages](https://img.shields.io/badge/upstream%20packages-23%20ported-blue)](docs/package-coverage.md)
[![license](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

**A Flutter port of [assistant-ui](https://www.assistant-ui.com).** The whole
library — the component set, the runtime, the primitives and the model
adapters — rebuilt as Dart/Flutter widgets, plus a one-to-one Flutter replica of
the assistant-ui landing page.

| | |
|---|---|
| Landing replica (live) | https://laplaceyoung.github.io/assistant-ui-flutter/ |
| Repository | https://github.com/LaplaceYoung/assistant-ui-flutter |
| Element coverage | [119 of 125 upstream elements ported](docs/element-coverage.md) |
| Package coverage | [23 of 46 upstream packages ported, 1 partial, 22 n/a](docs/package-coverage.md) |
| Landing parity | [mean 3.6% of pixels differ from the live page](docs/landing/parity/REPORT.md) |

No React, no DOM, no web view: the same three layers, expressed as Flutter
widgets.

```yaml
# pubspec.yaml — the package is consumed straight from this repository
dependencies:
  assistant_ui:
    git:
      url: https://github.com/LaplaceYoung/assistant-ui-flutter.git
      path: .
```

```bash
flutter run -d chrome example          # the gallery of every element family
cd landing && flutter run -d chrome    # the landing replica
flutter test                           # 394 tests
```

```dart
final runtime = LocalRuntime(adapter: MyChatModelAdapter());

AuiRuntimeProvider(
  runtime: runtime,
  child: const AssistantThread(),
);
```

## Layers

| Layer | assistant-ui | this package |
|---|---|---|
| Styled components | `@/components/assistant-ui/*` | `AssistantThread`, `AssistantComposer`, `AssistantMessageParts`, `AssistantMarkdown`, `AssistantTheme` |
| Primitives | `ThreadPrimitive`, `MessagePrimitive`, `ComposerPrimitive`, `ActionBarPrimitive`, `BranchPickerPrimitive`, `AuiIf` | `AuiThread`, `AuiMessage`, `AuiComposerInput`, `AuiActionBar`, `AuiBranchPicker`, `AuiIf` |
| Runtime | `useLocalRuntime` | `LocalRuntime` + `ChatModelAdapter` |
| Protocol | `@assistant-ui/react-data-stream` | `DataStreamChatModelAdapter`, `DataStreamParser` |
| Tool servers | `@assistant-ui/react-mcp` | `McpClient` (initialize / tools / call / toolkit), `McpServers` |
| AG-UI agents | `@assistant-ui/react-ag-ui` | `AgUiChatModelAdapter`, `AgUiAgent`, `parseAgUiEvent` |
| A2A agents | `@assistant-ui/react-a2a` | `A2AClient`, `A2AChatModelAdapter`, the wire types and conversions |
| LangGraph graphs | `@assistant-ui/react-langgraph` | `LangGraphClient`, `LangGraphChatModelAdapter`, `LangGraphMessageAccumulator` |
| Google ADK agents | `@assistant-ui/react-google-adk` | `AdkClient`, `AdkChatModelAdapter`, `AdkEventAccumulator` |
| Generative UI | `@assistant-ui/react-generative-ui` | `GenerativeUiNode`, `GenerativeUiRegistry`, `GenerativeUi`, `generativeUiToJsx` |
| Tracing UI | `@assistant-ui/react-o11y` | `SpanTree`, `SpanData`, the span primitive family |
| Hosted threads | `@assistant-ui/cloud` | `CloudClient` (threads CRUD + messages), `CloudThread` |

## What is implemented

- **Messages and parts** — `ThreadMessage`, branches, per-part status, and the
  full part set: text, reasoning, tool-call, image, file, source, data. Wire
  JSON matches assistant-ui, so the same backend payloads decode unchanged.
- **Runtime** — streaming with cumulative chunks, cancellation, regeneration as
  a new branch, message editing with truncate-and-rerun, branch switching, tool
  execution with `maxSteps`, and human-in-the-loop tools that pause the run
  with `requires-action`.
- **Markdown** — headings, lists, tables, block quotes, inline formatting and
  links, with fenced code tokenized through the same coldark palettes the
  syntax-highlighter element ships.
- **Protocol** — Vercel AI data stream v1 (`0:"text"`, `9:{tool-call}`,
  `a:{result}`, `d:{finish}`, …), CRLF-aware framing, SSE-wrapped frames,
  `aui-*` extension frames, and tolerant dropping of malformed frames.
- **AG-UI** — the event vocabulary as a sealed type (`parseAgUiEvent` is the only
  place raw maps are read, tolerant of malformed and unknown events), and an
  agent that POSTs a `RunAgentInput` and reads the SSE stream back. The adapter
  accumulates text, reasoning and tool calls into cumulative parts, parks the
  run on `requires-action` when `RUN_FINISHED` carries interrupts (with their
  ids, reasons and response schemas), and collects state / activity / custom
  events into `lastState`.
- **A2A** — the wire types (parts, messages, tasks, artifacts, stream events) with
  the card/send/stream/get/cancel endpoints, `A2A-Version: 1.0` headers, SSE
  streams whose non-`text/event-stream` replies are refused with the received
  type, and the upstream conversions both ways (part shapes, task state →
  message status). The adapter accumulates streamed status messages and
  artifacts into parts, parks the run on `input_required` / `auth_required`,
  and throws the agent's own message when a task fails.
- **LangGraph** — thread creation and `POST /threads/{id}/runs/stream` with the
  `messages` / `updates` / `custom` stream modes, read as `event:` / `data:`
  frames. The accumulator upserts by message id, honours `remove` (including
  the `__remove_all__` sentinel) and merges chunks the way
  `appendLangChainChunk` does: text and thinking concatenate by index, tool-call
  arguments concatenate into `partial_json` (parsed as it becomes valid, empty
  until then), and a complete message keeps the streamed argument text. An
  `__interrupt__` in an update parks the run on `requires-action`.
- **Google ADK** — session creation and the `/run_sse` endpoint with the
  `appName` / `userId` / `sessionId` / `newMessage` / `streaming` body, frames
  normalized across snake_case and camelCase. The accumulator replaces the text
  a partial event carries, closes it out on the final event, pairs function
  calls with their responses (an `error` payload marks the call failed),
  accumulates `stateDelta` / `artifactDelta`, tracks agent transfer and
  escalation, opens a gate for every `adk_request_confirmation` call (naming the
  gated tool and its own id), and parks the run when a long-running tool id, a
  confirmation, an auth request or an interrupt arrives. `adkConfirmationReply`
  builds the message that resumes the run, and `projectAdkToolConfirmations`
  reads which gates a transcript has open or answered.
- **Web preview** — the chrome (origin bar, reload, open-in-new, loading state)
  plus a platform frame: on web an iframe is registered as a platform view with
  its sandbox attribute, elsewhere the surface returns null and the host passes
  its own frame — the same responsibility split upstream documents.
- **Math** — a typesetter in Dart: `$…$` and `$$…$$` become widgets without a
  host renderer (fractions with a rule, radicals with an overline, superscripts
  and subscripts hung off the base axis, the Greek/operator symbol table, and
  verbatim `\text{}`). A host renderer still overrides it.
- **Web preview** — the chrome (origin bar, reload, open-in-new, loading state)
  plus a platform frame: on web an iframe is registered as a platform view with
  its sandbox attribute, elsewhere the surface returns null and the host passes
  its own frame — the same responsibility split upstream documents.
- **Math** — a typesetter in Dart: inline and display math become widgets
  without a host renderer (fractions with a rule, radicals with an overline,
  superscripts and subscripts hung off the base axis, the Greek and operator
  symbol table, verbatim `\text{}`). A host renderer still overrides it.
- **Mermaid** — a flowchart renderer in Dart: `graph` / `flowchart` in
  TD/TB/BT/LR, node shapes (box, rounded, stadium, decision), chains and
  labelled edges are parsed into a layered layout and painted, so a ```mermaid
  fence renders without the JavaScript engine. Diagram types outside the subset
  fall back to the source, and a host drawing overrides the built-in one.
- **Generative UI** — the model-emitted tree (`$type` discriminator, `$key` /
  `$action` / `$status` reserved, children parsed recursively, depth-bounded at
  64), the "view source" serializer with upstream's escaping and pretty-print
  rules, and a renderer that walks a host registry (a standard vocabulary of
  Text / Heading / Card / Stack / Button / Alert / Image ships with it).
  Unregistered components render their name instead of vanishing, and `$action`
  fires the host's handler.
- **Tracing** — `SpanTree` resolves parents (a missing parent or a cycle reads as
  a root), computes depth with a cache, keeps collapse per span, yields the
  visible rows and the window from the earliest start to the latest end. The
  primitive family (name, type badge, status indicator, collapse toggle, indent,
  children, timeline bar) reads it through `AuiSpanScope`, so a host can build
  any span view; an exporter is a host concern, spans arrive as `SpanData`.
- **Hosted platform** — the threads API: list with `is_archived` / `limit` /
  `after`, create with `last_message_at` / `external_id` / metadata, update,
  delete, and the thread's messages. Auth is a token callback with the project
  and workspace scoping in the path, so an app can refresh credentials without
  rebuilding the client; timestamps read as ISO strings or epoch seconds.
- **MCP** — a Model Context Protocol client over the streamable HTTP transport
  (JSON replies or `text/event-stream`), with the handshake, cursor-paginated
  `tools/list`, `tools/call` content flattening, resources, and a runtime
  [`Toolkit`] built from every configured server. One failing endpoint lands in
  a failures list instead of taking the others down.
- **Primitives** — thread layout with auto-scroll and top/bottom turn anchor,
  message parts pipeline with tool-UI resolution, composer with submit modes
  and edit mode, action bar with copy/reload/edit, branch picker.
- **Styled components** — thread, bubbles, composer, reasoning disclosure,
  tool-call card, markdown (headings, lists, fenced code, inline formatting,
  links), light and dark themes matching the shadcn neutral palette.
- **Composer family** — mentions and slash commands behind a trigger adapter,
  attachment chips, a context-usage ring, dictation with a live level waveform,
  queued turns that send themselves when the run settles, and per-thread draft
  restore. Speech and feedback adapters back the clone action bars.
- **Thread list** — `ThreadListRuntime` with per-thread drafts and titles, plus
  the primitives and sidebar shell the clones' thread switcher is built on.
- **Agent and job family** — `AssistantAgentPlan`, `AssistantAgentStatus`,
  `AssistantAgentHandoff`, `AssistantAgentCard`, `AssistantSubagentList`,
  `AssistantTaskCard`, `AssistantJobProgress`, `AssistantScheduleCard`,
  `AssistantCheckpointHistory`, `AssistantMemoryChips`,
  `AssistantBackgroundInbox`, plus the `AssistantCanvasSplit`,
  `AssistantFlowCanvas` and `AssistantComputerUse` surfaces.
- **Observability** — `AssistantTraceWaterfall`, `AssistantCostMeter`,
  `AssistantContextBreakdown`, `AssistantActivityGraph` / `AssistantHeatGraph`
  (shared `AuiHeatCalendar`), `AssistantConfidenceMarker`,
  `AssistantScoreBreakdown`, `AssistantChart`, `AssistantDataTable`,
  `AssistantComparisonCard`, `AssistantRecommendationCard`,
  `AssistantConnectionState`, `AssistantNumberTicker`, `AssistantSpecSheet`,
  `AssistantTimeline`, `AssistantTodoList` and `AssistantFlowGraph`.
- **Thread extras** — `AssistantEmptyState`, `AssistantErrorState`,
  `AssistantSuggestions`, `AssistantDaySeparator`, `AssistantStreamingText`,
  `AssistantSharedConversation`, `AssistantRegenerateMenu`, plus the
  `Jump to latest` pill the thread floats while the viewport is unpinned and
  the discard notice on an in-place edit.
- **Tool family** — a run of tool calls collapses into `AssistantToolGroup`
  (`groupToolCalls: true` on `AssistantThread`, backed by the
  `groupBy`/`partGroupBuilder` primitive), a failed call renders
  `AssistantToolError` with its retry budget, and `AssistantToolTimeline`
  narrates the steps with the files they touched. Human-in-the-loop ships as
  `AssistantApprovalCard` and `AssistantElicitationForm`; `AssistantMcpServerPanel`
  and `AssistantCommandPalette` cover the panel and the ⌘K surface.

## Vendor clones

Four presentations ship with the package, each a faithful port of the
corresponding [example page](https://www.assistant-ui.com/examples): the same
runtime and primitives, restyled to the vendor's own design language.

| Widget | Mirrors | Signature details |
|---|---|---|
| `ChatGptClone` | chatgpt.com | `#ffffff`/`#000000` surfaces, `#212121` dark composer, rounded-28 composer, high-contrast user bubble, always-visible assistant action bar |
| `ClaudeClone` | claude.ai | `#F0ECE0` cream, serif typography, borderless composer, mode tabs, `#c96442` accent, hover-only action bars |
| `GeminiClone` | gemini.google.com | ambient radial glow behind the greeting, single-row pill composer, `+` tool menu, Fast/Thinking picker, three send states |
| `GrokClone` | grok.com | pill composer with a collapsing model pill, animated Mic→Send→Stop slot, inverted primary, message timing tooltip |

They are pure presentation over the same runtime, so switching between them
keeps the conversation:

```dart
AuiRuntimeProvider(
  runtime: runtime,
  child: const GrokClone(),
);
```

Each clone accepts `onPickAttachments` (host file picking) and the vendor's
footnote text; everything else comes from the runtime.

## What is not (yet)

Persistence and cloud backends, the composer model picker, upload adapters for
platform file pickers, generative UI, MCP panels, message virtualization, and
the agent/observability element families (waves E–I in the plan). The
primitives leave room for all of them.

## Quick start

```dart
import 'package:assistant_ui/assistant_ui.dart';

class MyAdapter extends ChatModelAdapter {
  @override
  Stream<ChatModelRunResult> run(ChatModelRunContext context) async* {
    final response = await callMyBackend(context.messages);
    String text = '';
    await for (final token in response.tokens) {
      text += token;
      // Each event carries the full content, not a delta.
      yield ChatModelRunResult(content: <MessagePart>[TextPart(text)]);
    }
  }
}

void main() => runApp(
      MaterialApp(
        home: Scaffold(
          body: AuiRuntimeProvider(
            runtime: LocalRuntime(adapter: MyAdapter()),
            child: const AssistantThread(),
          ),
        ),
      ),
    );
```

### Talking to an existing assistant-ui backend

`DataStreamChatModelAdapter` posts `{messages, tools, system}` — the body
`@assistant-ui/react-data-stream` sends — and parses the data stream response.

```dart
final runtime = LocalRuntime(
  adapter: DataStreamChatModelAdapter(apiUrl: '/api/chat'),
);
```

### Tools

```dart
final runtime = LocalRuntime(
  adapter: adapter,
  options: LocalRuntimeOptions(
    maxSteps: 3,
    tools: <String, ToolDefinition>{
      'get_weather': ToolDefinition(
        description: 'Get the current weather',
        parameters: <String, Object?>{
          'type': 'object',
          'properties': <String, Object?>{'city': <String, Object?>{'type': 'string'}},
        },
        execute: (args) async => fetchWeather(args['city']! as String),
      ),
    },
  ),
);
```

Tool schemas reach the adapter through `context.tools`; results are fed back in
a continuation run, so `text → tool call → answer` stays one assistant message.

MCP servers register the same way — their tools are discovered and executed
over the wire:

```dart
final servers = McpServers(const <McpServerConfig>[
  McpServerConfig(
    id: 'docs',
    name: 'docs',
    transport: 'http',
    url: 'https://example.com/mcp',
    headers: <String, String>{'authorization': 'Bearer …'},
  ),
]);
final (Toolkit tools, List<(String, String)> failures) = await servers.connect();

final runtime = LocalRuntime(
  adapter: adapter,
  options: LocalRuntimeOptions(tools: tools),
);
```

The config dialog (`AssistantMcpConfig`) hands the host the same
`List<McpServerConfig>` on every edit, so the panel and the client share one
model.

## Custom UI on top of the primitives

```dart
AuiThreadLayout(
  viewport: AuiThreadViewport(
    turnAnchor: AuiTurnAnchor.top,
    child: AuiThreadMessages(
      builder: (context, message, isLast) => AuiMessage(
        child: message.isUser ? const MyBubble() : const MyAnswer(),
      ),
    ),
  ),
  footer: AuiThreadFooter(
    child: Column(
      children: <Widget>[
        AuiComposerInput(placeholder: 'Ask anything…'),
        AuiComposerSend(builder: (context, enabled) => MySendButton(enabled)),
      ],
    ),
  ),
);
```

`AuiIf` selects state the way `AuiIf` does upstream:

```dart
AuiIf(
  condition: (state) => state.thread.isEmpty,
  child: const Text('Ask something to begin'),
);
AuiIf(
  condition: (state) => state.message?.isLast ?? false,
  child: const AssistantActionBar(),
);
```

## Verification

```bash
flutter test          # 394 tests: runtime, protocol, adapters, components, clones, widgets
flutter analyze       # clean
cd example && flutter run -d chrome
```

The example was driven end to end in a real browser (headless Chrome over CDP):
streaming text with a stop button, a tool-call round trip — arguments, result
card, and the follow-up answer in the same assistant message — markdown lists,
tables and fenced code, regenerate plus the 1/2 branch picker, attachments,
mentions and slash commands, the context ring filling as a thread grows,
dictation streaming into the composer, tool grouping in a live thread, and the
tool-family page (`?page=tools`): grouping states, the run timeline, a failed
call, approval, elicitation, the MCP panel and the command palette. Two more
pages cover the later waves: `?page=agents` (status, plan, handoff, agent card,
subagents, task, job, schedule, checkpoints, memory, inbox, canvas split, flow
canvas, computer use) and `?page=observability` (trace, cost, context, both
heatmaps, confidence, score, chart, table, comparison, recommendation,
connection, ticker, spec sheet, timeline, todos, flow graph). Each vendor clone was opened through `?page=chatgpt|claude|gemini|grok`
and checked against its palette table in both the empty and conversation states.

Coverage against the upstream catalogs lives in
[`docs/element-coverage.md`](docs/element-coverage.md) (125 elements, generated
by `dart run tool/sync_element_coverage.dart`) and
[`docs/package-coverage.md`](docs/package-coverage.md) (46 packages, generated
by `dart run tool/sync_package_coverage.dart`); the wave plan is in
[`docs/PORT_PLAN.md`](docs/PORT_PLAN.md).

## Landing page replica

`landing/` is a standalone Flutter web app that reproduces
[the landing page](https://www.assistant-ui.com/) one-to-one: the pinned nav
with its hover dropdowns, the 72px hero, the interactive demo (built on this
package), `What you install` with the five runtime tabs, `What the runtime
handles` with a live element per act, `The primitives` with the interactive
anatomy, the logo wall and quotes, `Get started`, and the footer. Dark is the
default like the live site; `?theme=light` opens the light palette.

```bash
cd landing && flutter run -d chrome
flutter test          # 6 tests: sections, tabs, live showcase, anatomy, nav
```

Spec, captures and the section-by-section mapping live in `docs/landing/`;
the pixel comparison against the live page is in `docs/landing/parity/`.

## Differences from the React original

- Selectors: `useAuiState(selector)` becomes `AuiStateBuilder<T>(selector:
  ...)`; widgets rebuild only when their slice changes.
- Slots: the `children` render functions become builder callbacks
  (`builder`, `partBuilder`, `toolUIs`).
- `asChild` becomes a builder or plain composition — Flutter has no element
  merging.
- Scrolling: the viewport owns its `ScrollController`. `AuiTurnAnchor.top`
  pins the latest user message to the top on run start; the upstream
  clamp-when-tall behavior is not implemented.
- Virtualization: messages render inside one scroll view. Long threads are the
  point where a `ListView.builder` port of `ThreadPrimitive.Messages` belongs.

## License

MIT, matching the original project.
