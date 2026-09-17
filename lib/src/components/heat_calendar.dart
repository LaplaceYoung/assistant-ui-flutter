import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One day of activity in the calendar.
@immutable
class AuiHeatCell {
  const AuiHeatCell({required this.date, required this.count});

  final DateTime date;
  final int count;
}

/// GitHub-style contribution calendar shared by the `activity-graph` and
/// `heat-graph` elements: columns are weeks, rows are the days of the week,
/// and the level of each cell comes from the distribution of the counts.
///
/// Upstream delegates this layout to the `heat-graph` React package; the
/// quantile bucketing here matches its documented default (five steps, level 0
/// for a zero count).
class AuiHeatCalendar extends StatelessWidget {
  const AuiHeatCalendar({
    super.key,
    required this.data,
    required this.start,
    required this.end,
    this.cellSize = 9,
    this.gap = 3,
    this.levelColors,
    this.showMonthLabels = false,
    this.showDayLabels = true,
    this.showLegend = false,
    this.showTooltip = false,
    this.dayLabelParity = 1,
    this.weekStart = DateTime.monday,
  });

  final List<AuiHeatCell> data;
  final DateTime start;
  final DateTime end;

  final double cellSize;
  final double gap;

  /// Five colors, level 0 first. Defaults to the theme's foreground tint
  /// ladder, which is what the activity graph uses.
  final List<Color>? levelColors;

  final bool showMonthLabels;
  final bool showDayLabels;
  final bool showLegend;
  final bool showTooltip;

  /// Which rows carry a day label; upstream labels odd rows in the activity
  /// graph and even rows in the heat graph.
  final int dayLabelParity;

  /// First day of a week, `DateTime.monday` or `DateTime.sunday`.
  final int weekStart;

  static const List<String> _dayShort = <String>[
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  static const List<String> _monthShort = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  int get _weekStartJs => weekStart == DateTime.sunday ? 0 : 1;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final List<Color> colors = levelColors ?? _defaultColors(theme);
    final Map<int, int> byDay = <int, int>{
      for (final AuiHeatCell cell in data)
        DateTime.utc(cell.date.year, cell.date.month, cell.date.day)
                .millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay: cell.count,
    };
    final List<int> positives = byDay.values.where((int c) => c > 0).toList()
      ..sort();

    int levelOf(int count) {
      if (count <= 0 || positives.isEmpty) return 0;
      final int q1 = positives[(positives.length * 0.25).floor()];
      final int q2 = positives[(positives.length * 0.5).floor()];
      final int q3 = positives[(positives.length * 0.75).floor()];
      if (count >= q3 && count > q2) return 4;
      if (count >= q2 && count > q1) return 3;
      if (count >= q1) return 2;
      return 1;
    }

    final DateTime first = DateTime.utc(start.year, start.month, start.day);
    final DateTime last = DateTime.utc(end.year, end.month, end.day);
    // Align the first column to the start of its week.
    final int firstWeekday = first.weekday % 7; // Dart: Mon=1..Sun=7
    final int offset = (firstWeekday - _weekStartJs) % 7;
    final DateTime gridStart = first.subtract(Duration(days: offset));
    final int weeks =
        ((last.difference(gridStart).inDays + offset) / 7).ceil().clamp(1, 200);

    final List<Widget> columns = <Widget>[];
    for (int week = 0; week < weeks; week++) {
      final List<Widget> days = <Widget>[];
      for (int row = 0; row < 7; row++) {
        final DateTime date = gridStart.add(Duration(days: week * 7 + row));
        final bool inside =
            !date.isBefore(first) && !date.isAfter(last.add(const Duration(days: 0)));
        if (!inside) {
          days.add(SizedBox(width: cellSize, height: cellSize + gap));
          continue;
        }
        final int count = byDay[
                date.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay] ??
            0;
        final int level = levelOf(count);
        Widget cell = Container(
          width: cellSize,
          height: cellSize,
          decoration: BoxDecoration(
            color: colors[level.clamp(0, colors.length - 1)],
            borderRadius: BorderRadius.circular(2),
          ),
        );
        if (showTooltip) {
          cell = Tooltip(
            message: '$count contributions on ${_formatDate(date)}',
            child: cell,
          );
        }
        days.add(Semantics(
          label: '$count on ${_formatDate(date)}',
          child: Padding(
            padding: EdgeInsets.only(bottom: row == 6 ? 0 : gap),
            child: cell,
          ),
        ));
      }
      columns.add(Column(mainAxisSize: MainAxisSize.min, children: days));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showMonthLabels) ...<Widget>[
          SizedBox(
            height: 20,
            child: CustomPaint(
              painter: _MonthLabelPainter(
                weeks: weeks,
                gridStart: gridStart,
                columnWidth: cellSize + gap,
                label: (int week) {
                  final DateTime weekStartDate =
                      gridStart.add(Duration(days: week * 7));
                  if (week == 0) return _monthShort[weekStartDate.month - 1];
                  final DateTime previous =
                      weekStartDate.subtract(const Duration(days: 7));
                  if (previous.month != weekStartDate.month) {
                    return _monthShort[weekStartDate.month - 1];
                  }
                  return null;
                },
                style: auiMono(context, color: auiFg(theme, 0.35)),
              ),
            ),
          ),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (showDayLabels) ...<Widget>[
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int row = 0; row < 7; row++)
                    SizedBox(
                      height: cellSize,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: row == 6 ? 0 : gap),
                        child: Text(
                          row % 2 == dayLabelParity
                              // The row's weekday, whatever the week start is.
                              ? _dayShort[gridStart
                                      .add(Duration(days: row))
                                      .weekday -
                                  1]
                              : '',
                          style: auiMono(context, color: auiFg(theme, 0.25)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final (int index, Widget column) in columns.indexed)
                      Padding(
                        padding: EdgeInsets.only(
                          right: index == columns.length - 1 ? 0 : gap,
                        ),
                        child: column,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (showLegend) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              Text('less', style: auiMono(context, color: auiFg(theme, 0.25))),
              const SizedBox(width: 6),
              for (final Color color in colors) ...<Widget>[
                Container(
                  width: cellSize,
                  height: cellSize,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text('more', style: auiMono(context, color: auiFg(theme, 0.25))),
            ],
          ),
        ],
      ],
    );
  }

  List<Color> _defaultColors(AssistantTheme theme) {
    final bool dark = theme.brightness == Brightness.dark;
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
    return <Color>[
      auiFg(theme, 0.06),
      blue.withValues(alpha: 0.25),
      blue.withValues(alpha: 0.45),
      blue.withValues(alpha: 0.7),
      blue,
    ];
  }

  static String _formatDate(DateTime date) {
    const List<String> months = _monthShort;
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _MonthLabelPainter extends CustomPainter {
  const _MonthLabelPainter({
    required this.weeks,
    required this.gridStart,
    required this.columnWidth,
    required this.label,
    required this.style,
  });

  final int weeks;
  final DateTime gridStart;
  final double columnWidth;
  final String? Function(int week) label;
  final TextStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    for (int week = 0; week < weeks; week++) {
      final String? text = label(week);
      if (text == null) continue;
      final TextPainter painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      final double x = math.min(
        week * columnWidth,
        math.max(0, size.width - painter.width),
      );
      painter.paint(canvas, Offset(x, 0));
    }
  }

  @override
  bool shouldRepaint(_MonthLabelPainter oldDelegate) =>
      oldDelegate.weeks != weeks || oldDelegate.gridStart != gridStart;
}
