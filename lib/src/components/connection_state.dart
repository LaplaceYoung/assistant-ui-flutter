import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// How the transport is doing.
enum ConnectionPhase { online, dropped, reconnecting, resumed }

/// A banner while the stream is not healthy: lost, retrying, or back — the
/// `connection-state` element.
class AssistantConnectionState extends StatelessWidget {
  const AssistantConnectionState({
    super.key,
    required this.phase,
    this.attempt,
    this.resumedTokens,
    this.onRetry,
  });

  final ConnectionPhase phase;

  /// Shown while reconnecting.
  final int? attempt;

  /// Shown after a resume.
  final int? resumedTokens;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // Upstream renders nothing at all while the link is healthy.
    if (phase == ConnectionPhase.online) return const SizedBox.shrink();
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: <Widget>[
              _Glyph(phase: phase, dark: dark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  switch (phase) {
                    ConnectionPhase.dropped =>
                      'Connection lost. The run kept going on the server.',
                    ConnectionPhase.reconnecting => 'Reconnecting',
                    ConnectionPhase.resumed =>
                      'Picked the stream back up.',
                    ConnectionPhase.online => '',
                  },
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: theme.foreground,
                  ),
                ),
              ),
              if (phase == ConnectionPhase.dropped && onRetry != null) ...<Widget>[
                const SizedBox(width: 8),
                AuiPillButton(
                  label: 'Reconnect',
                  onPressed: onRetry,
                  padding: 10,
                ),
              ],
              if (phase == ConnectionPhase.reconnecting && attempt != null) ...<Widget>[
                const SizedBox(width: 8),
                Text(
                  'attempt $attempt',
                  style: auiMono(context, color: auiFg(theme, 0.3)).copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
              if (phase == ConnectionPhase.resumed &&
                  resumedTokens != null) ...<Widget>[
                const SizedBox(width: 8),
                Text(
                  '+$resumedTokens tokens',
                  style: auiMono(context, color: auiFg(theme, 0.3)).copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.phase, required this.dark});

  final ConnectionPhase phase;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    switch (phase) {
      case ConnectionPhase.dropped:
        return Icon(
          Icons.cloud_off,
          size: 14,
          color: dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
        );
      case ConnectionPhase.reconnecting:
        return AuiSpinner(size: 14, color: auiFg(theme, 0.4));
      case ConnectionPhase.resumed:
        return const Icon(Icons.check, size: 14, color: Color(0xFF10B981));
      case ConnectionPhase.online:
        return const SizedBox.shrink();
    }
  }
}
