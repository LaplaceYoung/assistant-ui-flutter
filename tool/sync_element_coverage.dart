// Generates doc/element-coverage.md from the official element inventory.
//
// The inventory (doc/official_elements.txt) is a snapshot of
// packages/ui/src/components/react/assistant-ui/elements in the upstream repo.
// Status lives here, next to the coverage report it produces, so the two can
// never drift:
//
//   dart run tool/sync_element_coverage.dart
//
// Refresh the inventory itself with:
//
//   curl -s "https://api.github.com/repos/assistant-ui/assistant-ui/contents/\
//   packages/ui/src/components/react/assistant-ui/elements" \
//     | jq -r '.[] | select(.type=="file") | .name' | grep -vE '\.(test|radix)\b' \
//     | sed 's/\.tsx$//' | sort > doc/official_elements.txt
import 'dart:io';

/// status per element: ported | partial | planned | n/a
class Entry {
  const Entry(this.status, {this.dart, this.wave, this.note});

  final String status;
  final String? dart;
  final String? wave;
  final String? note;
}

const Map<String, Entry> _entries = <String, Entry>{
  'thread': Entry('ported', dart: 'components/thread.dart'),
  'thread-list': Entry('ported',
      dart: 'components/thread_list.dart',
      note: 'runtime-backed list with search, archive, delete, auto-title'),
  'thread-list-sidebar': Entry('ported',
      dart: 'components/thread_list.dart',
      note: 'AssistantShell: collapsible rail + mobile drawer'),
  'assistant-sidebar': Entry('ported',
      dart: 'components/thread_list.dart',
      note: 'rail with collapse-to-icon, drag-to-resize with min/max clamps, and the copilot side (rail on the right); below the mobile breakpoint it becomes a drawer'),
  'message-actions': Entry('ported', dart: 'components/action_bar.dart'),
  'message-branches': Entry('ported', dart: 'components/action_bar.dart'),
  'message-pair': Entry('ported', dart: 'components/thread.dart',
      note: 'AssistantUserMessage + AssistantAssistantMessage'),
  'message-timing': Entry('ported', dart: 'components/message_timing.dart'),
  'markdown-text': Entry('partial',
      dart: 'components/markdown.dart',
      note: 'fenced code runs through the syntax-highlighter tokenizer and the coldark palettes; ```mermaid fences render through the built-in painters (flowchart, pie, sequence), and inline/display math is typeset by components/math_renderer.dart (fractions, radicals, scripts, environments, accents, the blackboard letters, the symbol table) with a host renderer overriding it. Constructs outside those subsets still fall back to the styled source'),
  'syntax-highlighter': Entry('ported',
      dart: 'components/syntax_highlighter.dart',
      note: 'Dart tokenizer instead of Prism; the coldark-cold / coldark-dark palettes are taken verbatim from prism-themes, and the markdown fenced blocks color through the same tokens'),
  'reasoning': Entry('ported', dart: 'components/parts.dart'),
  'tool-call': Entry('ported', dart: 'components/parts.dart'),
  'tool-fallback': Entry('ported', dart: 'components/parts.dart'),
  'tooltip-icon-button': Entry('ported', dart: 'components/tooltip_icon_button.dart'),
  'typing-indicator': Entry('ported', dart: 'components/typing_indicator.dart'),
  'loading-state': Entry('ported',
      dart: 'components/indicators.dart',
      note: 'AssistantLoadingState'),
  'attachment': Entry('partial',
      dart: 'components/attachment.dart',
      note: 'preview + progress + remove and the AttachmentAdapter contract are ported; a concrete storage backend stays with the host, as upstream leaves it to the app'),
  'composer': Entry('ported',
      dart: 'components/composer.dart',
      note: 'input/send/cancel/attachments/voice/queue/context done; the model picker and the quote preview drop into the leading/footer slots, covered by a wiring test'),
  'composer-attachments': Entry('planned', wave: 'D'),
  'composer-trigger-popover': Entry('ported',
      dart: 'primitives/composer_triggers.dart',
      note: 'char trigger, caret token detection, keyboard nav, anchored panel'),
  'composer-mentions': Entry('ported',
      dart: 'components/composer_triggers.dart',
      note: 'adapter + popover + directive insertion'),
  'composer-slash-commands': Entry('ported',
      dart: 'components/composer_triggers.dart',
      note: 'adapter + menu; commands consume the token'),
  'directive-text': Entry('ported',
      dart: 'components/composer_triggers.dart',
      note: '@[Name](id) rendered as inline chips'),
  'model-picker': Entry('ported',
      dart: 'components/model_picker.dart',
      note: 'families with capability chips, context and price, current model checked'),
  'context-display': Entry('ported',
      dart: 'components/composer_context.dart',
      note: 'usage ring + optional token label from thread.contextUsage'),
  'voice': Entry('ported',
      dart: 'components/composer_voice.dart',
      note: 'mic toggle + level waveform; streams dictation transcripts'),
  'voice-conversation': Entry('ported',
      dart: 'components/voice_conversation.dart',
      note: 'orb scaled by input level, caption per phase and the mute / end transport'),
  'mobile-composer': Entry('ported',
      dart: 'components/mobile_composer.dart',
      note: 'quick actions, attach, send / stop, keyboard-aware chrome'),
  'message-queue': Entry('ported',
      dart: 'components/message_queue.dart',
      note: 'stacked queued turns, cancel one by tap'),
  'draft-restore': Entry('ported',
      dart: 'runtime/local_runtime.dart',
      note: 'per-thread composer drafts survive thread switching and run start'),
  'agent-card': Entry('ported',
      dart: 'components/agent_card.dart',
      note: 'skills, endpoint footer, connect / connected'),
  'agent-handoff': Entry('ported',
      dart: 'components/agent_handoff.dart',
      note: 'from -> to pills, reason, carried-over list'),
  'agent-plan': Entry('ported',
      dart: 'components/agent_plan.dart',
      note: 'progress bar, per-step check / spinner / dot'),
  'agent-status': Entry('ported',
      dart: 'components/agent_status.dart',
      note: 'working/waiting/done/failed chip with elapsed and trailing control'),
  'background-inbox': Entry('ported',
      dart: 'components/background_inbox.dart',
      note: 'ready vs in-flight counts, collect on tap'),
  'canvas-split': Entry('ported',
      dart: 'components/canvas_split.dart',
      note: 'one widget instead of upstream seven pieces; md breakpoint stacks'),
  'checkpoint-history': Entry('ported',
      dart: 'components/checkpoint_history.dart',
      note: 'current mark, ahead rows dimmed, hover restore'),
  'computer-use': Entry('ported',
      dart: 'components/computer_use.dart',
      note: 'browser chrome, cursor trail, active step footer'),
  'flow-canvas': Entry('ported',
      dart: 'components/flow_canvas.dart',
      note: 'upstream edge routing (down/loop-bottom/loop-right); node coordinates are input because Flutter cannot measure pre-layout'),
  'job-progress': Entry('ported',
      dart: 'components/job_progress.dart',
      note: 'weighted overall bar, stage names, eta, cancel'),
  'memory-chips': Entry('ported',
      dart: 'components/memory_chips.dart',
      note: 'fresh vs existing tints, forget control'),
  'schedule-card': Entry('ported',
      dart: 'components/schedule_card.dart',
      note: 'cadence, next-run block, enable switch, run history'),
  'subagent-list': Entry('ported',
      dart: 'components/subagent_list.dart',
      note: 'per-agent progress bars plus the shimmering summary row'),
  'task-card': Entry('ported',
      dart: 'components/task_card.dart',
      note: 'five states, disclosure transcript, actions and result blocks'),
  'activity-graph': Entry('ported',
      dart: 'components/activity_graph.dart',
      note: 'contribution calendar with the range total'),
  'confidence-marker': Entry('ported',
      dart: 'components/confidence_marker.dart',
      note: 'underlines by confidence, basis pill while hovered'),
  'context-breakdown': Entry('ported',
      dart: 'components/context_breakdown.dart',
      note: 'segment bar, comma-formatted tokens, headroom row'),
  'cost-meter': Entry('ported',
      dart: 'components/cost_meter.dart',
      note: 'run vs session, per-model share bar and token counts'),
  'heat-graph': Entry('ported',
      dart: 'components/heat_graph.dart',
      note: 'month labels, day labels, legend, per-cell tooltips; the layout lives in components/heat_calendar.dart because upstream delegates it to the heat-graph package'),
  'score-breakdown': Entry('ported',
      dart: 'components/score_breakdown.dart',
      note: 'verdict band by ratio, weighted criteria, notes'),
  'trace-waterfall': Entry('ported',
      dart: 'components/trace_waterfall.dart',
      note: 'span bars by status with a running pulse'),
  // Wave E — tool family (ported in this wave).
  'tool-group': Entry('ported',
      dart: 'components/tool_group.dart',
      note: 'paper card with counts and per-call rows; the .aui Root/Trigger/Content trio is not ported'),
  'tool-timeline': Entry('ported',
      dart: 'components/tool_timeline.dart',
      note: 'swap label, revealed steps and diff stats; every revealed step enters '
          'with fade + slide-in-from-bottom over 300ms and the trigger chevron turns '
          'on the element curve, both per the upstream classes'),
  'tool-error': Entry('ported',
      dart: 'components/tool_error.dart',
      note: 'name/target/attempt, monospace error block, retry + skip'),
  'approval-card': Entry('ported',
      dart: 'components/approval_card.dart',
      note: 'request/running/done/denied states'),
  'elicitation-form': Entry('ported',
      dart: 'components/elicitation_form.dart',
      note: 'text/choice/toggle fields; adds selected + onFieldChanged over upstream display-only'),
  'mcp-server-panel': Entry('ported',
      dart: 'components/mcp_server_panel.dart',
      note: 'server rows with status dots, tools and authorize'),
  'command-palette': Entry('ported',
      dart: 'components/command_palette.dart',
      note: 'filter, grouped order, arrow wrap, enter to run'),
  'mcp-config': Entry('ported',
      dart: 'components/mcp_config.dart',
      note: 'editor (connectors, custom servers, add form, status, auth control) plus the client half of react-mcp in runtime/mcp_client.dart: initialize, tools/list with cursors, tools/call, resources, a merged toolkit per server and per-server failures; http/sse transports, stdio needs a local process'),
  'chart': Entry('ported',
      dart: 'components/chart.dart',
      note: 'area / line / bars variants over one x-scale; CustomPaint instead of SVG'),
  'comparison-card': Entry('ported',
      dart: 'components/comparison_card.dart',
      note: 'option columns, pick mark, trait checks and dashes'),
  'connection-state': Entry('ported',
      dart: 'components/connection_state.dart',
      note: 'online renders nothing; dropped / reconnecting / resumed'),
  'data-table': Entry('ported',
      dart: 'components/data_table.dart',
      note: 'model / context / cost columns with the initial glyph'),
  'flow-graph': Entry('ported',
      dart: 'components/flow_graph.dart',
      note: 'grid columns and rows, bezier edges; pending nodes lose the dashed border'),
  'number-ticker': Entry('ported',
      dart: 'components/number_ticker.dart',
      note: 'rolling digits on change, grouped figure'),
  'recommendation-card': Entry('ported',
      dart: 'components/recommendation_card.dart',
      note: 'confidence bars, accept / alternatives, accepted state'),
  'spec-sheet': Entry('ported',
      dart: 'components/spec_sheet.dart',
      note: 'labelled rows with an emphasised value column'),
  'timeline': Entry('ported',
      dart: 'components/timeline.dart',
      note: 'rail with past / now / future dots and the now ring'),
  'todo-list': Entry('ported',
      dart: 'components/todo_list.dart',
      note: 'four states with strikethrough and a failure reason'),
  'artifact-card': Entry('ported',
      dart: 'components/artifact_card.dart',
      note: 'live word count while generating, meta when settled, hover arrow'),
  'file-tree': Entry('ported',
      dart: 'components/file_tree.dart',
      note: 'folder / file rows with per-file diff counts and a total'),
  'sources': Entry('ported',
      dart: 'components/sources.dart',
      note: 'collapsible pill with the domain / title cards'),
  'conversation-search': Entry('ported',
      dart: 'components/conversation_search.dart',
      note: 'query field, hit counter, stepping, matched excerpt and the position rail'),
  'thread-search': Entry('ported',
      dart: 'components/thread_search.dart',
      note: 'pinned first then groups, arrow-key stepping'),
  'diagram': Entry('ported',
      dart: 'components/diagram.dart',
      note: 'zoom in/out/reset/expand over a host figure'),
  'document-reference': Entry('ported',
      dart: 'components/document_reference.dart',
      note: 'page anchors with quotes, active page highlighted'),
  'inline-citation': Entry('ported',
      dart: 'components/inline_citation.dart',
      note: 'numbered chips with a floating source preview; segments replace upstream\'s hardcoded sentence'),
  'retrieval-chunks': Entry('ported',
      dart: 'components/retrieval_chunks.dart',
      note: 'query pill, passage cards with locator, score and the relevance bar'),
  'research-report': Entry('ported',
      dart: 'components/research_report.dart',
      note: 'section states, per-section source counts and previews'),
  'speaker-identity': Entry('ported',
      dart: 'components/speaker_identity.dart',
      note: 'per-turn speaker badges tinted by kind'),
  'web-search': Entry('ported',
      dart: 'components/web_search.dart',
      note: 'query pill, result rows; the read count follows the list instead of upstream\'s fixed string'),
  'map-answer': Entry('ported',
      dart: 'components/map_answer.dart',
      note: 'grid map, pins, hand-dashed route and the pin list'),
  'image-generation': Entry('ported',
      dart: 'components/image_generation.dart',
      note: 'pulsing dot field then the gradient reveal; OKLCH gradients converted to sRGB'),
  'surfaces': Entry('ported',
      dart: 'components/surfaces.dart',
      note: 'the shared paper / field / mono / pill helpers'),
  'thinking-indicator': Entry('ported',
      dart: 'components/indicators.dart',
      note: 'AssistantThinkingIndicator'),
  'reasoning-panel': Entry('ported',
      dart: 'components/reasoning_panel.dart',
      note: 'collapsible steps with a pulsing active dot and the thinking label'),
  'reasoning-effort': Entry('ported',
      dart: 'components/reasoning_effort.dart',
      note: 'segmented levels with the budget spent'),
  'read-aloud': Entry('ported',
      dart: 'components/read_aloud.dart',
      note: 'word-by-word highlight with transport, progress and rate'),
  'quota-banner': Entry('ported',
      dart: 'components/quota_banner.dart',
      note: 'what is left, amber from 90%, upgrade action'),
  'settings-panel': Entry('ported',
      dart: 'components/settings_panel.dart',
      note: 'model segments, system prompt, temperature slider and the feature switches'),
  'prompt-library': Entry('ported',
      dart: 'components/prompt_library.dart',
      note: 'searchable saved prompts with a preview, variable chips and enter-to-insert'),
  'onboarding': Entry('ported',
      dart: 'components/onboarding.dart',
      note: 'stepped tour with progress dots, example box and skip / next'),
  'logos': Entry('ported',
      dart: 'components/logos.dart',
      note: 'vendor marks drawn from the upstream path data; the arc-based OpenAI mark falls back to a wordmark'),
  'launcher-bubble': Entry('ported',
      dart: 'components/launcher_bubble.dart',
      note: 'open/closed bubble with unread badge, prompts and start action'),
  'chat-panel': Entry('ported',
      dart: 'components/chat_panel.dart',
      note: 'compact panel with messages, typing row and composer'),
  'flow': Entry('ported',
      dart: 'components/flow.dart',
      note: 'root frame, rows / columns, dashed groups, box and decision nodes with tones, labelled arrows'),
  'flow-expand': Entry('ported',
      dart: 'components/flow_expand.dart',
      note: 'hover expand control and the full-screen zoom viewer shared with the Mermaid element'),
  'conversation-map': Entry('ported',
      dart: 'components/conversation_map.dart',
      note: 'rail of ticks per turn with previews, arrow-key stepping and the active mark'),
  'threadlist-sidebar': Entry('ported',
      dart: 'components/threadlist_sidebar.dart',
      note: 'product header, the thread list and the source link'),
  'follow-up-suggestions': Entry('ported',
      dart: 'components/follow_up_suggestions.dart',
      note: 'chips read from ThreadState.suggestions, edge fades, tap sends the prompt'),
  'guardrail-notice': Entry('ported',
      dart: 'components/guardrail_notice.dart',
      note: 'policy id, explanation and the alternatives to try'),
  'quote-reply': Entry('ported',
      dart: 'components/quote_reply.dart',
      note: 'highlighted selection with the action toolbar and the quoted reply'),
  'message-attachment': Entry('ported',
      dart: 'components/message_attachment.dart',
      note: 'image and document rows; the runtime wrapper renders through the same list'),
  'permission-grant': Entry('ported',
      dart: 'components/permission_grant.dart',
      note: 'capability, reach list, deny / session / always while pending, then the settled scope'),
  'code-diff': Entry('ported',
      dart: 'components/code_diff.dart',
      note: 'unified diff with gutter marks, tints and the +/- counts'),
  'terminal-block': Entry('ported',
      dart: 'components/terminal_block.dart',
      note: 'streaming command output with the exit state and caret'),
  'code-runner': Entry('ported',
      dart: 'components/code_runner.dart',
      note: 'run control, duration, output panel; takes a highlighter override'),
  'quote': Entry('ported',
      dart: 'components/quote.dart',
      note: 'quote block, selection toolbar and the composer preview, plus QuotePart in the runtime model so a quoted passage travels as a message part and renders in the bubble'),
  'reviewable-diff': Entry('ported',
      dart: 'components/reviewable_diff.dart',
      note: 'hunks kept or discarded one by one, apply gated on the review'),
  'assistant-modal': Entry('ported',
      dart: 'components/assistant_modal.dart',
      note: 'corner bubble, resizable panel with thread / list views, keyboard nudge and reset; the size is reported to the host instead of localStorage'),
  'model-selector': Entry('ported',
      dart: 'components/model_selector.dart',
      note: 'trigger variants and sizes, search over id / name / keywords, disabled rows, reasoning effort with sticky resolution; the compound maps to one widget'),
  'empty-state': Entry('ported',
      dart: 'components/empty_state.dart',
      note: 'greeting, prompt pills and the stand-in composer'),
  'error-state': Entry('ported',
      dart: 'components/error_state.dart',
      note: 'red card with the retry, or the shimmering retrying line'),
  'suggestions': Entry('ported',
      dart: 'components/suggestions.dart',
      note: 'pills or list, selected pill inverted'),
  'day-separator': Entry('ported',
      dart: 'components/day_separator.dart',
      note: 'rules the day changes, times on hover'),
  'streaming-text': Entry('ported',
      dart: 'components/streaming_text.dart',
      note: 'word reveal where each word fades in over 500ms, its fresh tint '
          'settles over 700ms and a pulsing caret trails the stream'),
  'shared-conversation': Entry('ported',
      dart: 'components/shared_conversation.dart',
      note: 'read-only turns with continue-in-your-own-chat'),
  'regenerate-menu': Entry('ported',
      dart: 'components/regenerate_menu.dart',
      note: 'model list with the current one marked'),
  'edit-message': Entry('ported',
      dart: 'components/composer.dart',
      note: 'edit in place, truncate and rerun, plus the discard notice'),
  'feedback-dialog': Entry('ported',
      dart: 'components/feedback_dialog.dart',
      note: 'reason chips, note field, send, then the live-region acknowledgement'),
  'stopped-run': Entry('ported',
      dart: 'components/action_bar.dart',
      note: 'a cancelled run keeps its content and offers Continue, which starts a run from that message'),
  'scroll-anchor': Entry('ported',
      dart: 'primitives/thread.dart',
      note: 'the viewport floats a jump-to-latest pill while unpinned'),
  'image': Entry('ported',
      dart: 'components/image.dart',
      note: 'loading/ready/failed/blocked frame with hover controls and zoom; download/copy call host callbacks since Dart has no image clipboard'),
  'file': Entry('partial', dart: 'components/parts.dart',
      note: 'chip carries the mime icon set, a type label, the payload size when the part carries base64 bytes, and a download hook the host wires'),
  'web-preview': Entry('partial',
      dart: 'components/web_preview.dart, components/web_preview_frame.dart',
      note: 'the chrome is ported (origin bar, reload, open-in-new, loading state, '
          'and it enforces no isolation, matching the element); the frame itself is '
          'a platform surface: an iframe registered as a platform view on web, '
          'null elsewhere so the host passes its own'),
  'shiki-highlighter': Entry('ported',
      dart: 'components/syntax_highlighter.dart',
      note: 'the Shiki-based variant of the highlighter element; this port '
          'tokenizes with Dart regexes and paints the same coldark palettes'),

  'mermaid-diagram': Entry('ported',
      dart: 'components/mermaid_diagram.dart, components/mermaid_renderer.dart, '
          'components/mermaid_extra.dart',
      note: 'frame (skeleton, code fallback, shared zoom surface) plus built-in '
          'renderers: graph/flowchart in TD/TB/BT/LR with node shapes, chains and '
          'labelled edges; pie with the palette and a legend; sequence with '
          'lifelines, arrows, self-messages and notes. All parsed and painted in '
          'Dart, so a fence renders with no host engine; class, state and gantt '
          'still fall back to the source, and a host drawing overrides the '
          'built-in one'),
  'math-block': Entry('ported',
      dart: 'components/math_block.dart',
      note: 'revealed derivation steps plus Frac / Sup / Sub helpers, and display math in markdown falls back to the styled TeX source when the host has no typesetter'),
  'generative-ui': Entry('ported',
      dart: 'components/generative_ui.dart',
      note: 'component registry with the styled Markdown entry; the library comes from the host, as upstream'),
};

