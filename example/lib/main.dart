import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

/// Demo app for `assistant_ui`.
///
/// Runs entirely offline: the adapter scripts a streaming answer so the
/// primitives, the runtime and the styled components can be exercised without
/// a backend. Swap [DemoChatModelAdapter] for [DataStreamChatModelAdapter] to
/// talk to a real endpoint.
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  /// `?theme=dark` deep-links straight into the dark palette.
  ThemeMode _mode = Uri.base.queryParameters['theme'] == 'dark'
      ? ThemeMode.dark
      : ThemeMode.light;

  /// `?page=chatgpt|claude|gemini|grok` deep-links into a vendor clone.
  String _page = Uri.base.queryParameters['page'] ?? 'default';

  /// `?shell=1` wraps the conversation in the sidebar shell.
  bool _shell = Uri.base.queryParameters['shell'] == '1';
  int _session = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'assistant_ui',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: AssistantTheme.light.background,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AssistantTheme.dark.background,
      ),
      themeMode: _mode,
      home: Builder(
        builder: (BuildContext context) {
          final bool isDark =
              Theme.of(context).brightness == Brightness.dark;
          final AssistantTheme theme =
              isDark ? AssistantTheme.dark : AssistantTheme.light;
          return AssistantThemeProvider(
            theme: theme,
            child: Scaffold(
              backgroundColor: theme.background,
              appBar: AppBar(
                backgroundColor: theme.background,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  'assistant_ui',
                  style: theme.body(context).copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                actions: <Widget>[
                  PopupMenuButton<String>(
                    tooltip: 'Clone',
                    initialValue: _page,
                    onSelected: (String page) => setState(() => _page = page),
                    itemBuilder: (BuildContext context) =>
                        const <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(value: 'default', child: Text('Default')),
                      PopupMenuItem<String>(value: 'chatgpt', child: Text('ChatGPT')),
                      PopupMenuItem<String>(value: 'claude', child: Text('Claude')),
                      PopupMenuItem<String>(value: 'gemini', child: Text('Gemini')),
                      PopupMenuItem<String>(value: 'grok', child: Text('Grok')),
                      PopupMenuItem<String>(
                        value: 'composer',
                        child: Text('Composer triggers'),
                      ),
                      PopupMenuItem<String>(
                        value: 'states',
                        child: Text('States and indicators'),
                      ),
                      PopupMenuItem<String>(value: 'tools', child: Text('Tools')),
                      PopupMenuItem<String>(value: 'agents', child: Text('Agents')),
                      PopupMenuItem<String>(
                        value: 'observability',
                        child: Text('Observability'),
                      ),
                      PopupMenuItem<String>(value: 'motion', child: Text('Motion')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.dashboard_customize_outlined,
                              size: 18, color: theme.mutedForeground),
                          const SizedBox(width: 6),
                          Text(
                            _page == 'default' ? 'Default' : _page,
                            style: theme.small(context).copyWith(
                              color: theme.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _shell ? 'Hide chat history' : 'Show chat history',
                    icon: Icon(
                      Icons.view_sidebar_outlined,
                      color: _shell ? theme.foreground : theme.mutedForeground,
                    ),
                    onPressed: () => setState(() => _shell = !_shell),
                  ),
                  IconButton(
                    tooltip: 'New chat',
                    icon: Icon(Icons.add_comment_outlined,
                        color: theme.mutedForeground),
                    onPressed: () => setState(() => _session++),
                  ),
                  IconButton(
                    tooltip: isDark ? 'Light theme' : 'Dark theme',
                    icon: Icon(
                      isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                      color: theme.mutedForeground,
                    ),
                    onPressed: () => setState(() {
                      _mode = isDark ? ThemeMode.light : ThemeMode.dark;
                    }),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              body: SafeArea(
                child: ChatSession(
                  key: ValueKey<int>(_session),
                  page: _page,
                  shell: _shell,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// One conversation. Recreated by "New chat", which rebuilds the runtime with
/// fresh state.
class ChatSession extends StatefulWidget {
  const ChatSession({super.key, this.page = 'default', this.shell = false});

  final String page;
  final bool shell;

  @override
  State<ChatSession> createState() => _ChatSessionState();
}

class _ChatSessionState extends State<ChatSession> {
  late final LocalRuntime _runtime = LocalRuntime(
    adapter: DemoChatModelAdapter(),
    options: LocalRuntimeOptions(
      systemPrompt: 'You are a helpful assistant running inside a Flutter app.',
      maxSteps: 3,
      // A small window so the composer ring is visibly filled in the demo.
      contextWindowTokens: 4000,
      dictation: _DemoDictationAdapter(),
      tools: <String, ToolDefinition>{
        'get_weather': ToolDefinition(
          description: 'Get the current weather for a city',
          parameters: <String, Object?>{
            'type': 'object',
            'properties': <String, Object?>{
              'city': <String, Object?>{'type': 'string'},
            },
            'required': <Object?>['city'],
          },
          execute: (Map<String, Object?> args) async {
            await Future<void>.delayed(const Duration(milliseconds: 700));
            final String city = (args['city'] as String?) ?? 'unknown';
            return <String, Object?>{
              'city': city,
              'temperature': 21,
              'conditions': 'partly cloudy',
            };
          },
          renderText: const ToolRenderText(
            running: 'Checking the weather…',
            complete: 'Weather ready',
          ),
        ),
      },
    ),
  );

  @override
  void dispose() {
    _runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuiRuntimeProvider(
        runtime: _runtime,
        child: widget.shell
            ? AssistantShell(child: _ThreadHost(page: widget.page))
            : _ThreadHost(page: widget.page),
      );
}

/// Picks the presentation: the default thread, or one of the vendor clones.
///
/// The clones are pure presentation over the same runtime, so switching pages
/// keeps the conversation.
class _ThreadHost extends StatelessWidget {
  const _ThreadHost({required this.page});

  final String page;

  @override
  Widget build(BuildContext context) {
    switch (page) {
      case 'chatgpt':
        return ChatGptClone(onPickAttachments: _demoPickAttachments);
      case 'claude':
        return ClaudeClone(onPickAttachments: _demoPickAttachments);
      case 'gemini':
        return GeminiClone(onPickAttachments: _demoPickAttachments);
      case 'grok':
        return GrokClone(onPickAttachments: _demoPickAttachments);
      case 'composer':
        return const _ComposerDemo();
      case 'tools':
        return const _ToolFamilyDemo();
      case 'agents':
        return const _AgentFamilyDemo();
      case 'observability':
        return const _ObservabilityDemo();
      case 'motion':
        return const _MotionDemo();
      case 'states':
        return const _StatesDemo();
      default:
        return const AssistantThread(
          turnAnchor: AuiTurnAnchor.top,
          composerPlaceholder: 'Ask about the weather, or anything else…',
          emptyState: _EmptyState(),
          groupToolCalls: true,
        );
    }
  }
}

/// Stands in for a platform file picker: hands back one small text file so the
/// attachment path (upload -> chip -> message card) is exercised end to end.
Future<List<PendingAttachment>> _demoPickAttachments(BuildContext context) async {
  return <PendingAttachment>[
    PendingAttachment(
      id: 'demo_${DateTime.now().microsecondsSinceEpoch}',
      filename: 'notes.txt',
      mimeType: 'text/plain',
      data: Uint8List.fromList(utf8.encode('Release notes draft.')),
    ),
  ];
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: <Widget>[
          Text(
            'How can I help you today?',
            textAlign: TextAlign.center,
            style: theme.body(context)
                .copyWith(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            'Try “what is the weather in Tokyo?” to see a tool call,\n'
            'or anything else to see markdown streaming.',
            textAlign: TextAlign.center,
            style: theme.small(context),
          ),
        ],
      ),
    );
  }
}

/// Scripted streaming model. Every run yields cumulative content, the same
/// contract a real backend adapter follows.
class DemoChatModelAdapter extends ChatModelAdapter {
  @override
  Stream<ChatModelRunResult> run(ChatModelRunContext context) async* {
    // On a continuation the last message is the assistant one, so the prompt
    // has to come from the last user message.
    final List<ThreadMessage> prompts = context.messages
        .where((ThreadMessage m) => m.isUser)
        .toList(growable: false);
    final String prompt = prompts.isEmpty ? '' : prompts.last.text.toLowerCase();
    final bool wantsWeather =
        prompt.contains('weather') || prompt.contains('temperature');

    if (wantsWeather) {
      // The runtime calls the adapter again once the tool result is attached,
      // so the answer streams in a second step of the same message.
      final List<ToolCallPart> resolved = context
          .getMessage()
          .content
          .whereType<ToolCallPart>()
          .where((ToolCallPart part) =>
              part.toolName == 'get_weather' && part.hasResult)
          .toList(growable: false);

      if (resolved.isEmpty) {
        final String city = _cityFrom(prompt);
        yield* _streamParts(<MessagePart>[
          ReasoningPart(
            'The user asked about the weather in $city. I should call the '
            'get_weather tool and then summarize the result.',
          ),
          const TextPart('Let me check that for you.'),
          ToolCallPart(
            toolCallId: 'call_${DateTime.now().millisecondsSinceEpoch}',
            toolName: 'get_weather',
            args: <String, Object?>{'city': city},
          ),
        ]);
        return;
      }

      final Object? result = resolved.last.result;
      final Map<String, Object?> data =
          result is Map ? result.cast<String, Object?>() : <String, Object?>{};

      yield* _streamText(
        'It is **${data['temperature']}°C** and ${data['conditions']} in '
        '${data['city']} right now.\n\n'
        '```json\n${_pretty(data)}\n```',
      );
      return;
    }

    yield* _streamParts(<MessagePart>[
      const ReasoningPart(
        'The user asked a general question. A short markdown answer with a '
        'list and a code block shows the renderer.',
      ),
      const TextPart('Here is what this port covers:'),
    ]);

    yield* _streamText(
      '\n\n- **Primitives** — thread, message, composer, action bar, branch '
      'picker\n'
      '- **Runtime** — streaming, cancel, regenerate, edit, branches\n'
      '- **Protocol** — the Vercel data stream, so existing backends work\n\n'
      'A quick check of the markdown renderer:\n\n'
      '```dart\n'
      "final runtime = LocalRuntime(adapter: MyAdapter());\n"
      'AuiRuntimeProvider(runtime: runtime, child: const AssistantThread());\n'
      '```\n\n'
      'Ask about the weather to see a tool call round trip.',
    );
  }

  /// Streams a fixed part list in a few steps so the UI shows parts appearing
  /// one after another.
  Stream<ChatModelRunResult> _streamParts(List<MessagePart> parts) async* {
    for (int i = 1; i <= parts.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      yield ChatModelRunResult(content: parts.sublist(0, i));
    }
  }

  /// Streams text word by word, keeping the parts already produced.
  Stream<ChatModelRunResult> _streamText(String text) async* {
    final List<String> tokens = _tokenize(text);
    final StringBuffer buffer = StringBuffer();
    for (final String token in tokens) {
      buffer.write(token);
      await Future<void>.delayed(const Duration(milliseconds: 18));
      yield ChatModelRunResult(
        content: <MessagePart>[
          TextPart(buffer.toString()),
        ],
      );
    }
  }

  static List<String> _tokenize(String text) {
    final RegExp pattern = RegExp(r'\s+|\S+');
    return pattern.allMatches(text).map((RegExpMatch m) => m.group(0)!).toList();
  }

  static String _cityFrom(String prompt) {
    final RegExpMatch? match = RegExp(
      r'\b(?:in|for|at)\s+([a-zA-Z\u4e00-\u9fa5]+(?:\s+[a-zA-Z\u4e00-\u9fa5]+)?)',
    ).firstMatch(prompt);
    final String raw = match?.group(1)?.trim() ?? 'San Francisco';
    if (raw.isEmpty) return 'San Francisco';
    return raw
        .split(RegExp(r'\s+'))
        .map((String word) => word.isEmpty
            ? word
            : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  static String _pretty(Map<String, Object?> data) =>
      '{\n${data.entries.map((MapEntry<String, Object?> e) => '  "${e.key}": ${e.value is String ? '"${e.value}"' : e.value}').join(',\n')}\n}';
}


/// Demo page for the composer family: mentions and slash commands on top of
/// the default thread.
class _ComposerDemo extends StatefulWidget {
  const _ComposerDemo();

  @override
  State<_ComposerDemo> createState() => _ComposerDemoState();
}

class _ComposerDemoState extends State<_ComposerDemo> {
  static const List<AssistantMention> _people = <AssistantMention>[
    AssistantMention(id: 'ann', name: 'Ann Lee', description: 'Design'),
    AssistantMention(id: 'bob', name: 'Bob Ray', description: 'Platform'),
    AssistantMention(id: 'ana', name: 'Ana Diaz', description: 'Research'),
  ];

  static const List<String> _commands = <String>[
    'summarize',
    'translate',
    'explain',
    'diagram',
  ];

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Column(
      children: <Widget>[
        Expanded(
          child: AuiThreadViewport(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    AuiIf(
                      condition: (AuiState state) => state.thread.isEmpty,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Column(
                          children: <Widget>[
                            Text(
                              'Mentions and slash commands',
                              style: theme.body(context).copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Type @ to mention someone, / to run a command, '
                              '↑↓ to move, Enter to pick.',
                              textAlign: TextAlign.center,
                              style: theme.small(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AuiThreadMessages(
                      builder: (
                        BuildContext context,
                        ThreadMessage message,
                        bool isLast,
                      ) =>
                          Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: AuiMessage(
                          message: message,
                          isLast: isLast,
                          child: message.isUser
                              ? Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 9,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.muted,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: AssistantDirectiveText(
                                      text: message.text,
                                      style: theme.body(context).copyWith(
                                        color: theme.foreground,
                                      ),
                                    ),
                                  ),
                                )
                              : const AssistantMessageParts(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: AuiComposerTriggerRoot(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.background,
                    borderRadius: BorderRadius.circular(theme.composerRadius),
                    border: Border.all(color: theme.border),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      AuiComposerInput(
                        placeholder: 'Type @ to mention, / for commands…',
                        maxLines: 6,
                        autofocus: true,
                        style: theme.body(context),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          const AssistantContextRing(showLabel: true),
                          const SizedBox(width: 10),
                          AssistantMessageQueue(title: '', maxVisible: 2),
                          const Spacer(),
                          const AssistantComposerVoice(),
                          const SizedBox(width: 6),
                          const AssistantPrimaryAction(),
                        ],
                      ),
                      AssistantMentionPopover(people: _people),
                      AssistantSlashCommandMenu(
                        commands: <AssistantSlashCommand>[
                          for (final String name in _commands)
                            AssistantSlashCommand(
                              name: name,
                              label: name[0].toUpperCase() + name.substring(1),
                              description: 'Run the $name command',
                              onRun: () async {
                                AuiRuntimeProvider.of(context)
                                    .composer
                                    .setText('$name: ');
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


/// Simulates a dictation session so the voice UI can be exercised without a
/// microphone plugin; a real app wires its own [DictationAdapter].
class _DemoDictationAdapter implements DictationAdapter {
  @override
  Future<DictationSession> start() async {
    final StreamController<String> transcripts = StreamController<String>();
    final String words = 'summarize the release notes please';
    final List<String> tokens = words.split(' ');
    Timer.periodic(const Duration(milliseconds: 420), (Timer timer) async {
      final int index = timer.tick;
      if (index > tokens.length) {
        await transcripts.close();
        timer.cancel();
        return;
      }
      transcripts.add(tokens.take(index).join(' '));
    });
    return DictationSession(
      transcripts: transcripts.stream,
      stop: () async {
        if (!transcripts.isClosed) await transcripts.close();
      },
    );
  }
}


/// Showcase for the tool family: grouped calls, the run timeline, a failed
/// call, the two human-in-the-loop cards, the MCP server panel and the command
/// palette. Each block owns its own state so every branch is reachable.
class _ToolFamilyDemo extends StatefulWidget {
  const _ToolFamilyDemo();

  @override
  State<_ToolFamilyDemo> createState() => _ToolFamilyDemoState();
}

class _ToolFamilyDemoState extends State<_ToolFamilyDemo> {
  GroupedToolState _groupState = GroupedToolState.running;
  bool _timelineStreaming = true;
  int _timelineVisible = 2;
  bool _retrying = false;
  int _attempt = 2;
  ApprovalState _approval = ApprovalState.request;
  ElicitationState _elicitation = ElicitationState.request;
  final Map<String, String> _answers = <String, String>{
    'scope': 'workspace',
  };
  String? _server;
  McpServerStatus _authStatus = McpServerStatus.needsAuth;
  String _query = '';
  String _activeCommand = 'new-thread';
  String? _ranCommand;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return ColoredBox(
      color: theme.muted,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _caption(theme, 'tool-group — one row per call'),
                AssistantToolGroup(
                  label: '3 tool calls',
                  tools: <GroupedTool>[
                    GroupedTool(
                      id: 'a',
                      name: 'read_file',
                      target: 'lib/main.dart',
                      state: GroupedToolState.done,
                      durationMs: 118,
                    ),
                    GroupedTool(
                      id: 'b',
                      name: 'grep',
                      target: 'runtime',
                      state: GroupedToolState.done,
                      durationMs: 42,
                    ),
                    GroupedTool(
                      id: 'c',
                      name: 'write_file',
                      target: 'lib/theme.dart',
                      state: _groupState,
                      durationMs: _groupState == GroupedToolState.running
                          ? null
                          : 260,
                    ),
                  ],
                  onOpenChange: (_) {},
                  initiallyOpen: true,
                ),
                _row(<Widget>[
                  _action('all done', () {
                    setState(() => _groupState = GroupedToolState.done);
                  }),
                  _action('fail one', () {
                    setState(() => _groupState = GroupedToolState.failed);
                  }),
                  _action('run again', () {
                    setState(() => _groupState = GroupedToolState.running);
                  }),
                ]),
                const SizedBox(height: 22),
                _caption(theme, 'tool-timeline — steps, then the diff'),
                AssistantToolTimeline(
                  steps: const <AssistantTimelineStep>[
                    AssistantTimelineStep(
                      verb: 'Reading',
                      chip: 'lib/main.dart',
                      icon: Icons.description_outlined,
                    ),
                    AssistantTimelineStep(
                      verb: 'Editing',
                      chip: 'lib/theme.dart',
                      icon: Icons.edit_outlined,
                    ),
                    AssistantTimelineStep(
                      verb: 'Running',
                      chip: 'flutter test',
                      icon: Icons.terminal,
                    ),
                  ],
                  visibleSteps: _timelineVisible,
                  streaming: _timelineStreaming,
                  activeLabel: 'Working…',
                  restingLabel: 'Worked for 12s',
                  initiallyOpen: true,
                  stats: _timelineStreaming
                      ? const <AssistantTimelineStat>[]
                      : const <AssistantTimelineStat>[
                          AssistantTimelineStat(
                            file: 'lib/theme.dart',
                            added: 12,
                            removed: 3,
                          ),
                          AssistantTimelineStat(file: 'README.md', added: 4),
                        ],
                  onOpenChange: (_) {},
                ),
                _row(<Widget>[
                  _action('step +1', () {
                    setState(() {
                      _timelineVisible =
                          (_timelineVisible + 1).clamp(1, 3);
                    });
                  }),
                  _action(
                    _timelineStreaming ? 'settle' : 'stream',
                    () => setState(() {
                      _timelineStreaming = !_timelineStreaming;
                      if (!_timelineStreaming) _timelineVisible = 3;
                    }),
                  ),
                ]),
                const SizedBox(height: 22),
                _caption(theme, 'tool-error — retry / skip'),
                AssistantToolError(
                  name: 'write_file',
                  target: 'lib/theme.dart',
                  message: 'EACCES: permission denied, open '
                      "'lib/theme.dart' at Object.writeFileSync",
                  attempt: _attempt,
                  maxAttempts: 3,
                  retrying: _retrying,
                  onRetry: () async {
                    setState(() {
                      _retrying = true;
                      _attempt = (_attempt + 1).clamp(1, 3);
                    });
                    await Future<void>.delayed(
                      const Duration(milliseconds: 1200),
                    );
                    if (mounted) setState(() => _retrying = false);
                  },
                  onSkip: () => setState(() => _attempt = 1),
                ),
                const SizedBox(height: 22),
                _caption(theme, 'approval-card — request → running → done'),
                AssistantApprovalCard(
                  state: _approval,
                  command: 'rm -rf build && flutter build web --release',
                  title: 'Run a command?',
                  subtitle: 'write access to the project folder',
                  onAllowOnce: () => setState(
                    () => _approval = ApprovalState.running,
                  ),
                  onAlwaysAllow: () => setState(
                    () => _approval = ApprovalState.running,
                  ),
                  onDeny: () => setState(
                    () => _approval = ApprovalState.denied,
                  ),
                ),
                _row(<Widget>[
                  _action('request', () {
                    setState(() => _approval = ApprovalState.request);
                  }),
                  _action('finish', () {
                    setState(() => _approval = ApprovalState.done);
                  }),
                  _action('deny', () {
                    setState(() => _approval = ApprovalState.denied);
                  }),
                ]),
                const SizedBox(height: 22),
                _caption(theme, 'elicitation-form — MCP needs input'),
                AssistantElicitationForm(
                  server: 'filesystem',
                  message: 'Grant access to read a folder so the server can '
                      'index your notes.',
                  fields: <ElicitationField>[
                    const ElicitationField(
                      name: 'folder',
                      label: 'folder',
                      value: '/Users/laplace/Desktop/notes',
                      required: true,
                    ),
                    ElicitationField(
                      name: 'scope',
                      label: 'scope',
                      value: _answers['scope'] ?? 'workspace',
                      kind: ElicitationFieldKind.choice,
                      options: const <String>['file', 'workspace', 'machine'],
                    ),
                    ElicitationField(
                      name: 'watch',
                      label: 'watch for changes',
                      value: _answers['watch'] ?? 'false',
                      kind: ElicitationFieldKind.toggle,
                    ),
                  ],
                  selected: _answers,
                  state: _elicitation,
                  onFieldChanged: (String name, String value) {
                    setState(() => _answers[name] = value);
                  },
                  onAccept: () => setState(
                    () => _elicitation = ElicitationState.accepted,
                  ),
                  onDecline: () => setState(
                    () => _elicitation = ElicitationState.declined,
                  ),
                ),
                _row(<Widget>[
                  _action('request', () {
                    setState(() => _elicitation = ElicitationState.request);
                  }),
                  _action('accepted', () {
                    setState(() => _elicitation = ElicitationState.accepted);
                  }),
                ]),
                const SizedBox(height: 22),
                _caption(theme, 'mcp-server-panel — servers and their tools'),
                AssistantMcpServerPanel(
                  servers: <McpServer>[
                    const McpServer(
                      id: 'fs',
                      name: 'filesystem',
                      transport: 'stdio',
                      status: McpServerStatus.connected,
                      tools: <String>['read_file', 'write_file', 'list_dir'],
                    ),
                    McpServer(
                      id: 'ws',
                      name: 'workspace-index',
                      transport: 'http://127.0.0.1:7331/mcp',
                      status: _authStatus,
                      tools: <String>['search_code', 'explain_symbol'],
                    ),
                    const McpServer(
                      id: 'pup',
                      name: 'playwright',
                      transport: 'sse',
                      status: McpServerStatus.failed,
                      tools: <String>['navigate', 'screenshot'],
                    ),
                  ],
                  expandedId: _server,
                  onToggle: (String id) => setState(
                    () => _server = _server == id ? null : id,
                  ),
                  onAuthorize: (String id) async {
                    setState(() => _authStatus = McpServerStatus.connecting);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 1100),
                    );
                    if (mounted) {
                      setState(() => _authStatus = McpServerStatus.connected);
                    }
                  },
                ),
                const SizedBox(height: 22),
                _caption(theme, 'command-palette — filter, arrows, enter'),
                AssistantCommandPalette(
                  commands: const <PaletteCommand>[
                    PaletteCommand(
                      id: 'new-thread',
                      label: 'New thread',
                      group: 'Thread',
                      keys: <String>['⌘', 'N'],
                    ),
                    PaletteCommand(
                      id: 'branch',
                      label: 'Switch branch',
                      group: 'Thread',
                      keys: <String>['⌘', 'B'],
                    ),
                    PaletteCommand(
                      id: 'model',
                      label: 'Pick a model',
                      group: 'Runtime',
                      keys: <String>['⌘', 'M'],
                    ),
                    PaletteCommand(
                      id: 'tools',
                      label: 'Toggle tool calls',
                      group: 'Runtime',
                      keys: <String>['⌘', 'T'],
                    ),
                    PaletteCommand(
                      id: 'theme',
                      label: 'Toggle theme',
                      group: 'View',
                      keys: <String>['⌘', 'D'],
                    ),
                  ],
                  query: _query,
                  activeId: _activeCommand,
                  onQueryChange: (String value) =>
                      setState(() => _query = value),
                  onActiveChange: (String id) =>
                      setState(() => _activeCommand = id),
                  onRun: (String id) =>
                      setState(() => _ranCommand = id),
                ),
                if (_ranCommand != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'ran: $_ranCommand',
                      style: theme.small(context),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _caption(AssistantTheme theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: theme.small(context)),
      );

  Widget _row(List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Wrap(spacing: 8, runSpacing: 8, children: children),
      );

  Widget _action(String label, VoidCallback onTap) =>
      AuiPillButton(label: label, onPressed: onTap);
}


/// Showcase for the agent family: status chips, a plan, a handoff, an agent
/// card, subagents, tasks, jobs, schedules, checkpoints, memory, the
/// background inbox, the canvas split, the flow canvas and computer use.
class _AgentFamilyDemo extends StatefulWidget {
  const _AgentFamilyDemo();

  @override
  State<_AgentFamilyDemo> createState() => _AgentFamilyDemoState();
}

class _AgentFamilyDemoState extends State<_AgentFamilyDemo> {
  AgentState _status = AgentState.working;
  TaskCardState _task = TaskCardState.working;
  int _jobStage = 1;
  bool _scheduleOn = true;
  String _checkpoint = 'c2';
  final List<MemoryChip> _memory = <MemoryChip>[
    const MemoryChip(
      id: 'm1',
      text: 'prefers tabs over spaces',
      change: MemoryChange.added,
    ),
    const MemoryChip(
      id: 'm2',
      text: 'ships on Fridays',
      change: MemoryChange.updated,
    ),
    const MemoryChip(
      id: 'm3',
      text: 'flutter 3.47',
      change: MemoryChange.existing,
    ),
  ];
  bool _collected = false;
  bool _connected = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);

    return ColoredBox(
      color: theme.muted,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _caption(theme, 'agent-status — three live states'),
                AssistantAgentStatus(
                  state: _status,
                  label: 'Searching the workspace',
                  elapsed: '12s',
                ),
                const SizedBox(height: 8),
                AssistantAgentStatus(
                  state: AgentState.waiting,
                  label: 'Waiting on approval',
                ),
                const SizedBox(height: 8),
                AssistantAgentStatus(
                  state: AgentState.done,
                  label: 'Patched the parser',
                ),
                _row(<Widget>[
                  _action('working', () {
                    setState(() => _status = AgentState.working);
                  }),
                  _action('failed', () {
                    setState(() => _status = AgentState.failed);
                  }),
                ]),
                const SizedBox(height: 22),
                _caption(theme, 'agent-plan'),
                const AssistantAgentPlan(
                  steps: <String>[
                    'Read the failing test',
                    'Patch lib/parser.dart',
                    'Run flutter test',
                    'Write the summary',
                  ],
                  activeIndex: 2,
                ),
                const SizedBox(height: 22),
                _caption(theme, 'agent-handoff'),
                const AssistantAgentHandoff(
                  from: 'planner',
                  to: 'patcher',
                  reason: 'The plan needs code changes in three files.',
                  carried: <String>[
                    'the failing test name',
                    'the file list',
                  ],
                ),
                const SizedBox(height: 22),
                _caption(theme, 'agent-card'),
                AssistantAgentCard(
                  name: 'searcher',
                  description: 'Searches the repo for symbols and usages.',
                  provider: 'local',
                  version: '1.4',
                  model: 'luna',
                  endpoint: 'http://127.0.0.1:7331/mcp',
                  connected: _connected,
                  skills: const <AgentSkill>[
                    AgentSkill(name: 'grep', description: 'search file contents'),
                    AgentSkill(name: 'explain', description: 'summarize a symbol'),
                  ],
                  onConnect: () => setState(() => _connected = true),
                ),
                const SizedBox(height: 22),
                _caption(theme, 'subagent-list'),
                const AssistantSubagentList(
                  agents: <SubagentItem>[
                    SubagentItem(name: 'reader', model: 'luna'),
                    SubagentItem(name: 'writer', model: 'opus'),
                    SubagentItem(name: 'runner', model: 'luna-mini'),
                  ],
                  completedCount: 1,
                  progress: <double>[100, 45, 0],
                  showSummary: true,
                  summaryAgent: SubagentItem(name: 'summary', model: 'luna'),
                ),
                const SizedBox(height: 22),
                _caption(theme, 'task-card — transcript behind the chevron'),
                AssistantTaskCard(
                  label: 'Patch the parser',
                  state: _task,
                  meta: 'edit_file',
                  elapsed: _task == TaskCardState.working ? '8s' : null,
                  transcript: const Text(
                    'read lib/parser.dart · 412 lines\n'
                    'replaced the tokenizer loop\n'
                    'wrote lib/parser.dart',
                  ),
                  result: _task == TaskCardState.failed
                      ? const Text('2 tests failed in parser_test.dart')
                      : null,
                  onOpenChange: (_) {},
                ),
                _row(<Widget>[
                  _action('working', () {
                    setState(() => _task = TaskCardState.working);
                  }),
                  _action('failed', () {
                    setState(() => _task = TaskCardState.failed);
                  }),
                ]),
                const SizedBox(height: 22),
                _caption(theme, 'job-progress'),
                AssistantJobProgress(
                  title: 'Reindex the workspace',
                  stages: const <JobStage>[
                    JobStage(name: 'fetch', weight: 1),
                    JobStage(name: 'parse', weight: 3),
                    JobStage(name: 'write', weight: 1),
                  ],
                  stageIndex: _jobStage,
                  stageProgress: 0.5,
                  eta: '~2 min left',
                  onCancel: () => setState(() => _jobStage = 3),
                ),
                _row(<Widget>[
                  _action('stage +1', () {
                    setState(() => _jobStage = (_jobStage + 1).clamp(0, 3));
                  }),
                  _action('restart', () => setState(() => _jobStage = 0)),
                ]),
                const SizedBox(height: 22),
                _caption(theme, 'schedule-card'),
                AssistantScheduleCard(
                  name: 'nightly reindex',
                  cadence: 'every weekday at 02:00',
                  nextRun: 'Fri 02:00',
                  enabled: _scheduleOn,
                  history: const <ScheduleRun>[
                    ScheduleRun(id: 'r1', at: 'Thu 02:00', ok: true),
                    ScheduleRun(id: 'r2', at: 'Wed 02:00', ok: false),
                  ],
                  onToggle: () => setState(() => _scheduleOn = !_scheduleOn),
                ),
                const SizedBox(height: 22),
                _caption(theme, 'checkpoint-history'),
                AssistantCheckpointHistory(
                  checkpoints: const <Checkpoint>[
                    Checkpoint(
                      id: 'c1',
                      label: 'before the patch',
                      at: '09:12',
                      files: 3,
                    ),
                    Checkpoint(
                      id: 'c2',
                      label: 'after the patch',
                      at: '09:18',
                      files: 4,
                    ),
                    Checkpoint(
                      id: 'c3',
                      label: 'draft answer',
                      at: '09:24',
                      files: 5,
                    ),
                  ],
                  currentId: _checkpoint,
                  onRestore: (String id) => setState(() => _checkpoint = id),
                ),
                const SizedBox(height: 22),
                _caption(theme, 'memory-chips'),
                AssistantMemoryChips(
                  chips: _memory,
                  onForget: (String id) => setState(
                    () => _memory.removeWhere((MemoryChip chip) => chip.id == id),
                  ),
                ),
                const SizedBox(height: 22),
                _caption(theme, 'background-inbox'),
                AssistantBackgroundInbox(
                  runs: <BackgroundRun>[
                    const BackgroundRun(
                      id: 'r1',
                      title: 'Reindex the workspace',
                      state: BackgroundState.running,
                      elapsed: '2m',
                    ),
                    BackgroundRun(
                      id: 'r2',
                      title: 'Summarize the docs',
                      state: _collected
                          ? BackgroundState.running
                          : BackgroundState.ready,
                      elapsed: _collected ? 'now' : '1m',
                      summary: _collected ? null : '18 pages',
                    ),
                    const BackgroundRun(
                      id: 'r3',
                      title: 'Fetch the release notes',
                      state: BackgroundState.failed,
                      elapsed: '30s',
                    ),
                  ],
                  onCollect: (String id) => setState(() => _collected = true),
                ),
                const SizedBox(height: 22),
                _caption(theme, 'canvas-split — thread beside document'),
                const AssistantCanvasSplit(
                  title: 'release-notes.md',
                  version: 3,
                  saved: true,
                  writing: true,
                  messages: <AssistantCanvasMessage>[
                    AssistantCanvasMessage(text: 'Draft the release notes'),
                    AssistantCanvasMessage(
                      text: 'On it — pulling the merged PRs.',
                      speaker: 'assistant',
                    ),
                  ],
                  lines: <AssistantCanvasLine>[
                    AssistantCanvasLine('Release notes', heading: true),
                    AssistantCanvasLine('Streaming landed for tool calls.'),
                    AssistantCanvasLine('Tool families render grouped calls.'),
                  ],
                ),
                const SizedBox(height: 22),
                _caption(theme, 'flow-canvas — routed edges'),
                const AssistantFlowCanvas(
                  nodes: <FlowNode>[
                    FlowNode(id: 'plan', title: 'Planner', left: 24, top: 20),
                    FlowNode(
                      id: 'patch',
                      title: 'Patcher',
                      left: 250,
                      top: 20,
                    ),
                    FlowNode(
                      id: 'test',
                      title: 'Runner',
                      left: 250,
                      top: 150,
                      subtitle: 'flutter test',
                    ),
                  ],
                  edges: <FlowEdge>[
                    FlowEdge(from: 'plan', to: 'patch', label: 'handoff'),
                    FlowEdge(from: 'patch', to: 'test'),
                    FlowEdge(
                      from: 'test',
                      to: 'patch',
                      route: FlowRoute.loopRight,
                      label: 'retry',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _caption(theme, 'computer-use — cursor trail'),
                const AssistantComputerUse(
                  url: 'https://example.com/pricing',
                  activeIndex: 2,
                  steps: <ComputerStep>[
                    ComputerStep(
                      id: 's1',
                      action: 'click',
                      target: 'Sign in',
                      x: 12,
                      y: 18,
                    ),
                    ComputerStep(
                      id: 's2',
                      action: 'type',
                      target: 'email field',
                      x: 38,
                      y: 44,
                    ),
                    ComputerStep(
                      id: 's3',
                      action: 'submit',
                      target: 'Continue',
                      x: 72,
                      y: 68,
                    ),
                  ],
                  screen: ColoredBox(
                    color: Color(0xFF151515),
                    child: Center(
                      child: Text(
                        'screen',
                        style: TextStyle(color: Color(0xFF6B6B6B)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _caption(AssistantTheme theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: theme.small(context)),
      );

  Widget _row(List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Wrap(spacing: 8, runSpacing: 8, children: children),
      );

  Widget _action(String label, VoidCallback onTap) =>
      AuiPillButton(label: label, onPressed: onTap);
}

/// Showcase for the observability family: trace, cost, context, the two
/// heatmaps, confidence marks and a score breakdown.
class _ObservabilityDemo extends StatefulWidget {
  const _ObservabilityDemo();

  @override
  State<_ObservabilityDemo> createState() => _ObservabilityDemoState();
}

class _ObservabilityDemoState extends State<_ObservabilityDemo> {
  int _visibleSpans = 3;
  String _hoveredClaim = 'b';
  int _chartPoints = 5;
  int _specRows = 3;
  bool _accepted = false;
  int _revision = 4;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final DateTime end = DateTime.utc(2026, 9, 21);
    final List<AuiHeatCell> heat = <AuiHeatCell>[
      for (int day = 0; day < 112; day++)
        AuiHeatCell(
          date: end.subtract(Duration(days: 111 - day)),
          count: (day * 5) % 7,
        ),
    ];

    return ColoredBox(
      color: theme.muted,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _caption(theme, 'trace-waterfall'),
                AssistantTraceWaterfall(
                  totalMs: 2140,
                  visibleCount: _visibleSpans,
                  spans: const <TraceSpan>[
                    TraceSpan(
                      id: 'a',
                      name: 'plan',
                      depth: 0,
                      startMs: 0,
                      durationMs: 180,
                      status: SpanStatus.completed,
                    ),
                    TraceSpan(
                      id: 'b',
                      name: 'retrieve',
                      depth: 0,
                      startMs: 180,
                      durationMs: 620,
                      status: SpanStatus.completed,
                    ),
                    TraceSpan(
                      id: 'c',
                      name: 'embed · batch 1',
                      depth: 1,
                      startMs: 200,
                      durationMs: 380,
                      status: SpanStatus.failed,
                    ),
                    TraceSpan(
                      id: 'd',
                      name: 'write',
                      depth: 0,
                      startMs: 800,
                      durationMs: 1340,
                      status: SpanStatus.running,
                    ),
                  ],
                ),
                _row(<Widget>[
                  _action('reveal +1', () {
                    setState(() => _visibleSpans = (_visibleSpans + 1).clamp(1, 4));
                  }),
                ]),
                const SizedBox(height: 22),
                _caption(theme, 'o11y span tree'),
                _SpanTreeDemo(),
                const SizedBox(height: 22),
                _caption(theme, 'cost-meter'),
                const AssistantCostMeter(
                  runCost: r'$0.0042',
                  sessionCost: r'$0.31',
                  lines: <CostLine>[
                    CostLine(
                      model: 'gpt-5.6-luna',
                      inputTokens: 1250,
                      outputTokens: 340,
                      cost: r'$0.0031',
                      share: 0.74,
                    ),
                    CostLine(
                      model: 'claude-opus-4.7',
                      inputTokens: 800,
                      outputTokens: 120,
                      cost: r'$0.0011',
                      share: 0.26,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _caption(theme, 'context-breakdown'),
                const AssistantContextBreakdown(
                  limit: 128000,
                  segments: <ContextSegment>[
                    ContextSegment(
                      label: 'System',
                      tokens: 1200,
                      tint: Color(0xFF8B8B8B),
                    ),
                    ContextSegment(
                      label: 'Messages',
                      tokens: 14800,
                      tint: Color(0xFF3B82F6),
                    ),
                    ContextSegment(
                      label: 'Tools',
                      tokens: 4200,
                      tint: Color(0xFF10B981),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _caption(theme, 'activity-graph'),
                AssistantActivityGraph(
                  data: heat,
                  start: end.subtract(const Duration(days: 111)),
                  end: end,
                  title: 'Runs this quarter',
                  total: '412 runs',
                ),
                const SizedBox(height: 22),
                _caption(theme, 'heat-graph — month labels and tooltips'),
                AssistantHeatGraph(
                  data: heat,
                  start: end.subtract(const Duration(days: 111)),
                  end: end,
                ),
                const SizedBox(height: 22),
                _caption(theme, 'confidence-marker — hover a claim'),
                AssistantConfidenceMarker(
                  hoveredId: _hoveredClaim,
                  onHover: (String id) => setState(() => _hoveredClaim = id),
                  claims: const <ConfidenceClaim>[
                    ConfidenceClaim(
                      id: 'a',
                      text: 'Revenue grew 12% in Q3.',
                      confidence: Confidence.grounded,
                      basis: 'q3 report, p.4',
                    ),
                    ConfidenceClaim(
                      id: 'b',
                      text: 'Churn is flattening.',
                      confidence: Confidence.inferred,
                      basis: 'from the last four weeks',
                    ),
                    ConfidenceClaim(
                      id: 'c',
                      text: 'It will hold through Q4.',
                      confidence: Confidence.uncertain,
                      basis: 'no data yet',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _caption(theme, 'score-breakdown'),
                const AssistantScoreBreakdown(
                  verdict: 'Strong',
                  total: 82.5,
                  outOf: 100,
                  visibleCount: 3,
                  criteria: <ScoreCriterion>[
                    ScoreCriterion(
                      label: 'Correctness',
                      score: 45,
                      weight: 50,
                      note: 'All 157 tests pass.',
                    ),
                    ScoreCriterion(label: 'Style', score: 27.5, weight: 30),
                    ScoreCriterion(label: 'Docs', score: 10, weight: 20),
                  ],
                ),
                const SizedBox(height: 22),
                _caption(theme, 'chart — area today'),
                AssistantChart(
                  label: 'Tokens per run',
                  value: '1,240',
                  delta: '+12%',
                  variant: ChartVariant.area,
                  visibleCount: _chartPoints,
                  points: const <double>[4, 9, 6, 12, 8, 14, 11, 16],
                ),
                const SizedBox(height: 10),
                _caption(theme, 'chart — bars'),
                const AssistantChart(
                  label: 'Runs per day',
                  value: '38',
                  delta: '-18%',
                  variant: ChartVariant.bars,
                  visibleCount: 7,
                  points: <double>[9, 14, 11, 6, 12, 8, 5],
                ),
                _row(<Widget>[
                  _action('reveal +1', () {
                    setState(
                      () => _chartPoints = (_chartPoints + 1).clamp(1, 8),
                    );
                  }),
                ]),
                const SizedBox(height: 22),
                _caption(theme, 'data-table'),
                const AssistantDataTable(
                  rows: <ModelUsage>[
                    ModelUsage(name: 'luna', context: '128k', cost: r'$0.31'),
                    ModelUsage(name: 'opus', context: '200k', cost: r'$0.90'),
                    ModelUsage(name: 'luna-mini', context: '64k', cost: r'$0.04'),
                  ],
                ),
                const SizedBox(height: 22),
                _caption(theme, 'spec-sheet'),
                AssistantSpecSheet(
                  title: 'Renderer',
                  subtitle: 'flutter 3.47 · web',
                  visibleCount: _specRows,
                  rows: const <SpecRow>[
                    SpecRow(label: 'engine', value: 'impeller'),
                    SpecRow(label: 'wasm', value: 'skwasm', emphasis: true),
                    SpecRow(label: 'bundle', value: '1.9 MB'),
                    SpecRow(label: 'hidden', value: 'nope'),
                  ],
                ),
                _row(<Widget>[
                  _action('reveal +1', () {
                    setState(() => _specRows = (_specRows + 1).clamp(1, 4));
                  }),
                ]),
                const SizedBox(height: 22),
                _caption(theme, 'comparison-card'),
                const AssistantComparisonCard(
                  traitLabels: <String>['streaming', 'tool calls', 'resumable'],
                  recommendedId: 'b',
                  reason: 'The data stream protocol streams and keeps a tool '
                      'call in the same message as its answer.',
                  options: <ComparisonOption>[
                    ComparisonOption(
                      id: 'a',
                      name: 'Plain JSON',
                      headline: 'one shot',
                      traits: <String?>[null, null, 'resumable'],
                    ),
                    ComparisonOption(
                      id: 'b',
                      name: 'Data stream',
                      headline: 'AI SDK v1 frames',
                      traits: <String?>['streaming', 'tool calls', 'resumable'],
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _caption(theme, 'recommendation-card'),
                AssistantRecommendationCard(
                  state: _accepted
                      ? RecommendationState.accepted
                      : RecommendationState.idle,
                  question: 'Which transport should the adapter use?',
                  answer: 'The Vercel data stream protocol (v1 frames).',
                  confidenceLabel: 'high confidence',
                  acceptedLabel: 'Using the data stream protocol',
                  onAccept: () => setState(() => _accepted = true),
                  onAlternatives: () => setState(() => _accepted = false),
                ),
                const SizedBox(height: 22),
                _caption(theme, 'connection-state'),
                const AssistantConnectionState(
                  phase: ConnectionPhase.dropped,
                ),
                const SizedBox(height: 8),
                const AssistantConnectionState(
                  phase: ConnectionPhase.reconnecting,
                  attempt: 2,
                ),
                const SizedBox(height: 8),
                const AssistantConnectionState(
                  phase: ConnectionPhase.resumed,
                  resumedTokens: 412,
                ),
                const SizedBox(height: 22),
                _caption(theme, 'number-ticker'),
                AssistantNumberTicker(
                  value: 12480 + _revision * 100,
                  label: 'tokens saved',
                ),
                _row(<Widget>[
                  _action('bump', () => setState(() => _revision++)),
                ]),
                const SizedBox(height: 22),
                _caption(theme, 'timestamp + todo-list + flow-graph'),
                const AssistantTimeline(
                  visibleCount: 3,
                  events: <TimelineEvent>[
                    TimelineEvent(
                      id: 'e1',
                      when: TimelineWhen.past,
                      time: '09:12',
                      title: 'Read the failing test',
                    ),
                    TimelineEvent(
                      id: 'e2',
                      when: TimelineWhen.now,
                      time: '09:18',
                      title: 'Patch lib/parser.dart',
                      detail: '3 files touched',
                    ),
                    TimelineEvent(
                      id: 'e3',
                      when: TimelineWhen.future,
                      time: '09:30',
                      title: 'Run the suite',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const AssistantTodoList(
                  revision: 4,
                  items: <TodoItem>[
                    TodoItem(
                      id: 'a',
                      text: 'Read the failing test',
                      status: TodoStatus.done,
                    ),
                    TodoItem(
                      id: 'b',
                      text: 'Patch the tokenizer',
                      status: TodoStatus.active,
                    ),
                    TodoItem(
                      id: 'c',
                      text: 'Write the summary',
                      status: TodoStatus.pending,
                    ),
                    TodoItem(
                      id: 'd',
                      text: 'Run flutter analyze',
                      status: TodoStatus.failed,
                      reason: '2 issues',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const AssistantFlowGraph(
                  visibleCount: 3,
                  nodes: <FlowGraphNode>[
                    FlowGraphNode(
                      id: 'a',
                      label: 'plan',
                      column: 0,
                      row: 0,
                      state: FlowNodeState.done,
                    ),
                    FlowGraphNode(
                      id: 'b',
                      label: 'patch',
                      column: 1,
                      row: 0,
                      state: FlowNodeState.active,
                    ),
                    FlowGraphNode(
                      id: 'c',
                      label: 'test',
                      column: 2,
                      row: 1,
                      state: FlowNodeState.pending,
                    ),
                    FlowGraphNode(
                      id: 'd',
                      label: 'summary',
                      column: 2,
                      row: 0,
                      state: FlowNodeState.pending,
                    ),
                  ],
                  edges: <FlowGraphEdge>[
                    FlowGraphEdge(from: 'a', to: 'b'),
                    FlowGraphEdge(from: 'b', to: 'd'),
                    FlowGraphEdge(from: 'b', to: 'c'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _caption(AssistantTheme theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: theme.small(context)),
      );

  Widget _row(List<Widget> children) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Wrap(spacing: 8, runSpacing: 8, children: children),
      );

  Widget _action(String label, VoidCallback onTap) =>
      AuiPillButton(label: label, onPressed: onTap);
}

/// The `react-o11y` tree: parents resolved from flat spans, with collapse,
/// status dots and the timeline bar for each row.
class _SpanTreeDemo extends StatefulWidget {
  const _SpanTreeDemo();

  @override
  State<_SpanTreeDemo> createState() => _SpanTreeDemoState();
}

class _SpanTreeDemoState extends State<_SpanTreeDemo> {
  late final SpanTree _tree = SpanTree(<SpanData>[
    SpanData(
      id: 'run',
      name: 'run · answer the question',
      type: 'chain',
      status: OpenSpanStatus.completed,
      startedAt: DateTime.utc(2026, 9, 21, 10, 0, 0),
      latencyMs: 2140,
    ),
    SpanData(
      id: 'plan',
      name: 'plan',
      parentSpanId: 'run',
      type: 'llm',
      status: OpenSpanStatus.completed,
      startedAt: DateTime.utc(2026, 9, 21, 10, 0, 0, 20),
      latencyMs: 180,
    ),
    SpanData(
      id: 'retrieve',
      name: 'retrieve',
      parentSpanId: 'run',
      type: 'retrieval',
      status: OpenSpanStatus.completed,
      startedAt: DateTime.utc(2026, 9, 21, 10, 0, 0, 200),
      latencyMs: 620,
    ),
    SpanData(
      id: 'embed',
      name: 'embed · batch 1',
      parentSpanId: 'retrieve',
      type: 'embedding',
      status: OpenSpanStatus.failed,
      startedAt: DateTime.utc(2026, 9, 21, 10, 0, 0, 260),
      latencyMs: 380,
    ),
    SpanData(
      id: 'write',
      name: 'write the answer',
      parentSpanId: 'run',
      type: 'llm',
      status: OpenSpanStatus.running,
      startedAt: DateTime.utc(2026, 9, 21, 10, 0, 0, 800),
      latencyMs: 1340,
    ),
    SpanData(
      id: 'skip',
      name: 'post-process',
      parentSpanId: 'run',
      type: 'chain',
      status: OpenSpanStatus.skipped,
      startedAt: DateTime.utc(2026, 9, 21, 10, 0, 2, 100),
    ),
  ]);

  @override
  Widget build(BuildContext context) =>
      AuiSpanTimeline(tree: _tree, spacing: 8);
}

/// An auto-playing pass over the interaction motion, so a browser check can
/// capture frames without having to hit a target: one phase every 1.6s drives
/// the entry animations the elements ship.
class _MotionDemo extends StatefulWidget {
  const _MotionDemo();

  @override
  State<_MotionDemo> createState() => _MotionDemoState();
}

class _MotionDemoState extends State<_MotionDemo> {
  Timer? _timer;
  int _phase = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (mounted) setState(() => _phase = (_phase + 1) % 4);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return ColoredBox(
      color: theme.muted,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('phase $_phase', style: theme.code(context)),
                const SizedBox(height: 14),
                // 1. The tool group's body drops in (`duration-200`).
                AssistantToolGroup(
                  label: 'Read 2 files',
                  open: _phase >= 1,
                  initiallyOpen: false,
                  tools: const <GroupedTool>[
                    GroupedTool(
                      id: 'm1',
                      name: 'read_file',
                      target: 'pubspec.yaml',
                      state: GroupedToolState.done,
                      durationMs: 12,
                    ),
                    GroupedTool(
                      id: 'm2',
                      name: 'read_file',
                      target: 'README.md',
                      state: GroupedToolState.done,
                      durationMs: 9,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // 2. Steps slide in one at a time (`duration-300`).
                AssistantToolTimeline(
                  initiallyOpen: true,
                  activeLabel: 'Working',
                  restingLabel: 'Worked for 12s',
                  streaming: true,
                  visibleSteps: 1 + _phase,
                  steps: const <AssistantTimelineStep>[
                    AssistantTimelineStep(verb: 'Read', chip: 'a.dart', icon: Icons.description),
                    AssistantTimelineStep(verb: 'Edit', chip: 'b.dart', icon: Icons.edit),
                    AssistantTimelineStep(verb: 'Run', chip: 'flutter test', icon: Icons.play_arrow),
                    AssistantTimelineStep(verb: 'Write', chip: 'notes.md', icon: Icons.note_add),
                  ],
                ),
                const SizedBox(height: 18),
                // 3. Words arrive and their tint settles (`500ms` / `700ms`).
                AssistantStreamingText(
                  count: 2 + _phase * 2,
                  streaming: true,
                  segments: const <StreamingSegment>[
                    StreamingSegment('The runtime streams partial tokens as they arrive, '),
                    StreamingSegment('so the thread keeps up', mono: true),
                    StreamingSegment(' with the model.'),
                  ],
                ),
                const SizedBox(height: 18),
                // 4. A popover grows in from 0.95 (`duration-150`).
                AuiZoomFadeIn(
                  trigger: _phase,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.background,
                      border: Border.all(color: theme.border),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'grounded · threading.md',
                      style: theme.code(context).copyWith(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The states a thread moves through, side by side: the empty state, the
/// loading and typing indicators, a failed run, the follow-up chips and the
/// timing readout. Each is the shipped widget, not a copy.
class _StatesDemo extends StatefulWidget {
  const _StatesDemo();

  @override
  State<_StatesDemo> createState() => _StatesDemoState();
}

class _StatesDemoState extends State<_StatesDemo> {
  late final LocalRuntime _runtime = LocalRuntime(
    adapter: _NullAdapter(),
    initialMessages: <ThreadMessage>[
      ThreadMessage.single(
        id: 'timed',
        role: MessageRole.assistant,
        createdAt: DateTime(2026, 1, 1),
        content: const <MessagePart>[TextPart('A finished answer.')],
        metadata: const MessageMetadata(
          timing: MessageTiming(
            totalStreamTime: 1400,
            firstTokenTime: 180,
            tokenCount: 96,
            tokensPerSecond: 68.5,
            totalChunks: 24,
          ),
        ),
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    _runtime.thread.setSuggestions(const <ThreadSuggestion>[
      ThreadSuggestion(prompt: 'Summarize this thread'),
      ThreadSuggestion(prompt: 'Show me the code'),
      ThreadSuggestion(prompt: 'Try a different model'),
      ThreadSuggestion(prompt: 'Explain the last step'),
    ]);
  }

  @override
  void dispose() {
    _runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return AuiRuntimeProvider(
      runtime: _runtime,
      // A bounded width around the list: a vertical list hands its children a
      // tight cross-axis width, so the cards fill the column.
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
          _Section(
            title: 'Empty state',
            detail: 'greeting, prompt pills and the stand-in composer',
            child: AssistantEmptyState(
              greeting: 'How can I help you today?',
              suggestions: const <String>['Weather in Tokyo', 'Draft a plan'],
              onSuggestion: (_) {},
              composerPlaceholder: 'Ask anything…',
              onSend: () {},
            ),
          ),
          _Section(
            title: 'Loading state',
            detail: 'the shimmering grid while a run warms up',
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: AssistantLoadingState(),
            ),
          ),
          _Section(
            title: 'Typing indicator',
            detail: 'the three-dot wave',
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: AssistantTypingIndicator(),
            ),
          ),
          _Section(
            title: 'Error state',
            detail: 'a failed run with a retry, and the retrying line',
            child: Column(
              children: <Widget>[
                AssistantErrorState(
                  title: 'The run failed',
                  detail: 'Upstream returned 503 after 1.2s.',
                  onRetry: () {},
                ),
                const SizedBox(height: 12),
                const AssistantErrorState(
                  title: 'Still failing',
                  detail: 'Trying again in a moment.',
                  retrying: true,
                ),
              ],
            ),
          ),
          _Section(
            title: 'Follow-up suggestions',
            detail: 'chips read from the thread state, with edge fades',
            child: AssistantFollowUpSuggestions(
              key: const ValueKey<String>('follow-ups'),
            ),
          ),
          _Section(
            title: 'Message timing',
            detail: 'the readout under a finished answer',
            child: AuiMessage(
              message: _runtime.state.thread.messages.first,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: AssistantMessageTiming(),
              ),
            ),
          ),
              Text(
                'Each widget above is the one the package ships, rendered '
                'outside a run so the states can be compared side by side.',
                style:
                    theme.small(context).copyWith(color: theme.mutedForeground),
              ),
              ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.detail,
    required this.child,
  });

  final String title;
  final String detail;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.body(context).copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            detail,
            style: theme.small(context).copyWith(color: theme.mutedForeground),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.muted,
                borderRadius: BorderRadius.circular(theme.cardRadius),
                border: Border.all(color: theme.border),
              ),
              child: Padding(padding: const EdgeInsets.all(12), child: child),
            ),
          ),
        ],
      ),
    );
  }
}

/// The states page never sends, so the adapter answers nothing.
class _NullAdapter implements ChatModelAdapter {
  @override
  Stream<ChatModelRunResult> run(ChatModelRunContext context) async* {
    yield const ChatModelRunResult(
      content: <MessagePart>[],
      status: MessageStatusComplete(),
    );
  }
}
