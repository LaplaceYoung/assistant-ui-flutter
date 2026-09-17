import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// How much of a quota is left, with an upgrade path — the `quota-banner`
/// element.
class AssistantQuotaBanner extends StatelessWidget {
  const AssistantQuotaBanner({
    super.key,
    required this.used,
    required this.limit,
    required this.unit,
    required this.resetsIn,
    required this.upgradeLabel,
    this.onUpgrade,
  });

  final int used;
  final int limit;

  /// What is being counted, e.g. `messages`.
  final String unit;

  /// Pre-formatted window, e.g. `3h 12m`.
  final String resetsIn;

  final String upgradeLabel;
  final VoidCallback? onUpgrade;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final int left = math.max(0, limit - used);
    final double ratio = limit == 0 ? 0 : used / limit;
    // Upstream turns the banner amber from 90% of the quota up.
    final bool tight = ratio >= 0.9;
    final Color amber =
        dark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      '$left $unit left',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: tight ? amber : theme.foreground,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'resets in $resetsIn',
                    style: auiMono(context, color: auiFg(theme, 0.3)).copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Semantics(
                label: '$unit used',
                value: '$used of $limit $unit used',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 4,
                    color: auiFg(theme, 0.06),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: math.max(0, math.min(1, ratio)),
                        child: ColoredBox(
                          color: tight ? const Color(0xFFF59E0B) : auiFg(theme, 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Text(
                    '$used of $limit used',
                    style: auiMono(context, color: auiFg(theme, 0.3)).copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  const Spacer(),
                  AuiPillButton(
                    label: upgradeLabel,
                    height: 28,
                    padding: 12,
                    variant: AuiPillButtonVariant.ink,
                    onPressed: onUpgrade,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
