import 'dart:async';

import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';

import '../landing_theme.dart';

/// Live demonstrations for the "What the runtime handles" list — one per act,
/// each built from the ported package components rather than a mock. The live
/// page renders the same set (`components/demo/elements/*`) in its showcase
/// slot, so the landing shows real widgets here too.
Widget showcaseDemo(int index) => switch (index) {
      0 => const _StreamingDemo(),
      1 => const _ReasoningDemo(),
      2 => const _ToolCallDemo(),
      3 => const _ApprovalDemo(),
      4 => const _SourcesDemo(),
      5 => const _AttachmentDemo(),
      6 => const _BranchingDemo(),
      7 => const _SuggestionsDemo(),
      8 => const _VoiceDemo(),
      _ => const _GenerativeUIDemo(),
    };

/// The frame every demo sits in, so the slot keeps one shape while it swaps.
class DemoSlot extends StatelessWidget {
  const DemoSlot({super.key, required this.index, this.maxWidth});

  final int index;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    final Widget body = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: KeyedSubtree(
          key: ValueKey<int>(index),
          child: showcaseDemo(index),
        ),
      ),
    );
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: body,
      ),
    );
  }
}

/// Words arriving one at a time, newest tinted.
class _StreamingDemo extends StatefulWidget {
  const _StreamingDemo();

  @override
  State<_StreamingDemo> createState() => _StreamingDemoState();
}

class _StreamingDemoState extends State<_StreamingDemo>
    with SingleTickerProviderStateMixin {
  static const List<StreamingSegment> _segments = <StreamingSegment>[
    StreamingSegment('The runtime '),
    StreamingSegment('streams '),
    StreamingSegment('partial '),
    StreamingSegment('tokens '),
    StreamingSegment('as they '),
    StreamingSegment('arrive', mono: true),
    StreamingSegment(', so the thread '),
    StreamingSegment('keeps up '),
    StreamingSegment('with the model.'),
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final int total = _segments.length;
        final int count = (_controller.value * (total + 2)).floor().clamp(0, total);
        return AssistantStreamingText(
          segments: _segments,
          count: count,
          streaming: count < total,
        );
      },
    );
  }
}

/// Reasoning steps revealed while the answer is still coming.
class _ReasoningDemo extends StatefulWidget {
  const _ReasoningDemo();

  @override
  State<_ReasoningDemo> createState() => _ReasoningDemoState();
}

class _ReasoningDemoState extends State<_ReasoningDemo>
    with SingleTickerProviderStateMixin {
  static const List<ReasoningStep> _steps = <ReasoningStep>[
    ReasoningStep(
      title: 'Read the failing assertion',
      body: 'The diff shows order 41 missing its discount.',
    ),
    ReasoningStep(
      title: 'Trace the discount path',
      body: 'Totals are recomputed before the line items are ranked.',
    ),
    ReasoningStep(
      title: 'Pick the fix',
      body: 'Rank first, then recompute so the order stays stable.',
    ),
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final int visible =
            (_controller.value * (_steps.length + 1)).floor().clamp(0, _steps.length);
        return AssistantReasoningPanel(
          steps: _steps,
          visibleSteps: visible,
          restingLabel: 'Thought for 4s',
          streaming: visible < _steps.length,
          open: true,
        );
      },
    );
  }
}

/// A tool call running, then reporting what it returned.
class _ToolCallDemo extends StatefulWidget {
  const _ToolCallDemo();

  @override
  State<_ToolCallDemo> createState() => _ToolCallDemoState();
}

class _ToolCallDemoState extends State<_ToolCallDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final bool done = _controller.value > 0.45;
        return AssistantToolCallCard(
          part: ToolCallPart(
            toolCallId: 'demo-weather',
            toolName: 'get_weather',
            args: const <String, Object?>{'city': 'Tokyo'},
            result: done
                ? const <String, Object?>{'tempC': 21, 'sky': 'clear'}
                : null,
          ),
        );
      },
    );
  }
}

/// The approval gate: a request, the run behind it, the outcome.
class _ApprovalDemo extends StatefulWidget {
  const _ApprovalDemo();

