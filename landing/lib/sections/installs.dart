import 'package:flutter/material.dart';

import '../landing_theme.dart';
import '../widgets.dart';

/// One runtime tab of the setup sample, mirroring `SETUP_SNIPPETS` in the
/// live page source.
class SetupTab {
  const SetupTab({
    required this.label,
    required this.caption,
    required this.docs,
    required this.code,
  });

  final String label;
  final String caption;

  /// The guide the tab links to.
  final String docs;
  final String code;
}

/// The provider samples, one per runtime. Upstream marks lines 2, 6, 7 and 8
/// as the lines that change between runtimes; the same four are highlighted
/// here.
const List<SetupTab> kSetupTabs = <SetupTab>[
  SetupTab(
    label: 'AI SDK',
    caption: 'Your route runs the model. The transport streams it back.',
    docs: '/docs/runtimes/ai-sdk/overview',
    code: '''import { AssistantRuntimeProvider } from "@assistant-ui/react";
import { useChatRuntime, AssistantChatTransport } from "@assistant-ui/ai-sdk";
import { Thread } from "@/components/assistant-ui/thread";

export default function App() {
  const runtime = useChatRuntime({
    transport: new AssistantChatTransport({ api: "/api/chat" }),
  });

  return (
    <AssistantRuntimeProvider runtime={runtime}>
      <Thread />
    </AssistantRuntimeProvider>
  );
}''',
  ),
  SetupTab(
    label: 'LangGraph',
    caption: 'Point stream at your graph. Threads and interrupts included.',
    docs: '/docs/runtimes/langgraph/overview',
    code: '''import { AssistantRuntimeProvider } from "@assistant-ui/react";
import { useLangGraphRuntime } from "@assistant-ui/react-langgraph";
import { Thread } from "@/components/assistant-ui/thread";

export default function App() {
  const runtime = useLangGraphRuntime({
    stream: (messages, config) => streamMessage({ messages, config }),
  });

  return (
    <AssistantRuntimeProvider runtime={runtime}>
      <Thread />
    </AssistantRuntimeProvider>
  );
}''',
  ),
  SetupTab(
    label: 'LangChain',
    caption: 'Connects to your deployed assistant by id.',
    docs: '/docs/runtimes/langchain',
    code: '''import { AssistantRuntimeProvider } from "@assistant-ui/react";
import { useStreamRuntime } from "@assistant-ui/react-langchain";
import { Thread } from "@/components/assistant-ui/thread";

export default function App() {
  const runtime = useStreamRuntime({
    assistantId: process.env["NEXT_PUBLIC_LANGGRAPH_ASSISTANT_ID"]!,
  });

  return (
    <AssistantRuntimeProvider runtime={runtime}>
      <Thread />
    </AssistantRuntimeProvider>
  );
}''',
  ),
  SetupTab(
    label: 'Mastra',
    caption: 'The same AI SDK client. Your route calls the Mastra agent.',
    docs: '/docs/integrations/frameworks/mastra/overview',
    code: '''import { AssistantRuntimeProvider } from "@assistant-ui/react";
import { useChatRuntime, AssistantChatTransport } from "@assistant-ui/ai-sdk";
import { Thread } from "@/components/assistant-ui/thread";

export default function App() {
  const runtime = useChatRuntime({
    transport: new AssistantChatTransport({ api: "/api/chat" }),
  });

  return (
    <AssistantRuntimeProvider runtime={runtime}>
      <Thread />
    </AssistantRuntimeProvider>
  );
}''',
  ),
  SetupTab(
    label: 'Custom',
    caption: 'No adapter at all. Your store, your transport, any backend.',
    docs: '/docs/runtimes/custom/overview',
    code: '''import { AssistantRuntimeProvider } from "@assistant-ui/react";
import { useExternalStoreRuntime } from "@assistant-ui/react";
import { Thread } from "@/components/assistant-ui/thread";

export default function App() {
  const runtime = useExternalStoreRuntime({
    messages, convertMessage, onNew,
  });

  return (
    <AssistantRuntimeProvider runtime={runtime}>
      <Thread />
    </AssistantRuntimeProvider>
  );
}''',
  ),
];

class InstallsSection extends StatefulWidget {
  const InstallsSection({super.key});

