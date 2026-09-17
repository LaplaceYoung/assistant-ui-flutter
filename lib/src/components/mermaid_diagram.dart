import 'package:flutter/material.dart';

import 'flow_expand.dart';
import 'theme.dart';

/// A diagram with a skeleton while its code streams, a code fallback when it
/// cannot be drawn, and a full-screen zoom — the `mermaid-diagram` element.
///
/// Note: upstream renders Mermaid with the `beautiful-mermaid` JS engine.
/// Flutter has no Mermaid port, so the port keeps everything around the
/// drawing — skeleton, fallback, hover expand, the zoom surface — and takes
/// the drawing itself as [diagram] (a host-rendered SVG/raster, or a Dart
/// graph). Pass no [diagram] to get the fallback.
class AssistantMermaidDiagram extends StatelessWidget {
  const AssistantMermaidDiagram({
    super.key,
    required this.code,
    this.diagram,
    this.streaming = false,
    this.zoomable = true,
  });

  /// The Mermaid source; shown verbatim in the fallback.
  final String code;

  /// The rendered diagram.
  final Widget? diagram;

  /// Replaces the diagram with the skeleton while the code streams in.
  final bool streaming;

  final bool zoomable;

  @override
  Widget build(BuildContext context) {
    if (streaming) return const AssistantMermaidSkeleton();
    if (diagram == null) return _Fallback(code: code);
    final Widget body = Container(
      color: theme(context),
      padding: const EdgeInsets.all(8),
      alignment: Alignment.center,
      child: diagram,
    );
    if (!zoomable) return body;
    // The expand surface is shared with the flow element.
    return AssistantFlowExpand(
      label: 'Expand diagram',
      child: body,
    );
  }

  static Color theme(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return theme.muted.withValues(alpha: 0.5);
  }
}

/// The three-card skeleton upstream shows while the diagram streams.
class AssistantMermaidSkeleton extends StatefulWidget {
  const AssistantMermaidSkeleton({super.key});

  @override
  State<AssistantMermaidSkeleton> createState() =>
      _AssistantMermaidSkeletonState();
}

class _AssistantMermaidSkeletonState extends State<AssistantMermaidSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final Color block = theme.mutedForeground.withValues(alpha: 0.2);
    return Semantics(
      label: 'Rendering diagram',
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.4, end: 1).animate(_pulse),
        child: Container(
          height: 128,
          decoration: BoxDecoration(
            color: theme.muted,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(theme.cardRadius),
              bottomRight: Radius.circular(theme.cardRadius),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (int i = 0; i < 3; i++) ...<Widget>[
                if (i > 0)
                  Container(width: 40, height: 1, color: block),
                Container(
                  width: 80,
                  height: 32,
                  decoration: BoxDecoration(
                    color: block,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          color: theme.muted.withValues(alpha: 0.75),
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(code.trim(), style: theme.code(context)),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.border)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Text(
            'diagram could not be rendered',
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: theme.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}
