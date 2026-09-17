import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';

import '../landing_theme.dart';
import '../playground/playground_state.dart';
import '../widgets.dart';

/// The interactive demo on the landing page: a real thread rendered with this
/// package, wrapped in the site's panel chrome (thread rail, chat header,
/// suggestion chips).
///
/// The model is scripted, so the demo works with no backend.
class DemoPanel extends StatefulWidget {
  const DemoPanel({super.key});

  @override
  State<DemoPanel> createState() => _DemoPanelState();
}

class _DemoPanelState extends State<DemoPanel> {
  late final LocalRuntime _runtime = LocalRuntime(
    adapter: _DemoAdapter(),
    options: const LocalRuntimeOptions(maxSteps: 1),
  );

  static const List<String> _suggestions = <String>[
    'Weather in Tokyo',
    'Show a sales dashboard',
    'Switch to dark mode',
    'Derive the geometric series',
    'Diagram a streaming chat app',
    'Add a thread list',
    'Remember my stack',
  ];

  @override
  void dispose() {
    _runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return ContentColumn(
      child: Container(
        height: 620,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedBuilder(
          animation: PlaygroundScope.controllerOf(context),
          builder: (BuildContext context, Widget? _) =>
              AssistantThemeProvider(
            theme: themeWithType(
              themeFor(PlaygroundScope.of(context)),
              PlaygroundScope.of(context),
            ),
            child: AuiRuntimeProvider(
          runtime: _runtime,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) => Row(
              children: <Widget>[
                if (constraints.maxWidth >= 700) _ThreadRail(colors: colors),
                Expanded(
                  child: Column(
                    children: <Widget>[
                      _ChatHeader(colors: colors),
                      Expanded(
                        child: AuiStateBuilder<bool>(
                          selector: (AuiState state) => state.thread.isEmpty,
                          builder: (BuildContext context, bool isEmpty) => isEmpty
                              ? _EmptyState(
                                  colors: colors,
                                  suggestions: _suggestions,
                                  onPick: _submit,
                                )
                              : _Conversation(colors: colors),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit(String prompt) {
    _runtime.composer.setText(prompt);
    _runtime.composer.send();
  }
}

class _ThreadRail extends StatelessWidget {
  const _ThreadRail({required this.colors});

  final LandingColors colors;

  @override
  Widget build(BuildContext context) => Container(
        width: 232,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: colors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.auto_awesome, size: 14, color: colors.foreground),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'assistant-ui',
                        overflow: TextOverflow.ellipsis,
                        style: LandingText.small(context).copyWith(
                          color: colors.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.view_sidebar_outlined, size: 15, color: colors.mutedForeground),
                    const SizedBox(width: 8),
                    Icon(Icons.edit_outlined, size: 15, color: colors.mutedForeground),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: colors.muted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.add, size: 14, color: colors.foreground),
                    const SizedBox(width: 8),
                    Text(
                      'New thread',
                      style: LandingText.small(context).copyWith(color: colors.foreground),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      );
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.colors});

  final LandingColors colors;

  @override
  Widget build(BuildContext context) => Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: <Widget>[
            Text(
              'New chat',
              style: LandingText.body(context).copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(Icons.more_horiz, size: 18, color: colors.mutedForeground),
            const SizedBox(width: 14),
            Icon(Icons.open_in_full, size: 16, color: colors.mutedForeground),
          ],
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.colors,
    required this.suggestions,
    required this.onPick,
  });

  final LandingColors colors;
  final List<String> suggestions;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'How can I help you today?',
              style: LandingText.sectionTitle(context).copyWith(
                color: colors.foreground,
                fontSize: 30,
              ),
            ),
            const SizedBox(height: 22),
            const _DemoComposer(),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: <Widget>[
                for (final String suggestion in suggestions)
                  _SuggestionChip(label: suggestion, onTap: () => onPick(suggestion)),
              ],
            ),
            const SizedBox(height: 18),
            const ArrowLink(label: 'Explore other examples'),
          ],
        ),
      );
}

class _SuggestionChip extends StatefulWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<_SuggestionChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered ? colors.muted : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            widget.label,
            style: LandingText.small(context).copyWith(color: colors.foreground),
          ),
        ),
      ),
    );
  }
}

