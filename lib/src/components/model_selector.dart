import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One reasoning-effort level a model can be run at.
@immutable
class ModelSelectorEffortOption {
  const ModelSelectorEffortOption({required this.id, required this.name});

  final String id;
  final String name;
}

/// Upstream's `DEFAULT_EFFORT_OPTIONS`.
const List<ModelSelectorEffortOption> auiDefaultEffortOptions =
    <ModelSelectorEffortOption>[
  ModelSelectorEffortOption(id: 'low', name: 'Low'),
  ModelSelectorEffortOption(id: 'medium', name: 'Med'),
  ModelSelectorEffortOption(id: 'high', name: 'High'),
];

/// One entry of the selector.
@immutable
class ModelOption {
  const ModelOption({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.disabled = false,
    this.keywords = const <String>[],
    this.usesDefaultEfforts = false,
    this.efforts,
  });

  final String id;
  final String name;
  final String? description;

  /// Leading mark, e.g. a vendor logo.
  final Widget? icon;

  final bool disabled;

  /// Extra terms the search matches, on top of [id] and [name].
  final List<String> keywords;

  /// `efforts: true` upstream — the low / medium / high set.
  final bool usesDefaultEfforts;

  /// A custom level list; wins over [usesDefaultEfforts].
  final List<ModelSelectorEffortOption>? efforts;

  /// The levels this model supports, or null when reasoning is fixed.
  List<ModelSelectorEffortOption>? get effortOptions =>
      efforts ?? (usesDefaultEfforts ? auiDefaultEffortOptions : null);
}

/// Resolves a sticky effort id against the model it would apply to — upstream's
/// `resolveModelEffort`.
String? auiResolveModelEffort(
  List<ModelOption> models,
  String? modelId,
  String? effort,
) {
  if (effort == null) return null;
  final ModelOption? model =
      models.where((ModelOption model) => model.id == modelId).firstOrNull;
  final List<ModelSelectorEffortOption>? options = model?.effortOptions;
  if (options == null) return null;
  return options.any((ModelSelectorEffortOption o) => o.id == effort)
      ? effort
      : null;
}

/// How the trigger is painted.
enum ModelSelectorVariant { outline, ghost, muted }

/// Trigger size.
enum ModelSelectorSize { standard, sm, lg }

/// A model selector: a trigger showing the current model, and a popover with
/// search, the model list and the reasoning effort — the `model-selector`
/// element.
///
/// Upstream ships this as a compound (`Root` / `Trigger` / `Value` / `Content`
/// / `Search` / `List` / `Item` / `Effort`) driven by React context; the port
/// keeps the same behaviour in one widget because a Dart host has no element
/// merging to compose the pieces with.
class AssistantModelSelector extends StatefulWidget {
  const AssistantModelSelector({
    super.key,
    required this.models,
    this.value,
    this.defaultValue,
    this.onValueChange,
    this.effort,
    this.defaultEffort,
    this.onEffortChange,
    this.open,
    this.defaultOpen = false,
    this.onOpenChange,
    this.variant = ModelSelectorVariant.outline,
    this.size = ModelSelectorSize.standard,
    this.searchable = true,
    this.placeholder = 'Select model',
    this.showEffort = true,
  });

  final List<ModelOption> models;

  /// Bound model; when null the widget owns it from [defaultValue].
  final String? value;
  final String? defaultValue;
  final ValueChanged<String>? onValueChange;

  /// Bound effort, sticky across model switches.
  final String? effort;
  final String? defaultEffort;
  final ValueChanged<String>? onEffortChange;

  /// Bound open state.
  final bool? open;
  final bool defaultOpen;
  final ValueChanged<bool>? onOpenChange;

  final ModelSelectorVariant variant;
  final ModelSelectorSize size;

  /// Shows the search field; without it the list runs on keyboard navigation
  /// alone, as upstream's `unfiltered` mode does.
  final bool searchable;

  final String placeholder;

  /// Appends the effort name to the trigger label.
  final bool showEffort;

  @override
  State<AssistantModelSelector> createState() => _AssistantModelSelectorState();
}

