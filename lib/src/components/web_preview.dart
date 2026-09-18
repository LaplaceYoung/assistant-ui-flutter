import 'package:flutter/material.dart';

import 'theme.dart';
import 'tooltip_icon_button.dart';

/// Chrome around a preview: the origin, a reload, and open-in-new — the
/// `web-preview` element. It renders [child] as given and enforces no
/// isolation of its own, so the caller passes an already-sandboxed frame
/// (on web, [WebPreviewFrame]).
class AssistantWebPreview extends StatelessWidget {
  const AssistantWebPreview({
    super.key,
    required this.origin,
    this.loading = false,
    this.child,
    this.onReload,
    this.onOpenExternal,
    this.width = 448,
    this.height = 280,
  });

  /// Shown in the URL bar; upstream shows the origin, not the full URL.
  final String origin;

  /// Swaps the frame for the loading shimmer.
  final bool loading;

  final Widget? child;
  final VoidCallback? onReload;
  final VoidCallback? onOpenExternal;

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: <Widget>[
                AssistantTooltipIconButton(
                  icon: Icons.refresh,
                  tooltip: 'Reload the preview',
                  size: 24,
                  iconSize: 14,
                  onPressed: onReload,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: theme.muted,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.border),
                    ),
                    child: Text(
                      origin,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.code(context).copyWith(fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                AssistantTooltipIconButton(
                  icon: Icons.open_in_new,
                  tooltip: 'Open in a new tab',
                  size: 24,
                  iconSize: 14,
                  onPressed: onOpenExternal,
                ),
              ],
            ),
          ),
          SizedBox(
            height: height,
            child: loading
                ? _Loading(theme: theme)
                : (child ?? _Empty(theme: theme, origin: origin)),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatefulWidget {
  const _Loading({required this.theme});

  final AssistantTheme theme;

  @override
  State<_Loading> createState() => _LoadingState();
}

class _LoadingState extends State<_Loading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? _) => ColoredBox(
          color: widget.theme.muted.withValues(
            alpha: 0.3 + _controller.value * 0.4,
          ),
          child: Center(
            child: Text(
              'Loading the preview…',
              style: widget.theme.small(context).copyWith(
                color: widget.theme.mutedForeground,
              ),
            ),
          ),
        ),
      );
}

/// The default body: what the frame is, and what to pass to give it one.
///
/// The element draws the chrome and enforces no isolation, exactly as upstream
/// documents; the frame itself is the host's because only the host knows whether
/// that is an `HtmlElementView`, a webview package or a screenshot.
class _Empty extends StatelessWidget {
  const _Empty({required this.theme, required this.origin});

  final AssistantTheme theme;
  final String origin;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: theme.muted.withValues(alpha: 0.4),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  origin,
                  textAlign: TextAlign.center,
                  style: theme.body(context).copyWith(color: theme.foreground),
                ),
                const SizedBox(height: 6),
                Text(
                  'No frame on this platform: pass one as `child` — an '
                  'HtmlElementView on the web, a webview elsewhere.',
                  textAlign: TextAlign.center,
                  style: theme.small(context).copyWith(
                    color: theme.mutedForeground,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
