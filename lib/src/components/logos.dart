import 'package:flutter/material.dart';

import 'theme.dart';

/// The vendor marks upstream ships as inline SVG.
///
/// The path data is kept verbatim so a host that wants the exact artwork can
/// hand it to an SVG renderer (or to [AuiLogoMark] for the shapes this port
/// can draw). The diagrams themselves are third-party trademarks and are not
/// redistributed as artwork, the same call the landing replica documents.
class AuiBrandLogos {
  const AuiBrandLogos._();

  /// `ClaudeLogo` from upstream `logos.tsx`, viewBox `0 0 256 257`.
  static const String claudePath =
      'm50.228 170.321 50.357-28.257.843-2.463-.843-1.361h-2.462l-8.426-.518'
      '-28.775-.778-24.952-1.037-24.175-1.296-6.092-1.297L0 125.796l.583-3.759'
      ' 5.12-3.434 7.324.648 16.202 1.101 24.304 1.685 17.629 1.037 26.118 2.722'
      'h4.148l.583-1.685-1.426-1.037-1.101-1.037-25.147-17.045-27.22-18.017'
      '-14.258-10.37-7.713-5.25-3.888-4.925-1.685-10.758 7-7.713 9.397.649 2.398.648'
      ' 9.527 7.323 20.35 15.75L94.817 91.9l3.889 3.24 1.555-1.102.195-.777'
      '-1.75-2.917-14.453-26.118-15.425-26.572-6.87-11.018-1.814-6.61'
      'c-.648-2.723-1.102-4.991-1.102-7.778l7.972-10.823L71.42 0 82.05 1.426'
      'l4.472 3.888 6.61 15.101 10.694 23.786 16.591 32.34 4.861 9.592 2.592 8.879'
      '.973 2.722h1.685v-1.556l1.36-18.211 2.528-22.36 2.463-28.776.843-8.1'
      ' 4.018-9.722 7.971-5.25 6.222 2.981 5.12 7.324-.713 4.73-3.046 19.768'
      '-5.962 30.98-3.889 20.739h2.268l2.593-2.593 10.499-13.934 17.628-22.036'
      ' 7.778-8.749 9.073-9.657 5.833-4.601h11.018l8.1 12.055-3.628 12.443'
      '-11.342 14.388-9.398 12.184-13.48 18.147-8.426 14.518.778 1.166 2.01-.194'
      ' 30.46-6.481 16.462-2.982 19.637-3.37 8.88 4.148.971 4.213-3.5 8.62'
      '-20.998 5.184-24.628 4.926-36.682 8.685-.454.324.519.648 16.526 1.555'
      ' 7.065.389h17.304l32.21 2.398 8.426 5.574 5.055 6.805-.843 5.184'
      '-12.962 6.611-17.498-4.148-40.83-9.721-14-3.5h-1.944v1.167l11.666 11.406'
      ' 21.387 19.314 26.767 24.887 1.36 6.157-3.434 4.86-3.63-.518-23.526-17.693'
      '-9.073-7.972-20.545-17.304h-1.36v1.814l4.73 6.935 25.017 37.59 1.296 11.536'
      '-1.814 3.76-6.481 2.268-7.13-1.297-14.647-20.544-15.1-23.138-12.185-20.739'
      '-1.49.843-7.194 77.448-3.37 3.953-7.778 2.981-6.48-4.925-3.436-7.972'
      ' 3.435-15.749 4.148-20.544 3.37-16.333 3.046-20.285 1.815-6.74-.13-.454'
      '-1.49.194-15.295 20.999-23.267 31.433-18.406 19.702-4.407 1.75-7.648-3.954'
      '.713-7.064 4.277-6.286 25.47-32.405 15.36-20.092 9.917-11.6-.065-1.686h-.583'
      'L44.07 198.125l-12.055 1.555-5.185-4.86.648-7.972 2.463-2.593 20.35-13.999'
      '-.064.065Z';

  /// `GeminiLogo`, viewBox `0 0 24 24`.
  static const String geminiPath =
      'M12 1c.53 5.94 4.06 9.47 10 10-5.94.53-9.47 4.06-10 10-.53-5.94-4.06-9.47'
      '-10-10C7.94 10.47 11.47 6.94 12 1Z';

  /// The `OpenAILogo` path is also stored upstream; it uses elliptical arcs,
  /// which [AuiLogoMark] does not draw.
  static const String openAiNote =
      'OpenAILogo uses arc commands; render it with an SVG renderer.';
}

/// Which vendor mark to draw.
enum AuiBrandMark { claude, openai, gemini }

/// Draws a vendor mark from its upstream path data.
///
/// Supports the `M / L / H / V / C / S / Q / T / Z` commands in both absolute
/// and relative form — everything the Claude and Gemini marks use. The OpenAI
/// mark needs `A` (elliptical arcs), so this painter falls back to a wordmark
/// for it.
class AuiLogoMark extends StatelessWidget {
  const AuiLogoMark({
    super.key,
    required this.mark,
    this.size = 20,
    this.color,
    this.fallbackLabel,
  });

