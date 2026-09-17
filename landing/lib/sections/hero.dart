import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../landing_theme.dart';
import '../widgets.dart';

/// Hero: the pill badge, the 72px display heading, the sub-copy, the two
/// calls to action and the stats row, with the dotted bubble illustration on
/// the right.
///
/// Type metrics come from the live page: 72px / weight 500 / line-height
/// 74.88px / letter-spacing -1.08px, heading top at 160px, left gutter 96px.
class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    // The live page keeps `px-4` under md and widens the hero gutter to 96px
    // at desktop widths; the heading steps 72 → 48 → 36 with the breakpoints.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        // The live hero keeps the page frame (max-w-7xl + px-4), so its content
        // edge lines up with every other section.
        final double headingSize = width >= 1024
            ? 72
            : (width >= 768 ? 44 : 36);
        final bool showArt = width >= 980;
        return ContentColumn(
          child: Padding(
            padding: EdgeInsets.only(
              top: width >= 768 ? 112 : 80,
              bottom: 32,
            ),
            child: Stack(
              // The art is positioned; everything else stays on the left edge.
              alignment: Alignment.topLeft,
              children: <Widget>[
                // Full width, or the column shrinks to its widest child and a
                // loose parent centres it instead of leaving it at the edge.
                SizedBox(
                  width: double.infinity,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // The port says what it is, rather than dressing up as the
                    // React original.
                    const _PortBadge(),
                    const SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        // `max-w-[20ch]` at 72px comes out at 897px.
                        maxWidth: showArt ? headingSize * 12.46 : width,
                      ),
                      child: Text(
                        // The live heading balances to this break at desktop
                        // widths (`text-balance`); the break is fixed here.
                        headingSize >= 72
                            ? 'The frontend library\nfor AI agents.'
                            : 'The frontend library for AI agents.',
                        style: LandingText.display(context, size: headingSize)
                            .copyWith(color: colors.foreground),
                      ),
                    ),
                    SizedBox(height: headingSize >= 72 ? 12 : 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 367),
                      child: Text(
                        'Primitives and a runtime for production chat. '
                        'Any backend, through adapters.',
                        style: LandingText.lead(context).copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        LandingButton(
                          label: 'Read the docs',
                          solid: true,
                          onPressed: () {},
                        ),
                        const CommandChip(command: 'npx assistant-ui init'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _StatsRow(),
                  ],
                ),
                ),
                if (showArt)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: _DottedBubbles(colors: colors, size: 260),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    final TextStyle style = LandingText.small(context).copyWith(
      color: colors.mutedForeground,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 6,
      children: <Widget>[
        Text('12.2k ', style: style.copyWith(color: colors.foreground)),
        Text('GitHub stars', style: style),
        _dot(style),
        Text('1.3M ', style: style.copyWith(color: colors.foreground)),
        Text('weekly downloads', style: style),
        _dot(style),
        Text('Backed by ', style: style),
        Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6600),
            borderRadius: BorderRadius.circular(3),
          ),
          child: const Text(
            'Y',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text('Combinator', style: style.copyWith(color: colors.foreground)),
      ],
    );
  }

  Widget _dot(TextStyle style) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('·', style: style),
      );
}

/// The dotted chat-bubble illustration: two overlapping rounded bubbles drawn
/// as a dot matrix, matching the site's pixel-art treatment.
class _DottedBubbles extends StatelessWidget {
  const _DottedBubbles({required this.colors, required this.size});

  final LandingColors colors;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size, size * 0.82),
        painter: _DottedBubblesPainter(color: colors.foreground.withValues(alpha: 0.55)),
      );
}

class _DottedBubblesPainter extends CustomPainter {
  _DottedBubblesPainter({required this.color});

  final Color color;
  static final Map<int, ui.Image> _dotTextures = <int, ui.Image>{};

  static const double _spacing = 6.5;
  static const double _dotRadius = 1.05;

  /// A tile holding one dot in [color], repeated through an ImageShader to
  /// fill a stroked path — cheaper and crisper than sampling the grid by hand.
  static ui.Image _texture(Color color) {
    final int key = color.toARGB32();
    final ui.Image? cached = _dotTextures[key];
    if (cached != null) return cached;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    canvas.drawCircle(
      const Offset(_spacing / 2, _spacing / 2),
      _dotRadius,
      Paint()..color = color,
    );
    final ui.Image image = recorder
        .endRecording()
        .toImageSync(_spacing.ceil(), _spacing.ceil());
    _dotTextures[key] = image;
    return image;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double stroke = math.max(10, w * 0.075);

    Path bubble(Rect rect, {required double radius, bool tailRight = true}) {
      final Path path = Path()
        ..addRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        );
      // Speech-bubble tail: a small square notch on the bottom corner.
      final double tail = rect.width * 0.14;
      path.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            tailRight ? rect.right - tail * 1.6 : rect.left + tail * 0.4,
            rect.bottom - stroke * 0.4,
            tail,
            tail,
          ),
          Radius.circular(tail * 0.3),
        ),
      );
      return path;
    }

    final Rect back = Rect.fromLTWH(stroke, stroke, w * 0.66, h * 0.62);
    final Rect front = Rect.fromLTWH(w * 0.28, h * 0.3, w * 0.66, h * 0.62);

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round
      ..shader = ImageShader(
        _texture(color),
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
      );

    canvas.drawPath(
      bubble(back, radius: w * 0.16, tailRight: false),
      paint,
    );
    canvas.drawPath(
      bubble(front, radius: w * 0.16, tailRight: true),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DottedBubblesPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// The identity pill: what this page is, and the dependency that gets it.
class _PortBadge extends StatelessWidget {
  const _PortBadge();

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.flutter_dash, size: 15, color: colors.foreground),
          const SizedBox(width: 7),
          Text(
            'Flutter port of assistant-ui — no React underneath',
            style: LandingText.small(context).copyWith(
              color: colors.mutedForeground,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