/// Families that map to a wave but have no per-element notes yet.
String _waveFor(String name) {
  const List<String> composer = <String>[
    'composer', 'mention', 'slash', 'voice', 'dictation', 'model', 'context',
    'trigger', 'quote', 'mobile', 'queue', 'draft', 'elicitation',
  ];
  const List<String> tools = <String>[
    'tool', 'approval', 'mcp', 'permission', 'guardrail', 'code-runner',
    'code-diff', 'reviewable', 'terminal', 'command-palette',
  ];
  const List<String> agent = <String>[
    'agent', 'plan', 'handoff', 'subagent', 'task', 'job', 'schedule',
    'checkpoint', 'background', 'canvas', 'computer-use', 'memory',
  ];
  const List<String> observe = <String>[
    'trace', 'cost', 'context-breakdown', 'activity', 'heat', 'confidence',
    'score', 'comparison', 'recommendation', 'connection', 'number-ticker',
    'spec-sheet', 'data-table', 'chart', 'flow-graph', 'timeline', 'todo',
  ];
  const List<String> content = <String>[
    'image', 'file', 'document', 'source', 'citation', 'chart', 'diagram',
    'mermaid', 'math', 'artifact', 'research', 'retrieval', 'search',
    'map-answer', 'generative', 'speaker', 'directive',
  ];
  for (final String key in composer) {
    if (name.contains(key)) return 'D';
  }
  for (final String key in tools) {
    if (name.contains(key)) return 'E';
  }
  for (final String key in agent) {
    if (name.contains(key)) return 'F';
  }
  for (final String key in observe) {
    if (name.contains(key)) return 'G';
  }
  for (final String key in content) {
    if (name.contains(key)) return 'H';
  }
  return 'I';
}