class _DemoComposer extends StatelessWidget {
  const _DemoComposer();

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 640),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AuiComposerInput(
            placeholder: 'Ask anything…',
            maxLines: 3,
            style: LandingText.body(context).copyWith(color: colors.foreground),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: 'Ask anything…',
              hintStyle: LandingText.body(context).copyWith(color: colors.mutedForeground),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const _ModelPill(),
              const Spacer(),
              AssistantPrimaryAction(
                size: 30,
                iconSize: 17,
                backgroundColor: colors.primary,
                foregroundColor: colors.primaryForeground,
                disabledBackgroundColor: colors.border,
                disabledForegroundColor: colors.mutedForeground,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The model pill: a live menu. Picking a model or an effort level writes to
/// the runtime, and the pill follows what the runtime reports.
class _ModelPill extends StatelessWidget {
  const _ModelPill();

  static const List<ModelOption> _models = <ModelOption>[
    ModelOption(
      id: 'gpt-5.6-luna',
      name: 'GPT-5.6 Luna',
      description: 'Balanced, fast',
      usesDefaultEfforts: true,
    ),
    ModelOption(id: 'gpt-5.6-sol', name: 'GPT-5.6 Sol', description: 'Deeper, slower'),
    ModelOption(id: 'claude-opus-4.7', name: 'Claude Opus 4.7'),
  ];

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    return AnimatedBuilder(
      animation: runtime,
      builder: (BuildContext context, Widget? _) {
        final String modelId = runtime.thread.state.model ?? 'gpt-5.6-luna';
        final ModelOption model = _models.firstWhere(
          (ModelOption option) => option.id == modelId,
          orElse: () => _models.first,
        );
        final List<ModelSelectorEffortOption>? efforts = model.effortOptions;
        final String? effortId =
            runtime.thread.state.effort ?? efforts?.first.id;
        final String effortLabel = efforts == null
            ? ''
            : efforts
                .firstWhere(
                  (ModelSelectorEffortOption option) => option.id == effortId,
                  orElse: () => efforts.first,
                )
                .name;

        return AssistantMenuButton(
          width: 260,
          items: <AssistantMenuItem>[
            for (final ModelOption option in _models)
              AssistantMenuItem(
                label: option.name,
                description: option.description ?? '',
                selected: option.id == model.id,
                onSelected: () => runtime.setModel(option.id),
              ),
            if (efforts != null) ...<AssistantMenuItem>[
              const AssistantMenuItem.separator(),
              for (final ModelSelectorEffortOption option in efforts)
                AssistantMenuItem(
                  label: 'Reasoning effort: ${option.name}',
                  description: option.id == effortId ? 'Applies to the next run' : '',
                  selected: option.id == effortId,
                  onSelected: () => runtime.setEffort(option.id),
                ),
            ],
          ],
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                model.name,
                style: LandingText.small(context)
                    .copyWith(color: colors.mutedForeground),
              ),
              if (efforts != null) ...<Widget>[
                const SizedBox(width: 4),
                Text('·',
                    style: LandingText.small(context)
                        .copyWith(color: colors.mutedForeground)),
                const SizedBox(width: 4),
                Text(
                  effortLabel,
                  style: LandingText.small(context)
                      .copyWith(color: colors.mutedForeground),
                ),
              ],
              const SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down,
                  size: 14, color: colors.mutedForeground),
            ],
          ),
        );
      },
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({required this.colors});

  final LandingColors colors;

  @override
  Widget build(BuildContext context) => AuiThreadViewport(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
            child: AuiThreadMessages(
              builder: (BuildContext context, ThreadMessage message, bool isLast) =>
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
                              color: colors.muted,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const AssistantMessageParts(isUser: true),
                          ),
                        )
                      : const AssistantMessageParts(),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Scripted model: streams a short answer that shows reasoning, markdown and
/// a tool call, so the demo exercises the whole pipeline offline.
class _DemoAdapter extends ChatModelAdapter {
  @override
  Stream<ChatModelRunResult> run(ChatModelRunContext context) async* {
    final List<ThreadMessage> userMessages = context.messages
        .where((ThreadMessage m) => m.isUser)
        .toList(growable: false);
    final String prompt =
        userMessages.isEmpty ? '' : userMessages.last.text.toLowerCase();

    if (prompt.contains('weather')) {
      yield* _streamParts(<MessagePart>[
        const ReasoningPart('The user wants the weather in Tokyo.'),
        const TextPart('Checking the current conditions…'),
        const ToolCallPart(
          toolCallId: 'call_landing',
          toolName: 'get_weather',
          args: <String, Object?>{'city': 'Tokyo'},
          result: <String, Object?>{'temperature': 21, 'conditions': 'partly cloudy'},
        ),
      ]);
      yield* _streamText('It is **21°C** and partly cloudy in Tokyo right now.');
      return;
    }

    yield* _streamParts(<MessagePart>[
      const ReasoningPart('A short answer with a list shows the renderer.'),
      const TextPart('Here is what the runtime handles for you:'),
    ]);
    yield* _streamText(
      '\n\n- **Streaming** with cancellation\n'
      '- **Tools** with automatic execution\n'
      '- **Branching**, editing and regeneration\n\n'
      'Every part of the UI is a component you compose.',
    );
  }

  Stream<ChatModelRunResult> _streamParts(List<MessagePart> parts) async* {
    for (int i = 1; i <= parts.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 180));
      yield ChatModelRunResult(content: parts.sublist(0, i));
    }
  }

  Stream<ChatModelRunResult> _streamText(String text) async* {
    final List<String> tokens = RegExp(r'\s+|\S+')
        .allMatches(text)
        .map((RegExpMatch m) => m.group(0)!)
        .toList();
    final StringBuffer buffer = StringBuffer();
    for (final String token in tokens) {
      buffer.write(token);
      await Future<void>.delayed(const Duration(milliseconds: 14));
      yield ChatModelRunResult(
        content: <MessagePart>[TextPart(buffer.toString())],
      );
    }
  }
}
