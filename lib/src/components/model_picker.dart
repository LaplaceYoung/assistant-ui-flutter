import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One model the picker offers.
@immutable
class PickableModel {
  const PickableModel({
    required this.id,
    required this.name,
    required this.family,
    required this.context,
    required this.price,
    this.capabilities = const <String>[],
  });

  final String id;
  final String name;

  /// Grouping header, e.g. `OpenAI`.
  final String family;

  final String context;
  final String price;

  final List<String> capabilities;
}

/// Models grouped by family, with the current one checked — the
/// `model-picker` element.
class AssistantModelPicker extends StatelessWidget {
  const AssistantModelPicker({
    super.key,
    required this.models,
    required this.selectedId,
    this.onSelect,
  });

  final List<PickableModel> models;
  final String selectedId;

  /// Reports a pick; without it the rows are inert.
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final List<String> families = <String>[];
    for (final PickableModel model in models) {
      if (!families.contains(model.family)) families.add(model.family);
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final String family in families) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Text(
                    family,
                    style: auiMono(context, color: auiFg(theme, 0.3)),
                  ),
                ),
                for (final PickableModel model in models
                    .where((PickableModel model) => model.family == family))
                  _Row(
                    model: model,
                    selected: model.id == selectedId,
                    onSelect: onSelect,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    required this.model,
    required this.selected,
    required this.onSelect,
  });

  final PickableModel model;
  final bool selected;
  final ValueChanged<String>? onSelect;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool tappable = widget.onSelect != null;
    return Semantics(
      button: tappable,
      selected: widget.selected,
      label: widget.model.name,
      child: MouseRegion(
        cursor: tappable ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tappable ? () => widget.onSelect!(widget.model.id) : null,
          child: Container(
            decoration: BoxDecoration(
              color: widget.selected
                  ? auiFg(theme, 0.06)
                  : (_hovered && tappable ? auiFg(theme, 0.035) : null),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: widget.selected
                      ? Icon(
                          Icons.check,
                          size: 14,
                          color: auiFg(theme, 0.7),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
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
                          fontSize: 13.5,
                          height: 1.3,
                          color: theme.foreground,
                        ),
                      ),
                      if (widget.model.capabilities.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: <Widget>[
                            for (final String capability
                                in widget.model.capabilities)
                              Container(
                                decoration: auiField(theme, radius: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                child: Text(
                                  capability,
                                  style: auiMono(
                                    context,
                                    color: auiFg(theme, 0.45),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      widget.model.context,
                      style: auiMono(context, color: auiFg(theme, 0.35))
                          .copyWith(
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.model.price,
                      style: auiMono(context, color: auiFg(theme, 0.25))
                          .copyWith(
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
