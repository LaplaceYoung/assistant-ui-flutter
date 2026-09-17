import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One turn on the conversation rail.
@immutable
class ConversationMapEntry {
  const ConversationMapEntry({
    required this.id,
    required this.title,
    this.preview,
  });

  final String id;
  final String title;

  /// First lines of the turn, shown while the tick is pointed at.
  final String? preview;
}

/// The rail of turns beside a thread: one tick per message, with the active
/// one marked and a preview on hover — the `conversation-map` element.
class AssistantConversationMap extends StatefulWidget {
  const AssistantConversationMap({
    super.key,
    required this.entries,
    this.activeId,
    this.visibleIds = const <String>[],
    this.onSelect,
    this.side = TextDirection.ltr,
    this.width = 24,
  });

  final List<ConversationMapEntry> entries;

  /// Turn the reader is sitting on.
  final String? activeId;

  /// Turns currently on screen; the rest read as dim ticks.
  final List<String> visibleIds;

  final ValueChanged<String>? onSelect;

  /// Which side the preview opens on.
  final TextDirection side;

  final double width;

  @override
  State<AssistantConversationMap> createState() =>
      _AssistantConversationMapState();
}

class _AssistantConversationMapState extends State<AssistantConversationMap> {
  final FocusNode _railFocus = FocusNode(debugLabel: 'conversation-map');
  int? _focused;
  String? _hovered;
  String? _focusedId;

  @override
  void dispose() {
    _railFocus.dispose();
    super.dispose();
  }

  int get _activeIndex => widget.activeId == null
      ? -1
      : widget.entries
          .indexWhere((ConversationMapEntry e) => e.id == widget.activeId);

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final Set<String> inView = widget.visibleIds.toSet();
    final ConversationMapEntry? preview = widget.entries
        .where((ConversationMapEntry entry) => entry.id == _hovered)
        .firstOrNull;

    return SizedBox(
      width: widget.width,
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowUp): _MoveTick(-1),
          SingleActivator(LogicalKeyboardKey.arrowDown): _MoveTick(1),
          SingleActivator(LogicalKeyboardKey.home): _MoveTick(-1, toEnd: false),
          SingleActivator(LogicalKeyboardKey.end): _MoveTick(1, toEnd: true),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _MoveTick: CallbackAction<_MoveTick>(
              onInvoke: (_MoveTick intent) => _step(intent),
            ),
          },
          child: Focus(
            focusNode: _railFocus,
            child: MouseRegion(
              // Pointing at the rail puts it in keyboard range, which is what
              // upstream gets from the ticks being real buttons.
              onEnter: (_) => _railFocus.requestFocus(),
              onExit: (_) => setState(() => _hovered = null),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (final (int index, ConversationMapEntry entry)
                      in widget.entries.indexed)
                    _Tick(
                      entry: entry,
                      active: index == _activeIndex,
                      onScreen: index == _activeIndex || inView.contains(entry.id),
                      focused: _focusedId == entry.id,
                      theme: theme,
                      onSelect: widget.onSelect,
                      onHover: (bool over) => setState(() {
                        _hovered = over ? entry.id : null;
                        if (over) _focused = index;
                      }),
                      follower: preview != null && preview.id == entry.id
                          ? _PreviewAnchor(
                              textDirection: widget.side,
                              preview: preview,
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Object? _step(_MoveTick intent) {
    final int total = widget.entries.length;
    if (total == 0) return null;
    if (intent.toEnd != null) {
      _setFocus(intent.toEnd! ? total - 1 : 0);
      return null;
    }
    final int current = _focused ?? _activeIndex.clamp(0, total - 1);
    _setFocus(current + intent.delta);
    return null;
  }

  void _setFocus(int index) {
    final int clamped = index.clamp(0, widget.entries.length - 1);
    setState(() {
      _focused = clamped;
      _focusedId = widget.entries[clamped].id;
    });
    widget.onSelect?.call(widget.entries[clamped].id);
  }
}

class _MoveTick extends Intent {
  const _MoveTick(this.delta, {this.toEnd});

  final int delta;

  /// Home / End jump to an edge instead of stepping.
  final bool? toEnd;
}

class _Tick extends StatefulWidget {
  const _Tick({
    required this.entry,
    required this.active,
    required this.onScreen,
    required this.focused,
    required this.theme,
    required this.onSelect,
    required this.onHover,
    required this.follower,
  });

  final ConversationMapEntry entry;
  final bool active;
  final bool onScreen;
  final bool focused;
  final AssistantTheme theme;
  final ValueChanged<String>? onSelect;
  final ValueChanged<bool> onHover;
  final Widget? follower;

  @override
  State<_Tick> createState() => _TickState();
}

class _TickState extends State<_Tick> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool highlight = _hovered || widget.focused;
    // At rest every tick is the same short bar; pointing at the rail grows it
    // out by tier, and the active tick reaches the full width.
    final double width = highlight
        ? (widget.active ? 24 : 18)
        : 12;
    final Color color = highlight
        ? widget.theme.foreground.withValues(alpha: 0.7)
        : widget.active
            ? widget.theme.foreground.withValues(alpha: 0.9)
            : widget.onScreen
                ? widget.theme.foreground.withValues(alpha: 0.5)
                : widget.theme.foreground.withValues(alpha: 0.15);

    final Widget tick = SizedBox(
      height: 14,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: width,
          height: widget.active ? 3 : 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
    final Widget interactive = MouseRegion(
      cursor: widget.onSelect == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovered = true);
        widget.onHover(true);
      },
      onExit: (_) {
        setState(() => _hovered = false);
        widget.onHover(false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect == null
            ? null
            : () => widget.onSelect!(widget.entry.id),
        child: tick,
      ),
    );
    final Widget labelled = Semantics(
      container: true,
      button: widget.onSelect != null,
      selected: widget.active,
      label: widget.entry.title,
      child: interactive,
    );
    if (widget.follower == null) return labelled;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[labelled, widget.follower!],
    );
  }
}

/// The preview card, anchored beside the rail while a tick is pointed at.
class _PreviewAnchor extends StatelessWidget {
  const _PreviewAnchor({required this.preview, required this.textDirection});

  final ConversationMapEntry preview;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Positioned(
      top: -8,
      left: textDirection == TextDirection.rtl ? null : 24,
      right: textDirection == TextDirection.rtl ? 24 : null,
      child: Container(
        width: 240,
        decoration: auiPaper(theme, radius: 16),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              preview.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: theme.foreground,
              ),
            ),
            if (preview.preview != null) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                preview.preview!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: auiFg(theme, 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