class _AssistantModelSelectorState extends State<AssistantModelSelector> {
  late String? _value =
      widget.value ?? widget.defaultValue ?? widget.models.firstOrNull?.id;
  late String? _effort = widget.effort ?? widget.defaultEffort;
  late bool _open = widget.open ?? widget.defaultOpen;
  final TextEditingController _query = TextEditingController();
  final FocusNode _triggerFocus = FocusNode(debugLabel: 'model-selector');
  final OverlayPortalController _overlay = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    if (_open) {
      // The portal is not mounted yet during initState.
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverlay());
    }
  }

  @override
  void didUpdateWidget(AssistantModelSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null) _value = widget.value;
    if (widget.effort != null) _effort = widget.effort;
    if (widget.open != null && widget.open != oldWidget.open) {
      _open = widget.open!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverlay());
    }
  }

  /// The portal controller refuses to change state during build, so the
  /// overlay follows the bound open state a frame later.
  void _syncOverlay() {
    if (!mounted) return;
    if (_open) {
      _overlay.show();
    } else {
      _overlay.hide();
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _triggerFocus.dispose();
    super.dispose();
  }

  ModelOption? get _selected => widget.models
      .where((ModelOption model) => model.id == _value)
      .firstOrNull;

  List<ModelOption> get _matches {
    final String needle = _query.text.trim().toLowerCase();
    if (needle.isEmpty) return widget.models;
    return widget.models.where((ModelOption model) {
      final String haystack = <String>[
        model.id,
        model.name,
        ...model.keywords,
      ].join(' ').toLowerCase();
      return haystack.contains(needle);
    }).toList();
  }

  void _setValue(String id) {
    if (widget.value == null) setState(() => _value = id);
    widget.onValueChange?.call(id);
    _setOpen(false);
  }

  void _setEffort(String effort) {
    if (widget.effort == null) setState(() => _effort = effort);
    widget.onEffortChange?.call(effort);
  }

  void _setOpen(bool open) {
    if (widget.open == null) setState(() => _open = open);
    widget.onOpenChange?.call(open);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOverlay());
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final ModelOption? selected = _selected;
    final List<ModelSelectorEffortOption>? options = selected?.effortOptions;
    final String? effort = auiResolveModelEffort(
      widget.models,
      selected?.id,
      _effort,
    );
    final String? effortName = effort == null
        ? null
        : options
            ?.where((ModelSelectorEffortOption o) => o.id == effort)
            .firstOrNull
            ?.name;

    return OverlayPortal(
      controller: _overlay,
      overlayChildBuilder: (BuildContext context) => Positioned.fill(
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 44),
            child: Material(
              color: Colors.transparent,
              child: _Content(
                matches: _matches,
                selectedId: selected?.id,
                effort: effort,
                efforts: options,
                searchable: widget.searchable,
                query: _query,
                onQueryChanged: () => setState(() {}),
                onPick: _setValue,
                onEffort: _setEffort,
              ),
            ),
          ),
        ),
      ),
      child: Focus(
        focusNode: _triggerFocus,
        onKeyEvent: (FocusNode node, KeyEvent event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
              event.logicalKey == LogicalKeyboardKey.arrowUp) {
            // ARIA combobox: the arrows open the listbox from the trigger.
            _setOpen(true);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Semantics(
          container: true,
          button: true,
          expanded: _open,
          label: selected == null
              ? widget.placeholder
              : '${selected.name}${effortName == null ? '' : ', $effortName'}',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Clicking a combobox focuses it, which is what makes the arrows
            // open the listbox.
            onTapDown: (_) => _triggerFocus.requestFocus(),
            onTap: () => _setOpen(!_open),
            child: _Trigger(
              variant: widget.variant,
              size: widget.size,
              selected: selected,
              effortName: widget.showEffort ? effortName : null,
              placeholder: widget.placeholder,
              theme: theme,
            ),
          ),
        ),
      ),
    );
  }
}

class _Trigger extends StatelessWidget {
  const _Trigger({
    required this.variant,
    required this.size,
    required this.selected,
    required this.effortName,
    required this.placeholder,
    required this.theme,
  });

  final ModelSelectorVariant variant;
  final ModelSelectorSize size;
  final ModelOption? selected;
  final String? effortName;
  final String placeholder;
  final AssistantTheme theme;

