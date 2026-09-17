## 0.1.0

The first release: a Flutter port of assistant-ui.

- **Runtime** — `LocalRuntime` stands in for `useLocalRuntime`: streaming with
  cumulative chunks, cancellation, regeneration as a branch, edit-and-rerun,
  branch switching, tool execution with `maxSteps`, human-in-the-loop tools and
  the thread/composer state the React store owns.
- **Primitives** — `AuiThread`, `AuiMessage`, `AuiComposerInput`, `AuiActionBar`,
  `AuiBranchPicker`, `AuiIf` and state builders that rebuild only the slice a
  widget reads.
- **Components** — 121 of the 125 upstream elements, including markdown with
  fenced-code highlighting, a Mermaid flowchart renderer and a LaTeX-ish math
  typesetter written in Dart, the tool and agent families, the observability
  family and the shells.
- **Adapters** — Vercel AI data stream v1, MCP, AG-UI, A2A, LangGraph, Google
  ADK, generative UI, the o11y span tree and the hosted cloud threads API.
- **Clones** — ChatGPT, Claude, Gemini and Grok reproductions.
- **Motion** — the interaction motion is aligned per family against the upstream
  sources, with reduced-motion support throughout (`MediaQuery.disableAnimations`).
