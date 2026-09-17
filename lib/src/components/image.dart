import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// How the image frame is drawn.
enum AuiImageVariant { outline, ghost, muted }

/// Width cap of the frame, mirroring upstream's `max-w-*` steps.
enum AuiImageSize { sm, standard, lg, full }

/// What the frame is showing.
enum AuiImageState {
  loading,
  ready,
  failed,

  /// Withheld by a policy (upstream's shield state).
  blocked,
}

/// An image frame: loading, loaded, failed or blocked, with download and copy
/// controls and a zoom surface — the `image` element.
///
/// Note: upstream downloads by building an object URL from the data URI and
/// copies through the async clipboard. Dart has no image-clipboard API, so the
/// two controls call host callbacks instead — the frame and states match.
class AssistantImage extends StatefulWidget {
  const AssistantImage({
    super.key,
    this.image,
    this.variant = AuiImageVariant.outline,
    this.size = AuiImageSize.standard,
    this.state = AuiImageState.ready,
    this.semanticsLabel = 'Image content',
    this.onDownload,
    this.onCopy,
    this.zoomable = true,
    this.failedLabel = 'Image could not be displayed',
    this.blockedLabel = 'Image blocked by policy',
  });

  /// The picture itself, e.g. `Image.memory` or an `Image.network`.
  final Widget? image;

  final AuiImageVariant variant;
  final AuiImageSize size;
  final AuiImageState state;
  final String semanticsLabel;

  /// Controls appear on hover when supplied.
  final VoidCallback? onDownload;
  final VoidCallback? onCopy;

  final bool zoomable;
  final String failedLabel;
  final String blockedLabel;

  @override
  State<AssistantImage> createState() => _AssistantImageState();
}

class _AssistantImageState extends State<AssistantImage> {
  bool _hovered = false;
  bool _zoomed = false;

  double get _maxWidth => switch (widget.size) {
        AuiImageSize.sm => 256,
        AuiImageSize.standard => 384,
        AuiImageSize.lg => 512,
        AuiImageSize.full => double.infinity,
      };

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool outline = widget.variant == AuiImageVariant.outline;
    final Color? fill = switch (widget.variant) {
      AuiImageVariant.muted => theme.muted.withValues(alpha: 0.5),
      AuiImageVariant.outline || AuiImageVariant.ghost => null,
    };

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: _maxWidth),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Stack(
          children: <Widget>[
            Semantics(
              image: true,
              label: widget.semanticsLabel,
              child: GestureDetector(
                onTap: widget.zoomable &&
                        widget.state == AuiImageState.ready &&
                        widget.image != null
                    ? () => setState(() => _zoomed = true)
                    : null,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 128),
                  decoration: BoxDecoration(
                    color: fill,
                    border: outline ? Border.all(color: theme.border) : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: switch (widget.state) {
                    AuiImageState.loading => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: AuiSpinner(
                            size: 20,
                            color: theme.mutedForeground,
                          ),
                        ),
                      ),
                    AuiImageState.failed => _Message(
                        icon: Icons.hide_image_outlined,
                        label: widget.failedLabel,
                      ),
                    AuiImageState.blocked => _Message(
                        icon: Icons.gpp_maybe_outlined,
                        label: widget.blockedLabel,
                      ),
                    AuiImageState.ready =>
                      widget.image ?? const SizedBox(height: 128),
                  },
                ),
              ),
            ),
            if (widget.state == AuiImageState.ready &&
                (widget.onDownload != null || widget.onCopy != null))
              Positioned(
                right: 8,
                top: 8,
                child: AnimatedOpacity(
                  opacity: _hovered ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.background,
                      border: Border.all(color: theme.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (widget.onDownload != null)
                          AuiIconAction(
                            icon: Icons.download_outlined,
                            label: 'Download image',
                            size: 26,
                            onPressed: widget.onDownload,
                          ),
                        if (widget.onCopy != null)
                          AuiIconAction(
                            icon: Icons.copy,
                            label: 'Copy image',
                            size: 26,
                            onPressed: widget.onCopy,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_zoomed && widget.image != null)
              Positioned.fill(
                child: _ZoomOverlay(
                  label: widget.semanticsLabel,
                  onClose: () => setState(() => _zoomed = false),
                  child: widget.image!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 20, color: theme.mutedForeground),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: theme.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomOverlay extends StatelessWidget {
  const _ZoomOverlay({
    required this.child,
    required this.label,
    required this.onClose,
  });

  final Widget child;
  final String label;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Semantics(
      container: true,
      label: label,
      child: Container(
        color: theme.background,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: GestureDetector(
                onTap: onClose,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Center(child: child),
                ),
              ),
            ),
            Positioned(
              right: 16,
              top: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.background,
                  border: Border.all(color: theme.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(4),
                child: AuiIconAction(
                  icon: Icons.close,
                  label: 'Close',
                  size: 28,
                  onPressed: onClose,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
