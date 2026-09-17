import 'dart:async';

import 'package:flutter/material.dart';

import '../landing_theme.dart';
import '../widgets.dart';

/// One primitive in the anatomy: the code lines that belong to it and the
/// caption the live page shows while it is active.
enum AnatomyPart { root, viewport, messages, scroll, composer }

extension on AnatomyPart {
  String get label => switch (this) {
        AnatomyPart.root => 'Root',
        AnatomyPart.viewport => 'Viewport',
        AnatomyPart.messages => 'Messages',
        AnatomyPart.scroll => 'Scroll to bottom',
        AnatomyPart.composer => 'Composer',
      };

  String get caption => switch (this) {
        AnatomyPart.root =>
          'Owns the runtime context. Everything composes inside.',
        AnatomyPart.viewport =>
          'The scroll surface. Follows the stream until the user takes over.',
        AnatomyPart.messages =>
          'Renders every turn through your components, by role.',
        AnatomyPart.scroll =>
          'Appears once you scroll away. One press back to live.',
        AnatomyPart.composer => 'Input, attachments, dictation, send.',
      };
}

/// `THE PRIMITIVES` — "Yours to reshape." with the composable-thread sample
/// and the anatomy that walks its parts.
class PrimitivesSection extends StatelessWidget {
  const PrimitivesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return ContentColumn(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Eyebrow('The primitives'),
            const SizedBox(height: 18),
            Text(
              'Yours to reshape.',
              style: LandingText.sectionTitle(context).copyWith(
                color: colors.foreground,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text(
                'Every part is a component you compose; the CLI copies the UI '
                'source into your repo.',
                style: LandingText.lead(context).copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            ),
            const SizedBox(height: 30),
            const _Anatomy(),
          ],
        ),
      ),
    );
  }
}

/// The interactive anatomy: the sample on the left, the schematic on the
/// right, and the caption for whichever part is lit. It cycles on its own
/// every 2.8s and holds once the reader points at a line.
class _Anatomy extends StatefulWidget {
  const _Anatomy();

  @override
  State<_Anatomy> createState() => _AnatomyState();
}

class _AnatomyState extends State<_Anatomy> {
  static const Duration _step = Duration(milliseconds: 2800);

  /// The composable thread sample, one entry per rendered line.
  static const List<(String, AnatomyPart, int)> _lines =
      <(String, AnatomyPart, int)>[
    ('<ThreadPrimitive.Root>', AnatomyPart.root, 0),
    ('<ThreadPrimitive.Viewport>', AnatomyPart.viewport, 1),
    ('<ThreadPrimitive.Messages', AnatomyPart.messages, 2),
    (
      'components={{ UserMessage, AssistantMessage }}',
      AnatomyPart.messages,
      3,
    ),
    ('/>', AnatomyPart.messages, 2),
    ('<ThreadPrimitive.ScrollToBottom />', AnatomyPart.scroll, 2),
    ('</ThreadPrimitive.Viewport>', AnatomyPart.viewport, 1),
    ('<ComposerPrimitive.Root>', AnatomyPart.composer, 1),
    ('<ComposerPrimitive.Input />', AnatomyPart.composer, 2),
    ('<ComposerPrimitive.Send />', AnatomyPart.composer, 2),
    ('</ComposerPrimitive.Root>', AnatomyPart.composer, 1),
    ('</ThreadPrimitive.Root>', AnatomyPart.root, 0),
  ];

  AnatomyPart _active = AnatomyPart.root;
  bool _held = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_step, (_) {
      if (!mounted || _held) return;
      setState(() {
        _active = AnatomyPart
            .values[(AnatomyPart.values.indexOf(_active) + 1) %
                AnatomyPart.values.length];
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _activate(AnatomyPart part, {bool hold = false}) {
    setState(() {
      _active = part;
      if (hold) _held = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 900;
        final Widget code = _AnatomyCode(
          lines: _lines,
          active: _active,
          onActivate: _activate,
        );
        final Widget panel = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _AnatomyMock(
              active: _active,
              onActivate: _activate,
            ),
            const SizedBox(height: 22),
            const ArrowLink(label: 'Customize the thread'),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 130,
                  child: Text(
                    _active.label,
                    style: LandingText.mono(context, size: 11).copyWith(
                      color: LandingColors.of(context).foreground,
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _active.caption,
                      key: ValueKey<AnatomyPart>(_active),
                      style: LandingText.small(context).copyWith(
                        color: LandingColors.of(context).mutedForeground,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
        if (!wide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              code,
              const SizedBox(height: 28),
              panel,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(flex: 7, child: code),
            const SizedBox(width: 40),
            Expanded(flex: 5, child: panel),
          ],
        );
      },
    );
  }
}

/// The sample with per-line hit areas: the lines of the active part are lit.
class _AnatomyCode extends StatelessWidget {
  const _AnatomyCode({
    required this.lines,
    required this.active,
    required this.onActivate,
  });

  final List<(String, AnatomyPart, int)> lines;
  final AnatomyPart active;
  final void Function(AnatomyPart part, {bool hold}) onActivate;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (String text, AnatomyPart part, int indent) in lines)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => onActivate(part),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onActivate(part, hold: true),
                child: Container(
                  color: part == active
                      ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                      : Colors.transparent,
                  padding: EdgeInsets.only(
                    left: 16 + indent * 16,
                    right: 12,
                    top: 3,
                    bottom: 3,
                  ),
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: LandingText.mono(context, size: 12).copyWith(
                      color: part == active
                          ? colors.foreground
                          : colors.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The schematic thread: each region carries a blue ring and a chip while its
/// part is active.
class _AnatomyMock extends StatelessWidget {
  const _AnatomyMock({required this.active, required this.onActivate});

  final AnatomyPart active;
  final void Function(AnatomyPart part, {bool hold}) onActivate;

  static const Color _blue = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: _region(
        context,
        part: AnatomyPart.root,
        colors: colors,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _region(
              context,
              part: AnatomyPart.viewport,
              colors: colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _region(
                    context,
                    part: AnatomyPart.messages,
                    colors: colors,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _bar(colors, width: double.infinity, height: 9),
                        const SizedBox(height: 6),
                        _bar(colors, width: 150, height: 9),
                        const SizedBox(height: 6),
                        _bar(colors, width: double.infinity, height: 9),
                        const SizedBox(height: 6),
                        _bar(colors, width: 110, height: 9),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: _region(
                      context,
                      part: AnatomyPart.scroll,
                      colors: colors,
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: colors.background,
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.border),
                        ),
                        child: Icon(
                          Icons.arrow_downward,
                          size: 12,
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _region(
              context,
              part: AnatomyPart.composer,
              colors: colors,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.border),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.add, size: 14, color: colors.mutedForeground),
                    const SizedBox(width: 8),
                    _bar(colors, width: 90, height: 7),
                    const Spacer(),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors.foreground,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(LandingColors colors, {required double width, required double height}) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.border,
          borderRadius: BorderRadius.circular(4),
        ),
      );

  /// One schematic region: a blue ring plus its chip when active.
  Widget _region(
    BuildContext context, {
    required AnatomyPart part,
    required LandingColors colors,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(8),
  }) {
    final bool current = part == active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onActivate(part),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onActivate(part, hold: true),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: current ? _blue.withValues(alpha: 0.7) : Colors.transparent,
                ),
              ),
              child: Opacity(opacity: current ? 1 : 0.8, child: child),
            ),
            if (current)
              Positioned(
                top: -9,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  color: _blue,
                  child: Text(
                    part.label.toUpperCase(),
                    style: LandingText.mono(context, size: 9).copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
