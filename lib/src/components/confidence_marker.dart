import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'motion.dart';
import 'theme.dart';

/// How well a claim is supported.
enum Confidence { grounded, inferred, uncertain }

/// One claim in an [AssistantConfidenceMarker].
@immutable
class ConfidenceClaim {
  const ConfidenceClaim({
    required this.id,
    required this.text,
    required this.confidence,
    required this.basis,
  });

  final String id;
  final String text;
  final Confidence confidence;

  /// Where the claim comes from, shown while it is hovered.
  final String basis;
}

/// Prose whose claims are underlined by how well they are supported, with the
/// basis shown on hover — the `confidence-marker` element.
class AssistantConfidenceMarker extends StatelessWidget {
  const AssistantConfidenceMarker({
    super.key,
    required this.claims,
    this.hoveredId = '',
    this.onHover,
    this.textStyle,
  });

  final List<ConfidenceClaim> claims;

  /// Claim whose basis is shown; empty for none.
  final String hoveredId;

  /// Reports the hovered claim id, and `''` when the pointer leaves.
  final ValueChanged<String>? onHover;

  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final ConfidenceClaim? hovered = claims
        .where((ConfidenceClaim claim) => claim.id == hoveredId)
        .firstOrNull;
    final TextStyle base = textStyle ??
        TextStyle(fontSize: 13.5, height: 1.55, color: theme.foreground);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                for (final ConfidenceClaim claim in claims)
                  _Claim(
                    claim: claim,
                    active: claim.id == hoveredId,
                    style: base,
                    onHover: onHover,
                  ),
              ],
            ),
            SizedBox(
              height: 36,
              child: Align(
                alignment: Alignment.topLeft,
                child: hovered == null
                    ? const SizedBox.shrink()
                    : _Basis(claim: hovered),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Claim extends StatelessWidget {
  const _Claim({
    required this.claim,
    required this.active,
    required this.style,
    required this.onHover,
  });

  final ConfidenceClaim claim;
  final bool active;
  final TextStyle style;
  final ValueChanged<String>? onHover;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    // Note: `text-underline-offset` has no Flutter equivalent; the 2px
    // decoration thickness and the dotted style for unverified claims match.
    final Color decoration = switch (claim.confidence) {
      Confidence.grounded =>
        (dark ? const Color(0xFF34D399) : const Color(0xFF10B981))
            .withValues(alpha: 0.5),
      Confidence.inferred =>
        const Color(0xFFF59E0B).withValues(alpha: 0.6),
      Confidence.uncertain =>
        (dark ? const Color(0xFFF87171) : const Color(0xFFEF4444))
            .withValues(alpha: 0.5),
    };
    final TextStyle claimStyle = style.copyWith(
      color: auiFg(theme, active ? 0.95 : 0.7),
      decoration: TextDecoration.underline,
      decorationColor: decoration,
      decorationThickness: 2,
      decorationStyle: claim.confidence == Confidence.uncertain
          ? TextDecorationStyle.dotted
          : TextDecorationStyle.solid,
    );

    return MouseRegion(
      cursor: SystemMouseCursors.help,
      onEnter: (_) => onHover?.call(claim.id),
      onExit: (_) => onHover?.call(''),
      child: GestureDetector(
        onTap: onHover == null ? null : () => onHover!(claim.id),
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(claim.text, style: claimStyle),
        ),
      ),
    );
  }
}

class _Basis extends StatelessWidget {
  const _Basis({required this.claim});

  final ConfidenceClaim claim;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final Color dot = switch (claim.confidence) {
      Confidence.grounded => const Color(0xFF10B981),
      Confidence.inferred => const Color(0xFFF59E0B),
      Confidence.uncertain => const Color(0xFFEF4444),
    };
    final String label = switch (claim.confidence) {
      Confidence.grounded => 'from a source',
      Confidence.inferred => 'inferred',
      Confidence.uncertain => 'unverified',
    };
    // `fade-in zoom-in-95 animate-in duration-150`: the basis pill grows in
    // from the claim it belongs to.
    return AuiZoomFadeIn(
      alignment: Alignment.bottomCenter,
      child: Container(
      decoration: BoxDecoration(
        color: theme.background,
        border: Border.all(color: theme.border.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '$label · ${claim.basis}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: auiMono(context, color: auiFg(theme, 0.55)),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Local alpha helper: the surfaces helpers live in `surfaces.dart`, which
/// this element deliberately does not depend on to keep the underline styling
/// in one place.
Color auiFgAlpha(AssistantTheme theme, double alpha) =>
    theme.foreground.withValues(alpha: alpha);