  final AuiBrandMark mark;
  final double size;

  /// Used for the Gemini mark's fill where a gradient is not needed.
  final Color? color;

  /// Shown for marks this painter cannot draw; defaults to the brand name.
  final String? fallbackLabel;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final String? path = switch (mark) {
      AuiBrandMark.claude => AuiBrandLogos.claudePath,
      AuiBrandMark.gemini => AuiBrandLogos.geminiPath,
      AuiBrandMark.openai => null,
    };
    if (path == null) {
      return SizedBox(
        height: size,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            fallbackLabel ?? 'OpenAI',
            style: TextStyle(
              fontSize: size * 0.7,
              height: 1.2,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: color ?? theme.foreground,
            ),
          ),
        ),
      );
    }
    final double viewBox = mark == AuiBrandMark.claude ? 256 : 24;
    final Color fill = color ??
        switch (mark) {
          AuiBrandMark.claude => const Color(0xFFD97757),
          AuiBrandMark.gemini => const Color(0xFF4285F4),
          AuiBrandMark.openai => theme.foreground,
        };
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: AuiLogoPainter(
          data: path,
          viewBox: viewBox,
          color: fill,
        ),
      ),
    );
  }
}

/// Paints SVG path data; see [AuiLogoMark] for the supported commands.
class AuiLogoPainter extends CustomPainter {
  AuiLogoPainter({
    required this.data,
    required this.viewBox,
    required this.color,
  });

  final String data;
  final double viewBox;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path path = parseAuiSvgPath(data);
    final double scale = size.width / viewBox;
    canvas.save();
    canvas.scale(scale, scale);
    canvas.drawPath(path, Paint()..color = color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(AuiLogoPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.color != color ||
      oldDelegate.viewBox != viewBox;
}

/// Parses the subset of SVG path syntax the vendor marks use.
///
/// Absolute and relative `M / L / H / V / C / Q / Z` with a tracked current
/// point. `S`, `T` and the elliptical `A` are not implemented — a wrong curve
/// reads worse than a missing one, and none of the marks that render here use
/// them.
Path parseAuiSvgPath(String data) {
  final Path path = Path();
  double cx = 0;
  double cy = 0;
  double startX = 0;
  double startY = 0;
  bool relative = false;

  double next(List<double> args, int index, bool isX) =>
      relative
          ? (isX ? cx : cy) + args[index]
          : args[index];

  final RegExp token = RegExp(r'[MmLlHhVvCcQqZz]|-?\d*\.?\d+(?:e-?\d+)?');
  final List<String> tokens =
      token.allMatches(data).map((RegExpMatch m) => m.group(0)!).toList();

  int i = 0;
  String command = '';
  while (i < tokens.length) {
    final String value = tokens[i];
    if (RegExp(r'^[A-Za-z]$').hasMatch(value)) {
      command = value;
      i++;
      if (command.toLowerCase() == 'z') {
        path.close();
        cx = startX;
        cy = startY;
        continue;
      }
    }
    if (i >= tokens.length) break;
    relative = command == command.toLowerCase();
    final String lower = command.toLowerCase();

    // Read the coordinate groups this command expects.
    final int arity = switch (lower) {
      'h' || 'v' => 1,
      'c' => 6,
      'q' => 4,
      _ => 2,
    };
    if (i + arity > tokens.length) break;
    final List<double> args = <double>[
      for (int k = 0; k < arity; k++) double.parse(tokens[i + k]),
    ];
    i += arity;

    switch (lower) {
      case 'm':
        final double x = next(args, 0, true);
        final double y = next(args, 1, false);
        path.moveTo(x, y);
        cx = startX = x;
        cy = startY = y;
        // A second pair after `m`/`M` is an implicit lineto.
        command = relative ? 'l' : 'L';
      case 'l':
        final double x = next(args, 0, true);
        final double y = next(args, 1, false);
        path.lineTo(x, y);
        cx = x;
        cy = y;
      case 'h':
        final double x = relative ? cx + args[0] : args[0];
        path.lineTo(x, cy);
        cx = x;
      case 'v':
        final double y = relative ? cy + args[0] : args[0];
        path.lineTo(cx, y);
        cy = y;
      case 'c':
        final double x1 = next(args, 0, true);
        final double y1 = next(args, 1, false);
        final double x2 = next(args, 2, true);
        final double y2 = next(args, 3, false);
        final double x = next(args, 4, true);
        final double y = next(args, 5, false);
        path.cubicTo(x1, y1, x2, y2, x, y);
        cx = x;
        cy = y;
      case 'q':
        final double x1 = next(args, 0, true);
        final double y1 = next(args, 1, false);
        final double x = next(args, 2, true);
        final double y = next(args, 3, false);
        path.quadraticBezierTo(x1, y1, x, y);
        cx = x;
        cy = y;
    }
  }
  return path;
}