  @override
  State<_ApprovalDemo> createState() => _ApprovalDemoState();
}

class _ApprovalDemoState extends State<_ApprovalDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final double v = _controller.value;
        final ApprovalState state = v < 0.4
            ? ApprovalState.request
            : v < 0.75
                ? ApprovalState.running
                : ApprovalState.done;
        return AssistantApprovalCard(
          state: state,
          command: 'rm -rf build/',
          title: 'Clean the build directory',
          subtitle: 'The tool wants to remove generated output.',
          onAllowOnce: state == ApprovalState.request ? () {} : null,
          onAlwaysAllow: state == ApprovalState.request ? () {} : null,
          onDeny: state == ApprovalState.request ? () {} : null,
        );
      },
    );
  }
}

/// Citations collected from the run.
class _SourcesDemo extends StatelessWidget {
  const _SourcesDemo();

  @override
  Widget build(BuildContext context) {
    return const AssistantSources(
      sources: <SourceRef>[
        SourceRef(
          domain: 'assistant-ui.com',
          title: 'Streaming and the runtime',
          snippet: 'Parts arrive as they are produced, and the viewport follows.',
        ),
        SourceRef(
          domain: 'nextjs.org',
          title: 'Route handlers',
          snippet: 'A handler can stream a response back to the client.',
        ),
        SourceRef(
          domain: 'developer.mozilla.org',
          title: 'Server-sent events',
          snippet: 'A text/event-stream response delivers messages over time.',
        ),
      ],
      initiallyOpen: true,
    );
  }
}

/// An attachment uploading, then landing on the message.
class _AttachmentDemo extends StatefulWidget {
  const _AttachmentDemo();

  @override
  State<_AttachmentDemo> createState() => _AttachmentDemoState();
}

class _AttachmentDemoState extends State<_AttachmentDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final double progress = _controller.value < 0.7
            ? _controller.value / 0.7
            : 1;
        return Row(
          children: <Widget>[
            AssistantAttachmentCard(
              attachment: const DocumentAttachment(
                id: 'demo-brief',
                mimeType: 'application/pdf',
                filename: 'q3-brief.pdf',
              ),
              progress: progress,
            ),
            const SizedBox(width: 12),
            AssistantAttachmentCard(
              attachment: const ImageAttachment(
                id: 'demo-shot',
                url: '',
                filename: 'dashboard.png',
              ),
              progress: 1,
            ),
          ],
        );
      },
    );
  }
}

/// Regenerating keeps every version instead of dropping the answer.
class _BranchingDemo extends StatefulWidget {
  const _BranchingDemo();

  @override
  State<_BranchingDemo> createState() => _BranchingDemoState();
}

class _BranchingDemoState extends State<_BranchingDemo> {
  late final LocalRuntime _runtime = LocalRuntime(
    options: LocalRuntimeOptions(maxSteps: 1),
    adapter: _ScriptedAdapter(),
  );

  @override
  void initState() {
    super.initState();
    unawaited(_seed());
  }

  /// One run, then two regenerations: three branches on the last message.
  /// Each step waits for the previous run so the regeneration is not dropped.
  Future<void> _seed() async {
    await _runtime.thread.send(
      content: const <MessagePart>[TextPart('Pick a fix')],
    );
    await _runtime.thread.settled;
    await _runtime.thread.reload();
    await _runtime.thread.settled;
    await _runtime.thread.reload();
  }

  @override
  void dispose() {
    _runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuiRuntimeProvider(
      runtime: _runtime,
      // The runtime is a ChangeNotifier, so the picker follows the branches.
      child: AnimatedBuilder(
        animation: _runtime,
        builder: (BuildContext context, Widget? _) {
          final List<ThreadMessage> messages = _runtime.thread.state.messages;
          final int index = messages.lastIndexWhere(
            (ThreadMessage message) => message.isAssistant,
          );
          if (index < 0) {
            return const SizedBox(height: 40);
          }
          return AuiMessage(
            message: messages[index],
            child: const AssistantBranchPickerBar(),
          );
        },
      ),
    );
  }
}