  @override
  State<InstallsSection> createState() => _InstallsSectionState();
}

class _InstallsSectionState extends State<InstallsSection> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final SetupTab tab = kSetupTabs[_tab];
    final LandingColors colors = LandingColors.of(context);
    return ContentColumn(
      child: Padding(
        padding: const EdgeInsets.only(top: 40, bottom: 72),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Eyebrow('What you install'),
            const SizedBox(height: 18),
            Text(
              '@assistant-ui/react',
              style: LandingText.sectionTitle(context).copyWith(
                color: colors.foreground,
                fontSize: 40,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                'The runtime owns the thread, the stream, and the tools.',
                style: LandingText.lead(context).copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            ),
            const SizedBox(height: 44),
            const Eyebrow('The setup'),
            const SizedBox(height: 14),
            Wrap(
              spacing: 48,
              runSpacing: 8,
              children: <Widget>[
                Text(
                  'A provider, a hook, one component.',
                  style: LandingText.body(context).copyWith(color: colors.foreground),
                ),
                Text(
                  'The complete client, whatever runs behind it.',
                  style: LandingText.body(context).copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _RuntimeTabs(
              active: _tab,
              onSelect: (int index) => setState(() => _tab = index),
            ),
            const SizedBox(height: 26),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool wide = constraints.maxWidth >= 900;
                final Widget code = CodeBlock(
                  code: tab.code,
                  highlightedLines: const <int>[2, 6, 7, 8],
                );
                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      code,
                      const SizedBox(height: 24),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: _PixelMatrix(),
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 7, child: code),
                    const SizedBox(width: 40),
                    const Expanded(
                      flex: 3,
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: _PixelMatrix(),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      tab.caption,
                      key: ValueKey<String>(tab.label + tab.caption),
                      style: LandingText.small(context).copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  ),
                ),
                ArrowLink(label: 'read the guide'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// AI SDK · LangGraph · LangChain · Mastra · Custom · all runtimes. Picking a
/// tab swaps the code sample, the caption and the guide link.
class _RuntimeTabs extends StatelessWidget {
  const _RuntimeTabs({required this.active, required this.onSelect});

  final int active;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 800;
        final Widget tabs = Wrap(
          spacing: 26,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            for (int i = 0; i < kSetupTabs.length; i++)
              _RuntimeTab(
                label: kSetupTabs[i].label,
                active: i == active,
                onTap: () => onSelect(i),
              ),
          ],
        );
        if (!wide) return tabs;
        return Row(
          children: <Widget>[
            Expanded(child: tabs),
            const ArrowLink(label: 'All runtimes'),
          ],
        );
      },
    );
  }
}

/// One runtime tab: uppercase mono, foreground when picked or hovered.
class _RuntimeTab extends StatefulWidget {
  const _RuntimeTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_RuntimeTab> createState() => _RuntimeTabState();
}

class _RuntimeTabState extends State<_RuntimeTab> {
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
        child: Text(
          widget.label.toUpperCase(),
          style: LandingText.eyebrow(context).copyWith(
            color: widget.active || _hovered
                ? colors.foreground
                : colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

/// The pixel matrix the live page animates beside the code sample: an 8×5
/// dot grid where a diagonal wave lights the cells in sequence.
class _PixelMatrix extends StatefulWidget {
  const _PixelMatrix();

  @override
  State<_PixelMatrix> createState() => _PixelMatrixState();
}

class _PixelMatrixState extends State<_PixelMatrix>
    with SingleTickerProviderStateMixin {
  static const int _columns = 8;
  static const int _rows = 5;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int row = 0; row < _rows; row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      for (int column = 0; column < _columns; column++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _cell(colors, row, column),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Streaming',
          style: LandingText.small(context).copyWith(color: colors.mutedForeground),
        ),
      ],
    );
  }

  Widget _cell(LandingColors colors, int row, int column) {
    // A diagonal wave: brightness follows the distance from the sweep line.
    final double phase = _controller.value * (_columns + _rows);
    final double distance = (row + column - phase).abs();
    final double opacity = (1 - (distance / 4)).clamp(0.12, 1.0);
    return Opacity(
      opacity: opacity,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: colors.foreground,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}
