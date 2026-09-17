import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One entry a trigger popover offers.
class TriggerItem {
  const TriggerItem({
    required this.id,
    required this.label,
    this.description,
    this.icon,
    this.data,
  });

  final String id;
  final String label;
  final String? description;
  final IconData? icon;

  /// Anything the host wants back when the item is picked.
  final Object? data;
}

/// Backs one trigger character: how to find items and what picking one does.
abstract class AuiTriggerAdapter {
  /// The character that opens the popover, for example `@` or `/`.
  String get triggerChar;

  /// Items matching the text typed after the trigger.
  Future<List<TriggerItem>> search(String query);

  /// Text that replaces the trigger token, or null to leave the composer
  /// untouched (slash commands run instead of inserting).
  String? insertText(TriggerItem item) => null;

  /// Runs when an item is picked — a command's action.
  Future<void> onSelect(TriggerItem item) async {}
}

/// State handed to a popover's builder.
class AuiTriggerState {
  const AuiTriggerState({
    required this.items,
    required this.query,
    required this.highlightedIndex,
    required this.close,
    required this.select,
    required this.highlight,
  });

  final List<TriggerItem> items;
  final String query;
  final int highlightedIndex;
  final VoidCallback close;

  /// Picks [item], or the highlighted one when null.
  final Future<void> Function(TriggerItem? item) select;
  final ValueChanged<int> highlight;
}

/// Shared coordinator for the trigger popovers attached to one composer.
///
/// Owns the composer's text controller, watches the caret for trigger tokens,
/// and routes Up/Down/Enter/Tab/Escape to the open popover before the input's
/// own key handling.
class AuiTriggerController extends ChangeNotifier {
  AuiTriggerController();

  /// Marks the composer input so popovers anchor to it rather than to their
  /// own zero-sized slot in the layout.
  final GlobalKey anchorKey = GlobalKey();

  final Map<String, _RegisteredTrigger> _triggers =
      <String, _RegisteredTrigger>{};

  TextEditingController? _text;
  String? _activeChar;
  String _query = '';
  int _tokenStart = -1;
  int _highlighted = 0;
  Timer? _debounce;

  /// The char whose popover is currently open, if any.
  String? get activeChar => _activeChar;
  bool get isOpen => _activeChar != null;
  String get query => _query;
  int get highlightedIndex => _highlighted;

  List<TriggerItem> get items =>
      _activeChar == null ? const <TriggerItem>[] : _triggers[_activeChar!]!.items;

  void _register(String char, _RegisteredTrigger trigger) {
    _triggers[char] = trigger;
  }

  /// Called by the composer input once it owns a controller.
  void attachText(TextEditingController controller) {
    if (identical(_text, controller)) return;
    _text?.removeListener(syncFromText);
    _text = controller..addListener(syncFromText);
    syncFromText();
  }

  void detachText(TextEditingController controller) {
    if (!identical(_text, controller)) return;
    controller.removeListener(syncFromText);
    _text = null;
    close();
  }

  /// Recomputes the token under the caret and refreshes the open popover.
  void syncFromText() {
    final TextEditingController? text = _text;
    if (text == null || _triggers.isEmpty) return;

    final String value = text.text;
    final int caret = text.selection.isValid
        ? text.selection.baseOffset
        : value.length;
    if (caret < 0) return;

    final String before = value.substring(0, caret.clamp(0, value.length));
    final _Token? token = _tokenAt(before);
    if (token == null) {
      close();
      return;
    }

    _tokenStart = token.start;
    _query = token.query;
    _activeChar = token.char;
    _highlighted = 0;
    _refreshItems();
  }

  _Token? _tokenAt(String before) {
    for (final String char in _triggers.keys) {
      final int index = before.lastIndexOf(char);
      if (index == -1) continue;
      final String query = before.substring(index + char.length);
      // A token ends at whitespace, so "@ann a" no longer matches "@ann".
      if (query.contains(RegExp(r'\s'))) continue;
      // Only open at a word boundary: "a@b" is an email, not a mention.
      if (index > 0 && before[index - 1].trim().isNotEmpty) continue;
      return _Token(char: char, query: query, start: index);
    }
    return null;
  }

