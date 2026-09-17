import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// Where a voice session stands.
enum VoiceMode { connecting, listening, thinking, speaking }

/// One line of a voice transcript.
@immutable
class VoiceTurn {
  const VoiceTurn({required this.id, required this.role, required this.text});

  final String id;

  /// `user` reads as `you`, anything else as `ai`.
  final String role;

  final String text;
}

/// A live voice session: the pulsing orb, the caption and the transport —
/// the `voice-conversation` element.
class AssistantVoiceConversation extends StatelessWidget {
  const AssistantVoiceConversation({
    super.key,
    required this.mode,
    this.amplitude = 0,
    this.transcript = const <VoiceTurn>[],
    this.muted = false,
    this.onToggleMute,
    this.onInterrupt,
    this.onEnd,
  });

  final VoiceMode mode;

  /// Input level, 0..1; scales the orb.
  final double amplitude;

  final List<VoiceTurn> transcript;
  final bool muted;

  final VoidCallback? onToggleMute;

  /// Tapping the orb interrupts the assistant while it speaks.
  final VoidCallback? onInterrupt;

  final VoidCallback? onEnd;

  static const Map<VoiceMode, String> _caption = <VoiceMode, String>{
    VoiceMode.connecting: 'Connecting',
    VoiceMode.listening: 'Listening',
    VoiceMode.thinking: 'Thinking',
    VoiceMode.speaking: 'Speaking',
  };

  static const Map<VoiceMode, String> _hint = <VoiceMode, String>{
    VoiceMode.connecting: 'Opening the mic',
    VoiceMode.listening: 'Listening for you',
    VoiceMode.thinking: 'Working on it',
    VoiceMode.speaking: 'Playing the reply',
  };

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
    final double level = amplitude.clamp(0, 1);
    final bool active =
        mode == VoiceMode.listening || mode == VoiceMode.speaking;
    final bool canInterrupt = mode == VoiceMode.speaking && onInterrupt != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 28),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Semantics(
                button: true,
                enabled: canInterrupt,
                label: 'Interrupt the assistant',
                child: GestureDetector(
                  onTap: canInterrupt ? onInterrupt : null,
                  child: SizedBox(
                    width: 96,
                    height: 96,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        _Halo(
                          size: 96,
                          scale: active ? 0.72 + level * 0.28 : 0.62,
                          opacity: active ? 1 : 0.5,
                          color: mode == VoiceMode.speaking
                              ? blue.withValues(alpha: dark ? 0.15 : 0.12)
                              : auiFg(theme, 0.05),
                        ),
                        _Halo(
                          size: 68,
                          scale: active ? 0.8 + level * 0.22 : 0.7,
                          opacity: 1,
                          color: mode == VoiceMode.speaking
                              ? blue.withValues(alpha: dark ? 0.25 : 0.20)
                              : auiFg(theme, 0.08),
                        ),
                        _Core(mode: mode, level: level, theme: theme, blue: blue),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _caption[mode]!,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: theme.foreground,
                ),
              ),
              Text(
                muted
                    ? 'Mic off'
                    : canInterrupt
                        ? 'Tap to interrupt'
                        : _hint[mode]!,
                style: auiMono(context, color: auiFg(theme, 0.35)),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final VoiceTurn turn in transcript)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            SizedBox(
                              width: 32,
                              child: Text(
                                turn.role == 'user' ? 'you' : 'ai',
                                style: auiMono(
                                  context,
                                  color: turn.role == 'user'
                                      ? auiFg(theme, 0.3)
                                      : blue.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                turn.text,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: auiFg(
                                    theme,
                                    turn.role == 'user' ? 0.5 : 0.8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Semantics(
                    button: true,
                    toggled: muted,
                    label: muted
                        ? 'Turn the microphone on'
                        : 'Turn the microphone off',
                    child: GestureDetector(
                      onTap: onToggleMute,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: muted
                              ? auiFg(theme, 0.08)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          muted ? Icons.mic_off : Icons.mic_none,
                          size: 16,
                          color: auiFg(theme, muted ? 0.9 : 0.45),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'End the call',
                    child: GestureDetector(
                      onTap: onEnd,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444)
                              .withValues(alpha: onEnd == null ? 0.3 : 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
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

class _Halo extends StatelessWidget {
  const _Halo({
    required this.size,
    required this.scale,
    required this.opacity,
    required this.color,
  });

  final double size;
  final double scale;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _Core extends StatefulWidget {
  const _Core({
    required this.mode,
    required this.level,
    required this.theme,
    required this.blue,
  });

  final VoiceMode mode;
  final double level;
  final AssistantTheme theme;
  final Color blue;

  @override
  State<_Core> createState() => _CoreState();
}

class _CoreState extends State<_Core> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  bool get _pulsing =>
      widget.mode == VoiceMode.connecting || widget.mode == VoiceMode.thinking;

  @override
  void initState() {
    super.initState();
    if (_pulsing) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Core oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pulsing && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!_pulsing && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool active = widget.mode == VoiceMode.listening ||
        widget.mode == VoiceMode.speaking;
    final Color color = switch (widget.mode) {
      VoiceMode.connecting => auiFg(widget.theme, 0.2),
      VoiceMode.listening => auiFg(widget.theme, 0.8),
      VoiceMode.thinking => auiFg(widget.theme, 0.3),
      VoiceMode.speaking => widget.blue,
    };
    final Widget core = AnimatedScale(
      scale: active ? 0.9 + widget.level * 0.2 : 0.85,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
    return _pulsing
        ? FadeTransition(
            opacity: Tween<double>(begin: 0.45, end: 1).animate(_pulse),
            child: core,
          )
        : core;
  }
}
