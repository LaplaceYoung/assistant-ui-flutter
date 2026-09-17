import 'package:flutter/material.dart';

import 'heat_calendar.dart';

/// The GitHub palette upstream hardcodes in `heat-graph.tsx`, level 0 first.
/// These stay light in dark mode: upstream passes them straight to the
/// `heat-graph` package's `colorScale`.
const List<Color> auiHeatGraphColors = <Color>[
  Color(0xFFEBEDF0),
  Color(0xFFC6D7F9),
  Color(0xFF8FB0F3),
  Color(0xFF5888E8),
  Color(0xFF2563EB),
];

/// Standalone contribution calendar with month labels, day labels, a legend
/// and per-cell tooltips — the `heat-graph` element.
class AssistantHeatGraph extends StatelessWidget {
  const AssistantHeatGraph({
    super.key,
    required this.data,
    required this.start,
    required this.end,
    this.cellSize = 11,
  });

  final List<AuiHeatCell> data;
  final DateTime start;
  final DateTime end;

  /// Upstream lets the cells scale with the container (`aspect-square w-full`);
  /// a fixed size keeps the column count honest in a chat bubble.
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    return AuiHeatCalendar(
      data: data,
      start: start,
      end: end,
      cellSize: cellSize,
      levelColors: auiHeatGraphColors,
      showMonthLabels: true,
      showDayLabels: true,
      showLegend: true,
      showTooltip: true,
      dayLabelParity: 0,
    );
  }
}
