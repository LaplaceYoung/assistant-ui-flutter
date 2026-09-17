import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// A figure with zoom controls — the `diagram` element.
class AssistantDiagram extends StatelessWidget {
  const AssistantDiagram({
    super.key,
    required this.title,
    required this.zoom,
    this.child,
    this.onZoomIn,
    this.onZoomOut,
    this.onReset,
    this.onExpand,
  });

  final String title;

  /// Scale of the figure, 1 being 100%.
  final double zoom;

  final Widget? child;

  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onReset;

  /// Adds the full-screen control; without it the control is disabled.
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: theme.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(zoom * 100).round()}%',
                      style: auiMono(context, color: auiFg(theme, 0.3))
                          .copyWith(
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    AuiIconAction(
                      icon: Icons.remove,
                      label: 'Zoom out',
                      size: 28,
                      onPressed: onZoomOut,
                    ),
                    AuiIconAction(
                      icon: Icons.add,
                      label: 'Zoom in',
                      size: 28,
                      onPressed: onZoomIn,
                    ),
                    AuiIconAction(
                      icon: Icons.refresh,
                      label: 'Reset the view',
                      size: 28,
                      onPressed: onReset,
                    ),
                    AuiIconAction(
                      icon: Icons.fullscreen,
                      label: 'Open full screen',
                      size: 28,
                      onPressed: onExpand,
                    ),
                  ],
                ),
              ),
              Container(
                constraints: const BoxConstraints(minHeight: 160),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: auiFg(theme, 0.07)),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                alignment: Alignment.center,
                child: ClipRect(
                  child: AnimatedScale(
                    scale: zoom,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