void main() {
  final File inventory = File('doc/official_elements.txt');
  if (!inventory.existsSync()) {
    stderr.writeln('doc/official_elements.txt is missing');
    exit(1);
  }
  final List<String> raw = inventory
      .readAsLinesSync()
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .toList();
  // `x.aui` is the installable form of `x`; count it once, under the base name.
  final Set<String> names = raw
      .map((String name) => name.endsWith('.aui') ? name.substring(0, name.length - 4) : name)
      .toSet();

  final Map<String, int> counts = <String, int>{};
  final List<(String, Entry)> rows = <(String, Entry)>[];

  for (final String name in names) {
    final Entry? explicit = _entries[name];
    final Entry entry = explicit ??
        Entry('planned', wave: _waveFor(name));
    counts[entry.status] = (counts[entry.status] ?? 0) + 1;
    rows.add((name, entry));
  }

  final StringBuffer out = StringBuffer()
    ..writeln('# Element coverage')
    ..writeln()
    ..writeln('Generated by `dart run tool/sync_element_coverage.dart` — do not edit by hand.')
    ..writeln()
    ..writeln('| Element | Status | Wave | Flutter | Note |')
    ..writeln('|---|---|---|---|---|');
  for (final (String name, Entry entry) in rows) {
    out.writeln('| `$name` | ${entry.status} | ${entry.wave ?? '—'} | '
        '${entry.dart == null ? '—' : '`${entry.dart}`'} | ${entry.note ?? ''} |');
  }
  out
    ..writeln()
    ..writeln('## Totals')
    ..writeln()
    ..writeln('| Status | Count |')
    ..writeln('|---|---|');
  for (final String status in <String>['ported', 'partial', 'planned', 'n/a']) {
    out.writeln('| $status | ${counts[status] ?? 0} |');
  }
  out.writeln('| **total** | **${names.length}** |');

  File('doc/element-coverage.md').writeAsStringSync(out.toString());
  stdout.writeln('wrote doc/element-coverage.md (${names.length} elements)');
}
