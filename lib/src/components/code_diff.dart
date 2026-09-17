import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// What a diff line is.
enum DiffKind { context, added, removed }

/// One line of a diff.
@immutable
class DiffLine {
  const DiffLine({required this.kind, required this.text});

  final DiffKind kind;
  final String text;
}

/// A unified diff with the file name and its counts — the `code-diff`
/// element.
class AssistantCodeDiff extends StatelessWidget {
  const AssistantCodeDiff({
    super.key,
    required this.filename,
    required this.additions,
    required this.deletions,
    required this.lines,
    this.cycle = 0,
  });

  final String filename;
  final int additions;
  final int deletions;
  final List<DiffLine> lines;

  /// Bump to replay the row entrance.
  final int cycle;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color green =
        dark ? const Color(0xFF34D399) : const Color(0xFF059669);
    final Color red = dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    final TextStyle code = theme.code(context).copyWith(fontSize: 12);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
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
                        filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: code.copyWith(color: auiFg(theme, 0.9)),
                      ),
                    ),
                    Text(
                      '+$additions',
                      style: auiMono(context, color: green),
                    ),
                    Text(' ', style: auiMono(context)),
                    Text(
                      '−$deletions',
                      style: auiMono(context, color: red),
                    ),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final (int index, DiffLine line) in lines.indexed)
                      Container(
                        key: ValueKey<String>('$cycle-$index'),
                        color: switch (line.kind) {
                          DiffKind.context => null,
                          DiffKind.added => const Color(0xFF10B981)
                              .withValues(alpha: 0.10),
                          DiffKind.removed => const Color(0xFFEF4444)
                              .withValues(alpha: 0.10),
                        },
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(
                              width: 16,
                              child: Text(
                                switch (line.kind) {
                                  DiffKind.context => '',
                                  DiffKind.added => '+',
                                  DiffKind.removed => '−',
                                },
                                style: code.copyWith(
                                  color: auiFg(theme, 0.45),
                                ),
                              ),
                            ),
                            Text(
                              line.text,
                              style: code.copyWith(
                                color: switch (line.kind) {
                                  DiffKind.context => auiFg(theme, 0.45),
                                  DiffKind.added => dark
                                      ? const Color(0xFF6EE7B7)
                                      : const Color(0xFFB45309),
                                  DiffKind.removed => dark
                                      ? const Color(0xFFFCA5A5)
                                      : const Color(0xFFB91C1C),
                                },
                              ),
                            ),
                          ],
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