  void _refreshItems() {
    final String? char = _activeChar;
    if (char == null) return;
    final _RegisteredTrigger trigger = _triggers[char]!;
    final int generation = ++trigger.generation;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 80), () async {
      final List<TriggerItem> items = await trigger.adapter.search(_query);
      if (trigger.generation != generation || _activeChar != char) return;
      trigger.items = items;
      _highlighted = items.isEmpty ? -1 : 0;
      notifyListeners();
    });
  }

  void highlight(int index) {
    final List<TriggerItem> items = this.items;
    if (items.isEmpty) return;
    _highlighted = index.clamp(0, items.length - 1);
    notifyListeners();
  }

  void moveHighlight(int delta) {
    final List<TriggerItem> items = this.items;
    if (items.isEmpty) return;
    highlight((_highlighted + delta) % items.length);
  }

  /// Closes the popover.
  void close() {
    _debounce?.cancel();
    if (_activeChar == null && _query.isEmpty && _tokenStart == -1) return;
    _activeChar = null;
    _query = '';
    _tokenStart = -1;
    _highlighted = 0;
    notifyListeners();
  }

  /// Closes without notifying — used when the composer goes away.
  void disposeSilently() {
    _debounce?.cancel();
    _text?.removeListener(syncFromText);
    _text = null;
    _activeChar = null;
  }

  /// Picks [item] (or the highlighted one): inserts its text and/or runs it.
  Future<void> select([TriggerItem? item]) async {
    final String? char = _activeChar;
    if (char == null) return;
    final List<TriggerItem> items = this.items;
    final TriggerItem? picked = item ??
        (_highlighted >= 0 && _highlighted < items.length
            ? items[_highlighted]
            : null);
    if (picked == null) return;

    final _RegisteredTrigger trigger = _triggers[char]!;
    final TextEditingController? text = _text;
    if (text != null) {
      final int caret = text.selection.isValid
          ? text.selection.baseOffset.clamp(_tokenStart, text.text.length)
          : text.text.length;
      final String insertion = trigger.adapter.insertText(picked) ?? '';
      final String next = text.text.replaceRange(_tokenStart, caret, insertion);
      final int nextCaret = _tokenStart + insertion.length;
      text.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: nextCaret),
      );
    }
    close();
    await trigger.adapter.onSelect(picked);
  }

  /// Consumes navigation keys while a popover is open. Returns true when the
  /// key was handled and the input should ignore it.
  bool handleKeyEvent(KeyEvent event) {
    if (!isOpen || event is! KeyDownEvent) return false;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        moveHighlight(1);
        return true;
      case LogicalKeyboardKey.arrowUp:
        moveHighlight(-1);
        return true;
      case LogicalKeyboardKey.escape:
        close();
        return true;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
      case LogicalKeyboardKey.tab:
        unawaited(select());
        return true;
      default:
        return false;
    }
  }
}

class _Token {
  const _Token({required this.char, required this.query, required this.start});

  final String char;
  final String query;
  final int start;
}

class _RegisteredTrigger {
  _RegisteredTrigger(this.adapter);

  final AuiTriggerAdapter adapter;
  List<TriggerItem> items = const <TriggerItem>[];
  int generation = 0;
}

/// Makes a [AuiTriggerController] available to the composer and its popovers.
class AuiComposerTriggerRoot extends StatefulWidget {
  const AuiComposerTriggerRoot({super.key, required this.child});

  final Widget child;

  @override
  State<AuiComposerTriggerRoot> createState() => _AuiComposerTriggerRootState();
}

class _AuiComposerTriggerRootState extends State<AuiComposerTriggerRoot> {
  final AuiTriggerController _controller = AuiTriggerController();

  @override
  void dispose() {
    _controller.disposeSilently();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuiTriggerScope(
        controller: _controller,
        child: widget.child,
      );
}

/// Inherited handle onto the composer's [AuiTriggerController].
class AuiTriggerScope extends InheritedNotifier<AuiTriggerController> {
  const AuiTriggerScope({
    super.key,
    required AuiTriggerController controller,
    required super.child,
  }) : super(notifier: controller);

  static AuiTriggerController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AuiTriggerScope>()
      ?.notifier;
}

/// Where a trigger popover opens relative to the composer.
///
/// Composers live at the bottom of the screen, so `above` is the default; a
/// top-docked composer passes `below`.
enum AuiTriggerPlacement { above, below }

/// One character-triggered popover.
///
/// Anchors its overlay to the composer input and renders whatever the builder
/// returns while a token under the caret matches [char].
class AuiComposerTriggerPopover extends StatefulWidget {
  const AuiComposerTriggerPopover({
    super.key,
    required this.adapter,
    required this.builder,
    this.width,
    this.placement = AuiTriggerPlacement.above,
    this.gap = 8,
  });

