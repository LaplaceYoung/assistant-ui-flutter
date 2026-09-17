import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One row of a spec sheet.
@immutable
class SpecRow {
  const SpecRow({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;

  /// Draws the value in the strong foreground.
  final bool emphasis;
}

/// Key–value spec card, revealed row by row as a run streams — the
/// `spec-sheet` element.
class AssistantSpecSheet extends StatelessWidget {
  const AssistantSpecSheet({
    super.key,
    required this.title,
    required this.rows,
    required this.visibleCount,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<SpecRow> rows;

  /// How many rows have been revealed, in order.
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final List<SpecRow> shown = rows.take(visibleCount).toList();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: theme.foreground,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: auiFg(theme, 0.45),
                  ),
                ),
              const SizedBox(height: 12),
              for (final (int index, SpecRow row) in shown.indexed)
                Container(
                  decoration: BoxDecoration(
                    border: index == 0
                        ? null
                        : Border(top: BorderSide(color: auiFg(theme, 0.06))),
                  ),
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 6, bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      SizedBox(
                        width: 96,
                        child: Text(
                          row.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: auiMono(context, color: auiFg(theme, 0.35)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          row.value,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            fontWeight: row.emphasis
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: auiFg(theme, row.emphasis ? 0.95 : 0.7),
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
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
