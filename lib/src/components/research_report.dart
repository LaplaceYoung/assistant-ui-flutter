import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// Where a report section stands.
enum SectionState { pending, writing, done }

/// One section of a research report.
@immutable
class ReportSection {
  const ReportSection({
    required this.id,
    required this.heading,
    required this.state,
    this.sources = 0,
    this.preview,
  });

  final String id;
  final String heading;
  final SectionState state;

  /// How many sources fed this section.
  final int sources;

  /// First lines, shown once the section has text.
  final String? preview;
}

/// A report being written, section by section — the `research-report`
/// element.
class AssistantResearchReport extends StatelessWidget {
  const AssistantResearchReport({
    super.key,
    required this.title,
    required this.sections,
    required this.sourcesRead,
  });

  final String title;
  final List<ReportSection> sections;
  final int sourcesRead;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
    final int done = sections
        .where((ReportSection section) => section.state == SectionState.done)
        .length;

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
              Text(
                '$done/${sections.length} sections · $sourcesRead sources read',
                style: auiMono(context, color: auiFg(theme, 0.3)).copyWith(
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final (int index, ReportSection section) in sections.indexed)
                Container(
                  decoration: BoxDecoration(
                    border: index == 0
                        ? null
                        : Border(top: BorderSide(color: auiFg(theme, 0.06))),
                  ),
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 8, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: Center(
                              child: switch (section.state) {
                                SectionState.done => Icon(
                                    Icons.check,
                                    size: 12,
                                    color: auiFg(theme, 0.35),
                                  ),
                                SectionState.writing =>
                                  AuiSpinner(size: 12, color: blue),
                                SectionState.pending => Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: auiFg(theme, 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              section.heading,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                color: section.state == SectionState.pending
                                    ? auiFg(theme, 0.35)
                                    : auiFg(theme, 0.85),
                              ),
                            ),
                          ),
                          if (section.sources > 0) ...<Widget>[
                            const SizedBox(width: 8),
                            Text(
                              '${section.sources} src',
                              style:
                                  auiMono(context, color: auiFg(theme, 0.25)),
                            ),
                          ],
                        ],
                      ),
                      if (section.preview != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 22, top: 4),
                          child: Text(
                            section.preview!,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: auiFg(theme, 0.5),
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