  final AuiTriggerAdapter adapter;
  final Widget Function(BuildContext context, AuiTriggerState state) builder;

  final double? width;

  /// Which side of the composer the popover appears on.
  final AuiTriggerPlacement placement;

  /// Distance between the popover and the composer.
  final double gap;

  @override
  State<AuiComposerTriggerPopover> createState() =>
      _AuiComposerTriggerPopoverState();
}

class _AuiComposerTriggerPopoverState extends State<AuiComposerTriggerPopover> {
  /// Marks the composer surface the popover anchors to.
  final GlobalKey _anchorKey = GlobalKey();

  final OverlayPortalController _portal = OverlayPortalController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _register();
  }

  @override
  void didUpdateWidget(AuiComposerTriggerPopover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.adapter, widget.adapter)) _register();
  }

  /// Registers once per adapter.
  ///
  /// Reading the scope without creating a dependency matters here: a
  /// dependency would re-run this on every controller notification, and
  /// re-registering resets the loaded items mid-search.
  void _register() {
    final AuiTriggerController? controller =
        context.getInheritedWidgetOfExactType<AuiTriggerScope>()?.notifier;
    if (controller == null) return;
    final _RegisteredTrigger? existing =
        controller._triggers[widget.adapter.triggerChar];
    if (existing != null && identical(existing.adapter, widget.adapter)) {
      return;
    }
    controller._register(
      widget.adapter.triggerChar,
      _RegisteredTrigger(widget.adapter),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuiTriggerController? controller = AuiTriggerScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();

    return KeyedSubtree(
      key: _anchorKey,
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, Widget? _) {
          final bool open = controller.activeChar == widget.adapter.triggerChar;
          // OverlayPortal shows/hides imperatively; sync after the frame so
          // build stays side-effect free.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || open == _portal.isShowing) return;
            if (open) {
              _portal.show();
            } else {
              _portal.hide();
            }
          });
          return OverlayPortal(
            controller: _portal,
            child: const SizedBox.shrink(),
            overlayChildBuilder: (BuildContext context) => _AnchorOnce(
              child: _buildAnchored(context, controller),
            ),
          );
        },
      ),
    );
  }

  /// Positions the popover against the composer's rect.
  ///
  /// The panel is anchored by the edge that faces the composer, so its own
  /// height never has to be known before layout.
  Widget _buildAnchored(
    BuildContext context,
    AuiTriggerController controller,
  ) {
    final RenderObject? anchorObject = controller.anchorKey.currentContext
            ?.findRenderObject() ??
        _anchorKey.currentContext?.findRenderObject();
    if (anchorObject is! RenderBox || !anchorObject.hasSize) {
      return const SizedBox.shrink();
    }
    final Rect anchor =
        anchorObject.localToGlobal(Offset.zero) & anchorObject.size;

    // Build-safe viewport: reading the overlay's render size here would throw
    // ("cannot get size during build").
    final Size viewport = MediaQuery.sizeOf(context);
    final bool above = widget.placement == AuiTriggerPlacement.above;
    final double width = widget.width ?? anchor.width;
    final double left = anchor.left.clamp(
      0.0,
      math.max(0.0, viewport.width - width),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          left: left,
          width: width,
          top: above ? null : anchor.bottom + widget.gap,
          bottom: above
              ? math.max(0.0, viewport.height - anchor.top + widget.gap)
              : null,
          child: widget.builder(
            context,
            AuiTriggerState(
              items: controller.items,
              query: controller.query,
              highlightedIndex: controller.highlightedIndex,
              close: controller.close,
              select: controller.select,
              highlight: controller.highlight,
            ),
          ),
        ),
      ],
    );
  }
}

/// Rebuilds its child once after the first frame.
///
/// The overlay child is first built before the composer has laid out, so the
/// anchor rect is unknown on that pass. One extra frame after mount fixes it.
class _AnchorOnce extends StatefulWidget {
  const _AnchorOnce({required this.child});

  final Widget child;

  @override
  State<_AnchorOnce> createState() => _AnchorOnceState();
}

class _AnchorOnceState extends State<_AnchorOnce> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
