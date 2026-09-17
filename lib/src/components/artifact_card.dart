import 'package:flutter/material.dart';

import '../primitives/message.dart' show AuiMessageHoverScope;
import 'motion.dart';
import 'surfaces.dart';
import 'theme.dart';

/// A document the run is producing, with its size so far — the
/// `artifact-card` element.
class AssistantArtifactCard extends StatelessWidget {
  const AssistantArtifactCard({
    super.key,
    required this.title,
    required this.meta,
    this.generating = false,
    this.words = 0,
    this.onTap,
  });

  final String title;

  /// Shown when the artifact is settled, e.g. `12 pages · pdf`.
  final String meta;

  /// While generating, the meta line becomes a live word count.
  final bool generating;

  final int words;

  /// Makes the card active; the corner arrow appears on hover either way.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: SizedBox(
        width: double.infinity,
        child: _Hover(
          onTap: onTap,
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: auiFg(theme, 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 16,
                  color: auiFg(theme, 0.45),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: theme.foreground,
                      ),
                    ),
                    if (generating)
                      // `fade-in blur-in-[2px] animate-in duration-300` when
                      // the live word count takes over the meta line.
                      AuiFadeInBlur(
                        trigger: generating,
                        child: Row(
                        children: <Widget>[
                          AuiShimmerLabel(
                            text: 'Writing',
                            style: auiMono(
                              context,
                              color: auiFg(theme, 0.4),
                            ),
                          ),
                          Text(
                            ' · ',
                            style: auiMono(
                              context,
                              color: auiFg(theme, 0.4),
                            ),
                          ),
                          Text(
                            '$words words',
                            style: auiMono(
                              context,
                              color: auiFg(theme, 0.4),
                            ).copyWith(
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                        ),
                      )
                    else
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: auiMono(context, color: auiFg(theme, 0.4)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _CornerArrow(theme: theme),
            ],
          ),
        ),
      ),
    );
  }
}

class _CornerArrow extends StatelessWidget {
  const _CornerArrow({required this.theme});

  final AssistantTheme theme;

  @override
  Widget build(BuildContext context) {
    final ValueNotifier<bool>? hovered = AuiMessageHoverScope.maybeOf(context);
    if (hovered == null) {
      return Icon(
        Icons.north_east,
        size: 14,
        color: auiFg(theme, 0.35),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: hovered,
      builder: (BuildContext context, bool isHovered, Widget? child) =>
          AnimatedOpacity(
        opacity: isHovered ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: child,
      ),
      child: Icon(Icons.north_east, size: 14, color: auiFg(theme, 0.35)),
    );
  }
}

class _Hover extends StatefulWidget {
  const _Hover({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Hover> createState() => _HoverState();
}

class _HoverState extends State<_Hover> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapCancel: widget.onTap == null
            ? null
            : () => setState(() => _pressed = false),
        onTapUp: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          // `active:scale-[0.98]`, same 150ms as the lift.
          scale: _pressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          // Upstream lifts the card a pixel on hover.
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
            decoration: auiPaper(theme, radius: 20),
            padding: const EdgeInsets.all(14),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
