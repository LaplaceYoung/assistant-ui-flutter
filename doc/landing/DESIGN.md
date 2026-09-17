# Landing page replica — design spec

Baseline: `https://www.assistant-ui.com/` captured 2026-09-17.
Artifacts in this folder: `landing.html` (DOM snapshot), `site.css` (their stylesheet),
`copy.md` (every string in document order), `theme.md` (OKLCH tokens resolved to sRGB),
`reference/viewport_*.webp` (six viewport screenshots at 1440×813, dark theme).

Replica target: `landing/` — a standalone Flutter web app in this repo, one route,
1:1 against the reference at 1440 wide, responsive down to 390.

## Global

| Item | Value |
|---|---|
| Content column | `max-w-7xl` = 1280px, `px-4` (16px) gutters |
| Page padding | hero top 80 → 112px at md, bottom 96 → 128px |
| Fonts | sans = Public Sans, mono = JetBrains Mono (fallbacks: Inter/DejaVu Sans, Menlo/monospace) |
| Radius | `--radius` 8px; pills `rounded-full`; cards `rounded-xl` (12px); page chrome `rounded-page` |
| Default theme | dark (site renders dark with no stored preference); toggle in the footer |
| Borders | light `#e5e5e2`; dark `white @ 10%` (`#fafaf9` at 0.10 alpha) |
| Muted surface | light `#f5f5f2`; dark `#282826` |
| Link affordance | `→` suffix on text links; underline on hover |

## Sections, in order

1. **Top nav** (sticky, `rounded-page`)
   - Left: logo mark (rounded square with a chat glyph) + `assistant-ui`
   - Center: `Docs`, `Products ⌄`, `Resources ⌄`, `Pricing`
   - Right: `Search ⌘K`, `Ask AI ⌘I`, white pill `Cloud`
   - Dropdowns open on hover/click; Products: React Native, Ink, Hosted, Cloud, Playground,
     Primitives (tw-shimmer, Heat Graph, Safe Content Frame, react-o11y)
2. **Hero**
   - `The frontend library for AI agents.` — set as `The / frontend / library / for AI / agents.` line breaks in the source, display size, tight leading, weight 600
   - Sub: `Primitives and a runtime for production chat. Any backend, through adapters.`
   - Row: `Read the docs` (pill button) + `npx assistant-ui init` (copy-to-clipboard code chip)
   - Stats: `12.2k GitHub stars`, `1.3M weekly downloads`, `Backed by [Y] Combinator`
3. **Live demo** — a real, interactive chat (this port renders it with its own runtime)
   - Chrome: sidebar with `New chat`, `Sign in`; `New thread`; `Load more`
   - Empty state: `How can I help you today?` + model pill `GPT-5.6 Luna` / `Low`
   - Suggestion chips: Weather in Tokyo · Show a sales dashboard · Switch to dark mode ·
     Derive the geometric series · Diagram a streaming chat app · Add a thread list · Remember my stack
   - Footer link: `Explore other examples →`
4. **What you install** (`WHAT YOU INSTALL` eyebrow)
   - `@assistant-ui/react` heading; body `The runtime owns the thread, the stream, and the tools.`
   - `THE SETUP` eyebrow; `A provider, a hook, one component.` + `The complete client, whatever runs behind it.`
   - Runtime tab row: AI SDK · LangGraph · LangChain · Mastra · Custom · `ALL RUNTIMES →`
   - Code block (syntax colored) with the provider/hook/Thread sample
   - Caption `Your route runs the model. The transport streams it back.` + `read the AI SDK guide →`
   - Right: the loading-state pixel matrix animation
5. **What the runtime handles** (`WHAT THE RUNTIME HANDLES`)
   - 01–10 list: Streaming, Reasoning, Tools, Approval, Sources, Attachments, Branching,
     Suggestions, Voice, Generative UI; the active row is highlighted, the right panel previews it
   - `All elements →`
6. **The primitives** (`THE PRIMITIVES` eyebrow, `Yours to reshape.`)
   - Body: `Every part is a component you compose; the CLI copies the UI source into your repo.`
   - Code block: `ThreadPrimitive.Root` … `ComposerPrimitive.Send` sample, with the composer lines highlighted
   - Right: mini thread mock with a `ROOT` badge
   - `Customize the thread →` link; `Root · Owns the runtime context. Everything composes inside.`
7. **Trusted by / social proof**
   - Line: `Works with AI SDK, LangGraph, and LangChain, or any backend through adapters. Ships for
     React, Native, and Ink. Elements extends it. Cloud hosts threads and persistence when you want them.`
   - Logo wall (2 rows): mastra, Google Cloud, P (paperclip), Neon, AgentOps / thesys, voltagent,
     ONLYOFFICE, unsloth
   - Three quote cards (@LangChainAI, @neondatabase, @hwchase17)
8. **Get started** (`GET STARTED`, `Start in the docs.`)
   - Body: `The command scaffolds a working thread. The docs take it from there.`
   - Command chip `npx assistant-ui init` (with copy icon), `Read the docs` button, `Contact sales`
   - Footnote `@assistant-ui/react · MIT License`
9. **Footer**
   - Six columns: Library (Docs, Changelog, Playground) · Platforms (React, React Native, Ink) ·
     Extend (Elements, Design) · Primitives (tw-shimmer, Heat Graph, Safe Content Frame, react-o11y) ·
     Resources (Examples, Showcase, Open source, Packages) · Company (Blog, Careers, Brand, Traction, Pricing)
   - Bottom: `©2026 Agentbase AI Inc.` · Privacy · Terms · Cookie settings · `All systems operational` ·
     social icons (X, GitHub, Discord) · theme toggle

## Flutter mapping

| Landing piece | Flutter building block |
|---|---|
| Hero + nav + footer chrome | local landing widgets (`landing/lib/sections/*`) |
| Live demo chat | this package: `LocalRuntime` + `AssistantThread`, scripted adapter |
| Code blocks | landing `CodeBlock` widget with the same token colors as `site.css` |
| Pixel matrix animation | `AssistantLoadingState` (already in the package) |
| Logo wall | text/shape marks (no third-party SVG assets shipped) |
| Quotes | cards with the same type scale |

## Fidelity rules

Copy is verbatim from `copy.md`. Colors come from `theme.md` only. Spacing/typography follow the
values in `site.css` (`text-*`, `gap-*`, `p-*` classes are recorded per section in the code).
Where a piece cannot be reproduced (brand SVG logos, the interactive docs playground), the code
carries a `// Fidelity gap:` comment and this file lists it in *Known gaps* below.

## Known gaps

- Brand logos are typographic stand-ins, not the vendors' SVG marks.
- The nav search palette (`⌘K`) is a visual replica; wiring it to a doc index is out of scope.
