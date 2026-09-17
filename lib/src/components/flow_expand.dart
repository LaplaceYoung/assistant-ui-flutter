import 'package:flutter/material.dart';

import 'theme.dart';

/// Wraps content with a hover expand control and a full-screen, zoomable
/// viewer — the `flow-expand` element.
///
/// The same surface the Mermaid element uses; both hand their content to it.
class AssistantFlowExpand extends StatefulWidget {
  const AssistantFlowExpand({
    super.key,
    required this.child,
    this.label = 'Expand diagram',
    this.closeLabel = 'Close diagram',
    this.alwaysShowTrigger = false,
  });

  final Widget child;

  final String label;
  final String closeLabel;

  /// Keeps the expand control visible instead of revealing it on hover.
  final bool alwaysShowTrigger;

  @override
  State<AssistantFlowExpand> createState() => _AssistantFlowExpandState();
}

class _AssistantFlowExpandState extends State<AssistantFlowExpand> {
  final OverlayPortalController _overlay = OverlayPortalController();
  final TransformationController _transform = TransformationController();
  bool _hovered = false;

  static const double _minScale = 0.5;
  static const double _maxScale = 4;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _open() {
    _overlay.show();
  }

  void _close() {
    _overlay.hide();
    _transform.value = Matrix4.identity();
  }

  void _zoomBy(double factor) {
    // Upstream zooms about the viewport centre within 0.5×–4×.
    final Matrix4 next = _transform.value.clone();
    final double current = next.getMaxScaleOnAxis();
    final double target = (current * factor).clamp(_minScale, _maxScale);
    final double ratio = target / current;
    next.scaleByDouble(ratio, ratio, ratio, 1);
    _transform.value = next;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: OverlayPortal(
        controller: _overlay,
        overlayChildBuilder: (BuildContext context) => Positioned.fill(
          child: _Viewer(
            transform: _transform,
            onZoom: _zoomBy,
            onReset: () => _transform.value = Matrix4.identity(),
            onClose: _close,
            closeLabel: widget.closeLabel,
            child: widget.child,
          ),
        ),
        child: Stack(
          children: <Widget>[
            widget.child,
            // `Positioned.fill` + `Align` keeps the control inside the child's
            // box: a `Positioned` corner would sit outside a small child and
            // stop taking taps.
            Positioned.fill(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AnimatedOpacity(
                    opacity: widget.alwaysShowTrigger || _hovered ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: IgnorePointer(
                      ignoring: !(widget.alwaysShowTrigger || _hovered),
                      child: _Control(
                        icon: Icons.fullscreen,
                        label: widget.label,
                        onTap: _open,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Viewer extends StatelessWidget {
  const _Viewer({
    required this.transform,
    required this.onZoom,
    required this.onReset,
    required this.onClose,
    required this.closeLabel,
    required this.child,
  });

  final TransformationController transform;
  final ValueChanged<double> onZoom;
  final VoidCallback onReset;
  final VoidCallback onClose;
  final String closeLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Semantics(
      container: true,
      // The toolbar keeps its own nodes; without this their labels fold into
      // one long string on the viewer.
      explicitChildNodes: true,
      label: 'Diagram',
      child: Container(
        color: theme.background,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: transform,
                minScale: 0.5,
                maxScale: 4,
                child: Center(child: child),
              ),
            ),
            Positioned(
              right: 16,
              top: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.muted.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _Control(
                      icon: Icons.add,
                      label: 'Zoom in',
                      onTap: () => onZoom(1.25),
                    ),
                    _Control(
                      icon: Icons.remove,
                      label: 'Zoom out',
                      onTap: () => onZoom(0.8),
                    ),
                    _Control(
                      icon: Icons.refresh,
                      label: 'Reset zoom',
                      onTap: onReset,
                    ),
                    _Control(
                      icon: Icons.close,
                      label: closeLabel,
                      onTap: onClose,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Semantics(
      // Without `container` the label folds into an ancestor node and the
      // control reads as unlabelled.
      container: true,
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        // The label is already on the Semantics node above; a second one
        // doubles it for screen readers.
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(icon, size: 16, color: theme.mutedForeground),
          ),
        ),
      ),
    );
  }
}
