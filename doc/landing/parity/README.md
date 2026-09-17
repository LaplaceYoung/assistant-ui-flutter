# Landing page parity

Section-by-section comparison of the replica (`landing/`) against the live page
(`https://www.assistant-ui.com/`), captured in headless Chrome at a **1300×953**
viewport (1280 CSS px + `--force-device-scale-factor=1`, scrollbars hidden).

## How it was captured

1. Both pages are loaded in the same Chrome over CDP.
2. The live page scrolls with `window.scrollTo(0, y)` at `y = 0, 560, 1120, …`.
   The replica is a Flutter canvas whose own scroll view owns the offset, so it
   is scrolled with wheel events of the same delta.
3. Each frame is written to disk as `src_<n>.png` / `rep_<n>.png`, and
   `side_<n>.png` is the pair at 50% scale.

Because Flutter's service worker caches `main.dart.js`, the build's
`flutter_service_worker.js` is deleted before serving: otherwise a fresh build
renders the previous bundle and the comparison silently measures stale code.

## What was measured

| Frame | Section | Pixels differing > 60 (0–255) |
|---|---|---|
| 0 | hero | 4.3% |
| 1 | hero → demo panel | 2.5% |
| 2 | demo panel | 3.4% |
| 3 | `What you install` + setup tabs | 2.5% |
| 4 | `What the runtime handles` | 3.2% |
| 5 | `The primitives` | 4.6% |
| 6 | social proof | 4.8% |
| 7 | `Get started` + footer | 4.3% |

Mean **3.7%**. The residue is font rasterisation (the bundled Public Sans
renders ~10% wider than the live page's, so line boxes match within 2px while
glyph widths differ), the demo panel's animated content, and the dotted art.

## Geometry the fixes were driven by

Read off the live page with `getComputedStyle` at the capture viewport:

| Element | Live value |
|---|---|
| content frame | `main` `max-w-7xl` (1280) + `px-4` → content edge **26px**, `pt-28` (112px) |
| header | **48px** tall |
| `h1` | 72px / line-height 74.88 / weight 500 / tracking −1.08px, measure `20ch` = 897px, top 160 |
| hero sub-copy | 15px / 24.375, measure 367px, top 322 |
| primary CTA | height **32**, radius **8**, padding 0/12, 14px/20 weight 500 |
| secondary CTA | plain text link, 13px/19.5 — no box |
| nav chip (`Cloud`) | radius 8, 12.8px label, padding 0/10 |
| stats row | 13px, 28px gaps, top 439 |

## Deltas found and fixed

- Hero used a 96px desktop gutter and a narrower centred column → content edge
  sat at 204px instead of 26px. The hero now uses the page frame.
- The hero carried an `assistant-ui` badge that the live page does not have.
- The hero `Stack` centred its loose child; the column now fills the frame.
- Heading wrap: the live `h1` balances to `The frontend library / for AI
  agents.`; Flutter has no `text-balance`, so the desktop break is explicit.
- `LandingButton` was a pill (radius 999, 18/10 padding, ~40px tall) → now the
  live 32px / radius 8 / 0-12 padding box; the secondary CTA is a text link.
- The header was 64px → 48px, matching the live page and the hero's `pt-28`.
