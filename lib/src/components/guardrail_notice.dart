import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// A policy stopped the request, with safer things to try instead — the
/// `guardrail-notice` element.
class AssistantGuardrailNotice extends StatelessWidget {
  const AssistantGuardrailNotice({
    super.key,
    required this.title,
    required this.explanation,
    required this.policy,
    this.alternatives = const <String>[],
    this.onPick,
  });

  final String title;
  final String explanation;

  /// Policy id shown on the right, e.g. `safety.self-harm`.
  final String policy;

  final List<String> alternatives;

  /// Reports the chosen alternative.
  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color amber =
        dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 20),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.shield_outlined, size: 14, color: amber),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: theme.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    policy,
                    style: auiMono(context, color: auiFg(theme, 0.3)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                explanation,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: auiFg(theme, 0.6),
                ),
              ),
              if (alternatives.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'try instead',
                  style: auiMono(context, color: auiFg(theme, 0.3)),
                ),
                const SizedBox(height: 4),
                for (final String alternative in alternatives)
                  _Alternative(alternative: alternative, onPick: onPick),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Alternative extends StatefulWidget {
  const _Alternative({required this.alternative, required this.onPick});

  final String alternative;
  final ValueChanged<String>? onPick;

  @override
  State<_Alternative> createState() => _AlternativeState();
}

class _AlternativeState extends State<_Alternative> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return MouseRegion(
      cursor: widget.onPick == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPick == null
            ? null
            : () => widget.onPick!(widget.alternative),
        child: Container(
          decoration: BoxDecoration(
            color: _hovered && widget.onPick != null
                ? auiFg(theme, 0.04)
                : null,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(
            widget.alternative,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: auiFg(theme, _hovered ? 0.95 : 0.7),
            ),
          ),
        ),
      ),
    );
  }
}
