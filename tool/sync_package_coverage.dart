// Generates doc/package-coverage.md from the official package inventory.
//
// The inventory (doc/official_packages.txt) is a snapshot of `packages/` in
// the upstream repo. Status lives here, next to the report it produces, so the
// two cannot drift:
//
//   dart run tool/sync_package_coverage.dart
//
// Refresh the inventory with:
//
//   curl -s "https://api.github.com/repos/assistant-ui/assistant-ui/contents/\
//   packages" | jq -r '.[] | select(.type=="dir") | .name' | sort \
//     > doc/official_packages.txt
import 'dart:io';

/// status per package: ported | partial | n/a
class Entry {
  const Entry(this.status, {this.dart, this.note});

  final String status;
  final String? dart;
  final String? note;
}

const Map<String, Entry> _entries = <String, Entry>{
  // --- runtime and protocol -------------------------------------------------
  'core': Entry('ported',
      dart: 'core/, runtime/local_runtime.dart',
      note: 'messages, branches, parts, adapters, runtime API; the store and tap '
          'responsibilities live in LocalRuntime, which is the port of useLocalRuntime'),
  'store': Entry('ported',
      dart: 'runtime/local_runtime.dart, primitives/state.dart',
      note: 'thread/threads/composer state with the same slices the React store exposes'),
  'tap': Entry('ported',
      dart: 'runtime/local_runtime.dart',
      note: 'run lifecycle, abort, queue and tool execution'),
  'assistant-stream': Entry('ported',
      dart: 'protocol/data_stream.dart, protocol/data_stream_adapter.dart',
      note: 'data stream v1 frames, CRLF-aware and SSE-wrapped, plus the aui-* extensions'),
  'cloud': Entry('ported',
      dart: 'runtime/cloud.dart',
      note: 'threads CRUD and thread messages with a token callback; the realtime '
          'event stream and files endpoints are not ported'),
  // --- model and framework adapters ----------------------------------------
  'ai-sdk': Entry('ported',
      dart: 'protocol/data_stream_adapter.dart',
      note: 'the AI SDK UI message stream is the data stream the adapter reads'),
  'react-data-stream': Entry('ported', dart: 'protocol/data_stream_adapter.dart'),
  'react-ai-sdk': Entry('ported', dart: 'protocol/data_stream_adapter.dart'),
  'react-langgraph': Entry('ported',
      dart: 'runtime/langgraph.dart',
      note: 'threads, run streaming, message accumulator and conversions'),
  'react-langchain': Entry('ported',
      dart: 'runtime/langgraph.dart',
      note: 'the assistant-id flavour of the same platform API is the LangGraph client'),
  'react-ag-ui': Entry('ported',
      dart: 'runtime/ag_ui.dart',
      note: 'event parser, SSE agent and the adapter; the React-side queue and '
          'thread-switch orchestration maps onto the Dart runtime'),
  'react-a2a': Entry('ported',
      dart: 'runtime/a2a.dart',
      note: 'client, wire types and conversions; push-notification configs and the '
          'extended agent card are not ported'),
  'react-google-adk': Entry('ported',
      dart: 'runtime/adk.dart',
      note: 'client, accumulator and conversions; tool confirmations (gated call '
          'id, decision projection, the reply that resumes), auth requests, agent '
          'transfer and escalation, state/artifact deltas and long-running tool ids'),
  'react-mcp': Entry('ported',
      dart: 'runtime/mcp_client.dart',
      note: 'client half (initialize, tools, call, toolkit); the panel is '
          'components/mcp_config.dart. stdio needs a local process, so http/sse'),
  'react-generative-ui': Entry('ported',
      dart: 'runtime/generative_ui.dart',
      note: 'the IR, the view-source serializer and the host vocabulary; the '
          'standard component set is smaller than upstream\'s full catalogue'),
  // --- UI --------------------------------------------------------------------
  'react': Entry('ported',
      dart: 'primitives/, components/',
      note: 'the React package scope is this port whole surface: provider, '
          'primitives, hooks and the styled components'),
  'ui': Entry('ported',
      dart: 'components/, primitives/',
      note: '119 of 125 elements ported, 4 partial, 2 n/a — see doc/element-coverage.md'),
  'tw-shimmer': Entry('ported',
      dart: 'components/shimmer.dart',
      note: 'the effect with the CSS utility parameters (angle, speed, spread, '
          'track, repeat delay)'),
  'heat-graph': Entry('ported', dart: 'components/heat_graph.dart'),
  'react-o11y': Entry('ported',
      dart: 'runtime/span_tree.dart, components/span_primitives.dart',
      note: 'the span resource (parents resolved, depths cached, cycles broken, '
          'collapse, visible rows, time window) and the primitive family (name, '
          'type badge, status, collapse toggle, indent, children, timeline bar); '
          'an OTel exporter is a host concern, so spans arrive as SpanData'),
  'react-devtools': Entry('n/a',
      note: 'browser devtools extension; Flutter has the inspector instead'),
  'react-hook-form': Entry('n/a', note: 'React form binding; host concern in Flutter'),
  'react-lexical': Entry('n/a', note: 'Lexical rich-text editor; Flutter has its own editing stack'),
  'react-markdown': Entry('ported',
      dart: 'components/markdown.dart',
      note: 'the block and inline grammar, with fenced code through the syntax highlighter'),
  'react-streamdown': Entry('n/a', note: 'React streaming markdown renderer; superseded by components/markdown.dart'),
  'react-syntax-highlighter': Entry('ported',
      dart: 'components/syntax_highlighter.dart',
      note: 'the coldark palettes and the tokenizer'),
  'react-native': Entry('partial',
      dart: 'components/',
      note: 'the RN element set was used as the layout reference for the Flutter '
          'widgets rather than ported file by file'),
  'react-ink': Entry('n/a', note: 'terminal renderer for React; Flutter ships no terminal target'),
  'react-ink-markdown': Entry('n/a', note: 'markdown for react-ink; same reason'),
  'react-opencode': Entry('n/a', note: 'code-editor integration for React'),
  'react-pi': Entry('n/a', note: 'React package for the pi runtime; no Dart counterpart yet'),
  'safe-content-frame': Entry('n/a',
      note: 'sandboxed iframe embed; Flutter has no equivalent surface'),
  'agent-launcher': Entry('ported',
      dart: 'components/launcher_bubble.dart',
      note: 'the launcher surface; the package\'s build wiring is React-specific'),
  'eve': Entry('n/a', note: 'upstream internal app package'),
  // --- apps, tooling and other frameworks -----------------------------------
  'cli': Entry('n/a',
      note: 'copies React UI source into an app; a Flutter port would ship widgets, '
          'not generated source'),
  'create-assistant-ui': Entry('n/a', note: 'scaffolder for React apps'),
  'mcp-docs-server': Entry('n/a', note: 'docs server for MCP clients'),
  'metro': Entry('n/a', note: 'React Native bundler config'),
  'next': Entry('n/a', note: 'Next.js plugin'),
  'vite': Entry('n/a', note: 'Vite plugin'),
  'x-buildutils': Entry('n/a', note: 'build tooling'),
  'x-changelog': Entry('n/a', note: 'release tooling'),
  'x-generative-compiler': Entry('n/a', note: 'compiler tooling for the React renderer'),
  'x-performance': Entry('n/a', note: 'React performance harness'),
  'svelte': Entry('n/a', note: 'another framework binding'),
  'vue': Entry('n/a', note: 'another framework binding'),
};

