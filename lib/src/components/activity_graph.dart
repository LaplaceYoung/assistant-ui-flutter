import 'package:flutter/material.dart';

import 'heat_calendar.dart';
import 'surfaces.dart';
import 'theme.dart';

/// Contribution calendar with the range's total — the `activity-graph`
/// element.
class AssistantActivityGraph extends StatelessWidget {
  const AssistantActivityGraph({
    super.key,
    required this.data,
    required this.start,
    required this.end,
    required this.title,
    required this.total,
  });

  final List<AuiHeatCell> data;
  final DateTime start;
  final DateTime end;
  final String title;

  /// Pre-formatted total, e.g. `412 runs`.
  final String total;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: theme.foreground,
                      ),
                    ),
                  ),
                  Text(
                    total,
                    style: auiMono(context, color: auiFg(theme, 0.35))
                        .copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AuiHeatCalendar(
                data: data,
                start: start,
                end: end,
                showDayLabels: true,
                showLegend: true,
                dayLabelParity: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
