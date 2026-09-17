# Gaps

What the port does not have, kept as a list rather than a feeling. Each line
says what is missing, why, and where it would be finished. Derived from
`doc/element-coverage.md` (elements), `doc/package-coverage.md` (packages) and
the surfaces built on top of them.

## Landing: the playground's controls

The playground mirrors upstream's builder — presets, a live preview, generated
code, a shareable URL. Its panel lists only the knobs this port honours, because
a control that changes nothing is worse than an absent one. These are the
upstream controls that are **not** listed yet, with the reason:

| Upstream control | Why it is absent | Where it lands |
|---|---|---|
| `attachments` | The thread takes `onPickAttachments`, but no attachment UI is wired into the styled thread | `components/thread.dart` — the composer's attach button |
| `branchPicker`, `editMessage` | The primitives exist (`AuiBranchPicker`, `AssistantInlineComposer`); the styled thread renders them without a host switch | `components/thread.dart` |
| `actionBar.{copy,reload,speak,feedback}` | `AssistantActionBar` reads the runtime, not a config; no per-entry flags | `components/action_bar.dart` |
| `markdown` | Part rendering is not switchable: text always goes through `AssistantMarkdown` | `components/parts.dart` |
| `codeHighlightTheme` | No syntax highlighter in the port; code blocks render as monospace | `components/markdown.dart` (would need a grammar) |
| `sources`, `followUpSuggestions` | `SourcePart` renders as a chip; follow-up suggestions render from the thread's suggestion list, not as a per-message row | `components/parts.dart` |
| `typingIndicator`, `loadingIndicator`, `loadingText` | The typing dot and the loading row are hard-coded in the thread | `components/thread.dart` |
| `userMessagePosition` | User bubbles are right-aligned by construction | `components/parts.dart` |
| `animations` | Motion is always on; the port honours `MediaQuery.disableAnimations` instead of a switch | `components/*` — deliberate |

Styles that **are** honoured: `theme`, `colors.accent`, `borderRadius`,
`maxWidth`, `fontSize`, `messageSpacing` — each maps to an `AssistantTheme` value
or a constructor argument, and the generated snippet prints exactly that.

## Elements

Four are partial, with the reason recorded in `doc/element-coverage.md`:
`markdown-text` (Mermaid beyond flowcharts, LaTeX beyond the typesetter),
`web-preview` (non-web frames), `attachment` (storage backend), `file` (host
download action).

## Interactions that were inert, and are not now

Found by pressing things rather than reading them:

| Element | What was wrong | Now |
|---|---|---|
| `thread-list` rows | The archive and delete buttons were wired to `onPressed: () {}` — they hovered, and did nothing | Both call `ThreadsRuntimeApi.archive` / `unarchive` / `delete` for their own row; `test/thread_list_actions_test.dart` hovers to reveal them and asserts the thread moved |
| `chat-panel` composer | The composer was a static `Text` that looked like a field; only the send chip was tappable | With `onSend` the composer is a real `TextField` — type, press Enter or the send chip; without it, the static strip stays |
| `settings-panel` toggle rows | Only the switch answered a tap; the label above it, which reads as part of the setting, did nothing | The row takes the tap |
| `attachment` remove | The close icon was a bare gesture with no label, so neither a reader nor a screen reader could name it | `Semantics(button: true, label: 'Remove')` |

`test/element_interactions_test.dart` taps the primary control of sixteen
elements — the regenerate menu, the quote toolbar, the feedback dialog, the
permission request (grant and deny), the launcher bubble, the chat panel, the
artifact card, the code runner, thread search, the turn rail, the prompt library,
the document reference's anchors, onboarding's next and skip, the memory chips
and the job progress — and asserts the callback fires, so this class of miss
cannot come back quietly.

## Verification not yet done

- **No frame-by-frame diff of the playground.** `tool/landing_parity.sh` measures
  the landing page against the live one (mean 3.6% of pixels); the playground has
  behavioural tests and a screenshot check, not a pixel comparison.
- **No per-element visual diff.** The 121 ported elements have unit and widget
  tests and appear in the gallery (archived under `doc/gallery/`, captured by
  `example/tool/capture_gallery_test.dart --update-goldens`); they have not each
  been compared against the live site's rendering.
- **The live site's copy for the playground's own chrome** (its toolbar icons and
  labels) is matched in spirit, not transcribed.