  @override
  Widget build(BuildContext context) {
    final (double height, double padding, double fontSize) = switch (size) {
      ModelSelectorSize.sm => (32, 10, 12),
      ModelSelectorSize.standard => (36, 12, 14),
      ModelSelectorSize.lg => (40, 16, 14),
    };
    final Color fill = switch (variant) {
      ModelSelectorVariant.outline => Colors.transparent,
      ModelSelectorVariant.ghost => Colors.transparent,
      ModelSelectorVariant.muted => theme.muted,
    };

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: fill,
        border: variant == ModelSelectorVariant.outline
            ? Border.all(color: theme.border)
            : null,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (selected?.icon != null) ...<Widget>[
            SizedBox(width: 14, height: 14, child: selected!.icon),
            const SizedBox(width: 8),
          ],
          if (selected == null)
            Text(
              placeholder,
              style: TextStyle(
                fontSize: fontSize,
                height: 1.2,
                color: theme.mutedForeground,
              ),
            )
          else ...<Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                selected!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: theme.foreground,
                ),
              ),
            ),
            if (effortName != null) ...<Widget>[
              const SizedBox(width: 8),
              SizedBox(
                width: 30,
                child: Text(
                  effortName!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1.2,
                    color: theme.mutedForeground,
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(width: 8),
          Icon(
            Icons.expand_more,
            size: 16,
            color: theme.foreground.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.matches,
    required this.selectedId,
    required this.effort,
    required this.efforts,
    required this.searchable,
    required this.query,
    required this.onQueryChanged,
    required this.onPick,
    required this.onEffort,
  });

  final List<ModelOption> matches;
  final String? selectedId;
  final String? effort;
  final List<ModelSelectorEffortOption>? efforts;
  final bool searchable;
  final TextEditingController query;
  final VoidCallback onQueryChanged;
  final ValueChanged<String> onPick;
  final ValueChanged<String> onEffort;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      width: 288,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.muted
            : theme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (searchable) ...<Widget>[
            Container(
              decoration: auiField(theme, radius: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.search, size: 14, color: theme.mutedForeground),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: query,
                      onChanged: (_) => onQueryChanged(),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: theme.foreground,
                      ),
                      cursorColor: theme.foreground,
                      decoration: InputDecoration(
                        isDense: true,
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Search models',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: theme.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
          ],
          for (final ModelOption model in matches)
            _Item(
              model: model,
              selected: model.id == selectedId,
              onPick: onPick,
            ),
          if (matches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No models found.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: theme.mutedForeground,
                ),
              ),
            ),
          if (efforts != null && efforts!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Container(height: 1, color: theme.border),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Reasoning effort',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  letterSpacing: 0.4,
                  color: theme.mutedForeground,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                for (final ModelSelectorEffortOption option in efforts!)
                  Expanded(
                    child: _EffortOption(
                      option: option,
                      selected: option.id == effort,
                      onPick: onEffort,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Item extends StatefulWidget {
  const _Item({
    required this.model,
    required this.selected,
    required this.onPick,
  });

  final ModelOption model;
  final bool selected;
  final ValueChanged<String> onPick;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Semantics(
      button: true,
      enabled: !widget.model.disabled,
      selected: widget.selected,
      label: widget.model.name,
      child: MouseRegion(
        cursor: widget.model.disabled
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.model.disabled
              ? null
              : () => widget.onPick(widget.model.id),
          child: Container(
            decoration: BoxDecoration(
              color: _hovered && !widget.model.disabled
                  ? auiFg(theme, 0.05)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: widget.selected
                      ? Icon(
                          Icons.check,
                          size: 14,
                          color: auiFg(theme, 0.8),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                if (widget.model.icon != null) ...<Widget>[
                  SizedBox(width: 14, height: 14, child: widget.model.icon),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        widget.model.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: widget.model.disabled
                              ? auiFg(theme, 0.4)
                              : theme.foreground,
                        ),
                      ),
                      if (widget.model.description != null)
                        Text(
                          widget.model.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            color: theme.mutedForeground,
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
    );
  }
}

class _EffortOption extends StatelessWidget {
  const _EffortOption({
    required this.option,
    required this.selected,
    required this.onPick,
  });

  final ModelSelectorEffortOption option;
  final bool selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: option.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onPick(option.id),
        child: Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? theme.foreground : null,
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            option.name,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: selected
                  ? theme.background
                  : theme.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