void main() {
  final File inventory = File('doc/official_packages.txt');
  if (!inventory.existsSync()) {
    stderr.writeln('Missing ${inventory.path}');
    exit(1);
  }
  final List<String> packages = inventory
      .readAsLinesSync()
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .toList();

  final List<String> missing =
      packages.where((String p) => !_entries.containsKey(p)).toList();
  final List<String> extra =
      _entries.keys.where((String p) => !packages.contains(p)).toList();
  if (missing.isNotEmpty || extra.isNotEmpty) {
    stderr.writeln('Inventory drift: missing=$missing extra=$extra');
    exit(1);
  }

  final StringBuffer out = StringBuffer()
    ..writeln('# Package coverage')
    ..writeln()
    ..writeln('Generated by `dart run tool/sync_package_coverage.dart` — do not '
        'edit by hand.')
    ..writeln()
    ..writeln('| Package | Status | Flutter | Note |')
    ..writeln('|---|---|---|---|');

  for (final String name in packages) {
    final Entry entry = _entries[name]!;
    final String? dartPath = entry.dart;
    final String dartColumn = dartPath == null ? '—' : '`$dartPath`';
    final String note = entry.note ?? '';
    final String status = entry.status;
    out.writeln('| `$name` | $status | $dartColumn | $note |');
  }

  final Map<String, int> counts = <String, int>{};
  for (final Entry entry in _entries.values) {
    counts[entry.status] = (counts[entry.status] ?? 0) + 1;
  }
  final List<String> order = <String>['ported', 'partial', 'n/a'];
  out
    ..writeln()
    ..writeln('## Totals')
    ..writeln()
    ..writeln('| Status | Count |')
    ..writeln('|---|---|');
  for (final String status in order) {
    out.writeln('| $status | ${counts[status] ?? 0} |');
  }
  out.writeln('| **total** | **${_entries.length}** |');

  File('doc/package-coverage.md').writeAsStringSync(out.toString());
  stdout.writeln('wrote doc/package-coverage.md (${packages.length} packages)');
}
