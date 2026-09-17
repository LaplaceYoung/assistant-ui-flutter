import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One model row of an [AssistantDataTable].
@immutable
class ModelUsage {
  const ModelUsage({
    required this.name,
    required this.context,
    required this.cost,
  });

  final String name;

  /// Context window, pre-formatted.
  final String context;

  /// Cost, pre-formatted.
  final String cost;
}

/// Model usage as a table, with a glyph per row — the `data-table` element.
class AssistantDataTable extends StatelessWidget {
  const AssistantDataTable({
    super.key,
    required this.rows,
    this.cycle = 0,
  });

  final List<ModelUsage> rows;

  /// Bump to replay the row entrance animation.
  final int cycle;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Model',
                        style: auiMono(context, color: auiFg(theme, 0.35)),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        'Context',
                        textAlign: TextAlign.end,
                        style: auiMono(context, color: auiFg(theme, 0.35)),
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text(
                        'Cost',
                        textAlign: TextAlign.end,
                        style: auiMono(context, color: auiFg(theme, 0.35)),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: auiFg(theme, 0.06),
              ),
              KeyedSubtree(
                key: ValueKey<int>(cycle),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final ModelUsage row in rows) _Row(row: row),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({required this.row});

  final ModelUsage row;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        color: _hovered ? auiFg(theme, 0.03) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: auiFg(theme, 0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                widget.row.name.isEmpty ? '?' : widget.row.name[0],
                style: TextStyle(
                  fontSize: 9,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: auiFg(theme, 0.45),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.row.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: auiFg(theme, 0.9),
                ),
              ),
            ),
            SizedBox(
              width: 64,
              child: Text(
                widget.row.context,
                textAlign: TextAlign.end,
                style: auiMono(context, color: auiFg(theme, 0.55)).copyWith(
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 64,
              child: Text(
                widget.row.cost,
                textAlign: TextAlign.end,
                style: auiMono(context, color: auiFg(theme, 0.55)).copyWith(
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
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