/// Follow-up prompts the runtime offers, one being picked.
class _SuggestionsDemo extends StatefulWidget {
  const _SuggestionsDemo();

  @override
  State<_SuggestionsDemo> createState() => _SuggestionsDemoState();
}

class _SuggestionsDemoState extends State<_SuggestionsDemo> {
  static const List<String> _suggestions = <String>[
    'Summarize the diff',
    'Open a pull request',
    'Explain the failure',
  ];

  int _pick = -1;

  late final StreamSubscription<void> _ticks = Stream<void>.periodic(
    const Duration(milliseconds: 1600),
  ).listen((_) {
    if (!mounted) return;
    setState(() => _pick = _pick >= _suggestions.length - 1 ? 0 : _pick + 1);
  });

  @override
  void dispose() {
    _ticks.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AssistantSuggestions(
      suggestions: _suggestions,
      selected: _pick == -1 ? null : _suggestions[_pick],
    );
  }
}

/// Dictation wired into the composer controls.
class _VoiceDemo extends StatefulWidget {
  const _VoiceDemo();

  @override
  State<_VoiceDemo> createState() => _VoiceDemoState();
}

class _VoiceDemoState extends State<_VoiceDemo> {
  late final LocalRuntime _runtime = LocalRuntime(
    options: LocalRuntimeOptions(dictation: _DemoDictation()),
    adapter: _ScriptedAdapter(),
  );

  @override
  void initState() {
    super.initState();
    // Dictation runs for the camera, restarting when the fake session ends.
    unawaited(_dictate());
  }

  Future<void> _dictate() async {
    while (mounted) {
      await _runtime.thread.startDictation();
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      if (!mounted) return;
      await _runtime.thread.stopDictation();
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
  }

  @override
  void dispose() {
    _runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuiRuntimeProvider(
      runtime: _runtime,
      child: const Row(
        children: <Widget>[
          AssistantComposerVoice(size: 34),
          SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// A chart the model asked for, drawing itself.
class _GenerativeUIDemo extends StatefulWidget {
  const _GenerativeUIDemo();

  @override
  State<_GenerativeUIDemo> createState() => _GenerativeUIDemoState();
}

class _GenerativeUIDemoState extends State<_GenerativeUIDemo>
    with SingleTickerProviderStateMixin {
  static const List<double> _points = <double>[
    12, 18, 15, 24, 30, 26, 38, 44, 41, 52, 58, 64,
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final int visible = (_controller.value * _points.length)
            .ceil()
            .clamp(1, _points.length);
        return AssistantChart(
          label: 'Weekly downloads',
          value: '1.3M',
          delta: '+12%',
          points: _points,
          visibleCount: visible,
          height: 96,
        );
      },
    );
  }
}

/// A dictation session that emits a rolling transcript, for the voice demo.
class _DemoDictation implements DictationAdapter {
  @override
  Future<DictationSession> start() async {
    final StreamController<String> controller = StreamController<String>();
    const List<String> transcript = <String>[
      'Summarize ',
      'the last ',
      'three commits',
    ];
    int index = 0;
    final Timer timer = Timer.periodic(const Duration(milliseconds: 700), (t) {
      if (index >= transcript.length) {
        t.cancel();
        controller.close();
        return;
      }
      final String partial = transcript.take(index + 1).join();
      index += 1;
      controller.add(partial);
    });
    return DictationSession(
      transcripts: controller.stream,
      stop: () async {
        timer.cancel();
        await controller.close();
      },
    );
  }
}

/// Answers each run with a different version, so regenerating produces
/// distinct branches.
class _ScriptedAdapter implements ChatModelAdapter {
  int _run = 0;

  static const List<String> _versions = <String>[
    'Rank the line items before recomputing the totals.',
    'Recompute the totals after ranking, then compare the two orders.',
    'Sort by rank, recompute once, and assert the discount per line.',
  ];

  @override
  Stream<ChatModelRunResult> run(ChatModelRunContext context) async* {
    final String text = _versions[_run % _versions.length];
    _run += 1;
    yield ChatModelRunResult(content: <MessagePart>[TextPart(text)]);
  }
}
