import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One option column in an [AssistantComparisonCard].
@immutable
class ComparisonOption {
  const ComparisonOption({
    required this.id,
    required this.name,
    required this.headline,
    this.traits = const <String?>[],
  });

  final String id;
  final String name;
  final String headline;

  /// One entry per trait label; null or empty means the option lacks it.
  final List<String?> traits;
}

/// Two or more options side by side with the pick called out — the
/// `comparison-card` element.
class AssistantComparisonCard extends StatelessWidget {
  const AssistantComparisonCard({
    super.key,
    required this.traitLabels,
    required this.options,
    required this.recommendedId,
    required this.reason,
  });

  final List<String> traitLabels;
  final List<ComparisonOption> options;

  /// Option to mark with `pick`.
  final String recommendedId;

  final String reason;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final ComparisonOption option in options)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: option == options.last ? 0 : 8,
                        ),
                        child: _Option(
                          option: option,
                          traitLabels: traitLabels,
                          recommended: option.id == recommendedId,
                          blue: blue,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                reason,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: auiFg(theme, 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.option,
    required this.traitLabels,
    required this.recommended,
    required this.blue,
  });

  final ComparisonOption option;
  final List<String> traitLabels;
  final bool recommended;
  final Color blue;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: recommended
            ? blue.withValues(alpha: 0.07)
            : auiFieldColor(theme),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Flexible(
                child: Text(
                  option.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: theme.foreground,
                  ),
                ),
              ),
              if (recommended) ...<Widget>[
                const SizedBox(width: 6),
                Text('pick', style: auiMono(context, color: blue)),
              ],
            ],
          ),
          Text(
            option.headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: auiFg(theme, 0.45),
            ),
          ),
          const SizedBox(height: 8),
          for (final (int index, String label) in traitLabels.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: <Widget>[
                  Icon(
                    index < option.traits.length &&
                            (option.traits[index] ?? '').isNotEmpty
                        ? Icons.check
                        : Icons.remove,
                    size: 12,
                    color: index < option.traits.length &&
                            (option.traits[index] ?? '').isNotEmpty
                        ? const Color(0xFF10B981)
                        : auiFg(theme, 0.2),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      index < option.traits.length &&
                              (option.traits[index] ?? '').isNotEmpty
                          ? option.traits[index]!
                          : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: auiFg(
                          theme,
                          index < option.traits.length &&
                                  (option.traits[index] ?? '').isNotEmpty
                              ? 0.65
                              : 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
