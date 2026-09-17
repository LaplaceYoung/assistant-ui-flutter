# assistant_ui_landing

A one-to-one Flutter replica of the [assistant-ui landing page](https://www.assistant-ui.com/),
built with the `assistant_ui` package in this repo.

```bash
flutter run -d chrome          # or: flutter build web --release
```

## What is replicated

Every section of the live page, in order:

1. Sticky top nav — logo, Docs / Products / Resources / Pricing with dropdowns,
   `Search ⌘K`, `Ask AI ⌘I`, the `Cloud` pill
2. Hero — the 72px display heading on the page frame (content edge 26px, header
   48px, `pt-28`), sub-copy, `Read the docs` + `npx assistant-ui init`, the
   12.2k / 1.3M / Y Combinator stats, and the dotted bubble illustration
3. The interactive demo panel — a real thread on this package's runtime, with the
   thread rail, `New thread`, `New chat`, the model pill and the seven suggestion chips
4. `What you install` — `@assistant-ui/react`, the setup copy, the five runtime
   tabs (AI SDK / LangGraph / LangChain / Mastra / Custom) that swap the provider
   code sample, its caption and its guide link, the pixel-matrix animation
5. `What the runtime handles` — the 01–10 capability list where each act shows a
   live element from this package (streamed text, the reasoning panel, a tool
   card, the approval gate, sources, attachments, the branch picker, suggestions,
   the dictation control, a chart) on the live page's 7s rotation
6. `The primitives` — "Yours to reshape." with the interactive anatomy: the sample
   and the schematic light the same part (Root / Viewport / Messages / Scroll to
   bottom / Composer) on a 2.8s cycle, hold when you point at a line, and the
   caption follows
7. Social proof — the ecosystems sentence, the two logo rows and the three quotes
8. `Get started` — "Start in the docs.", the command chip and the two calls to action
9. Footer — six link columns, the legal row, the status pill, socials and the theme toggle

The nav dropdowns (Products: Platforms + Primitives; Resources: Learn, Open source,
Company, Status) open on hover and render above the page from the page stack, since
a pinned header paints the sections after it over anything its own child overflows.

Copy, colours, type scale and spacing come from the captures in
`doc/landing/` (`copy.md`, `theme.md`, `site.css`, `DESIGN.md`), and the
section-by-section pixel comparison against the live page lives in
`doc/landing/parity/` (mean 3.7% of pixels differ; see that folder's README
for the method and the geometry the fixes were driven by).

## Fidelity notes

- Fonts are the real ones: Public Sans and JetBrains Mono, bundled from Google
  Fonts and used with explicit `wght` variations.
- The palette is the site's OKLCH token set resolved to sRGB; dark is the default,
  matching the live page, and the footer toggle switches to light.
- Brand logos are typographic stand-ins (the vendors' SVG marks are not shipped).
- The `⌘K` search palette and the docs playground are visual replicas; their
  backends are out of scope.
- Buttons that leave the page (Read the docs, Contact sales, Cloud, the docs
  links) are inert: this repo ships the landing page, not the docs site.
