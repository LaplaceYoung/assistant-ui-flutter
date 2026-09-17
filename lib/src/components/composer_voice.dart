import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/runtime_api.dart';
import '../primitives/runtime_provider.dart';
import '../primitives/state.dart';
import 'theme.dart';
import 'tooltip_icon_button.dart';

/// Dictation control for the composer: a mic that becomes a live waveform
/// while a session runs — the `composer-voice` element.
///
/// The waveform reflects the session state rather than real amplitude; a
/// plugin-level audio meter would be needed for that.
/// Fidelity gap: no audio-level input.
class AssistantComposerVoice extends StatelessWidget {
  const AssistantComposerVoice({
    super.key,
    this.size = 32,
    this.tooltipIdle = 'Dictate',
    this.tooltipActive = 'Stop dictation',
    this.micIcon = Icons.mic_none,
    this.stopIcon = Icons.stop,
    this.showWaveform = true,
  });

  final double size;
  final String tooltipIdle;
  final String tooltipActive;
  final IconData micIcon;
  final IconData stopIcon;
  final bool showWaveform;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    return AuiStateBuilder<({bool listening, bool canDictate})>(
      selector: (AuiState state) => (
        listening: state.composer.dictation != null,
        canDictate: state.thread.capabilities.dictation,
      ),
      builder: (BuildContext context, ({bool listening, bool canDictate}) value) {
        if (value.listening && showWaveform) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _VoiceWaveform(color: theme.foreground, height: size * 0.6),
              const SizedBox(width: 6),
              AssistantTooltipIconButton(
                icon: stopIcon,
                tooltip: tooltipActive,
                size: size,
                iconSize: size * 0.5,
                shape: AssistantIconButtonShape.circle,
                backgroundColor: theme.muted,
                foregroundColor: theme.foreground,
                onPressed: runtime.thread.stopDictation,
              ),
            ],
          );
        }
        return AssistantTooltipIconButton(
          icon: micIcon,
          tooltip: tooltipIdle,
          size: size,
          iconSize: size * 0.5,
          shape: AssistantIconButtonShape.circle,
          foregroundColor: theme.mutedForeground,
          hoverColor: theme.muted,
          onPressed: value.canDictate ? runtime.thread.startDictation : null,
        );
      },
    );
  }
}

/// Five bars whose heights follow a travelling wave. Purely indicative: it
/// marks that the session is live, not the input level.
class _VoiceWaveform extends StatefulWidget {
  const _VoiceWaveform({required this.color, required this.height});

  final Color color;
  final double height;

  @override
  State<_VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<_VoiceWaveform>
    with SingleTickerProviderStateMixin {
  static const int _bars = 5;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? _) => Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              for (int i = 0; i < _bars; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: 2),
                _bar(i),
              ],
            ],
          ),
        ),
      );

  Widget _bar(int index) {
    final double phase = (_controller.value + index / _bars) % 1.0;
    final double wave = math.sin(phase * 2 * math.pi);
    final double scale = 0.35 + 0.65 * ((wave + 1) / 2);
    // `transition-[height,background-color] duration-150`: each bar eases to
    // its new height instead of stepping.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      width: 2.5,
      height: widget.height * scale,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
