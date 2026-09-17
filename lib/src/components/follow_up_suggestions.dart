import 'package:flutter/material.dart';

import '../core/message_part.dart';
import '../core/runtime_api.dart';
import '../primitives/runtime_provider.dart';
import '../primitives/state.dart';
import 'surfaces.dart';
import 'theme.dart';

/// Follow-up prompts the thread offers once a run settles, scrolling sideways
/// when they do not fit — the `follow-up-suggestions` element.
///
/// Reads `state.thread.suggestions`, the way upstream does; the host fills
/// them through `runtime.thread.setSuggestions(...)`. Tapping a chip sends its
/// prompt.
class AssistantFollowUpSuggestions extends StatefulWidget {
  const AssistantFollowUpSuggestions({super.key, this.fadeWidth = 32});

  /// Width of the fade at each edge while there is more to scroll.
  final double fadeWidth;

  @override
  State<AssistantFollowUpSuggestions> createState() =>
      _AssistantFollowUpSuggestionsState();
}

class _AssistantFollowUpSuggestionsState
    extends State<AssistantFollowUpSuggestions> {
  final ScrollController _controller = ScrollController();
  bool _fadeLeading = false;
  bool _fadeTrailing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateFades);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateFades);
    _controller.dispose();
    super.dispose();
  }

  void _updateFades() {
    if (!_controller.hasClients) return;
    final ScrollPosition position = _controller.position;
    final bool leading = position.pixels > 1;
    final bool trailing = position.pixels < position.maxScrollExtent - 1;
    if (leading != _fadeLeading || trailing != _fadeTrailing) {
      setState(() {
        _fadeLeading = leading;
        _fadeTrailing = trailing;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuiIf(
      condition: (AuiState state) =>
          state.thread.isNotEmpty &&
          !state.thread.isRunning &&
          state.thread.suggestions.isNotEmpty,
      child: AuiStateBuilder<List<ThreadSuggestion>>(
        selector: (AuiState state) => state.thread.suggestions,
        builder: (BuildContext context, List<ThreadSuggestion> suggestions) {
          final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
          final double fade = widget.fadeWidth;

          final Widget row = Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final ThreadSuggestion suggestion in suggestions)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _Chip(
                      suggestion: suggestion,
                      onTap: () => runtime.thread.send(
                        content: <MessagePart>[
                          TextPart(suggestion.prompt),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );

          return SizedBox(
            width: double.infinity,
            child: ShaderMask(
              // The fades only appear on the edge there is more to scroll to.
              shaderCallback: (Rect bounds) => LinearGradient(
                colors: <Color>[
                  _fadeLeading ? const Color(0x00FFFFFF) : const Color(0xFFFFFFFF),
                  const Color(0xFFFFFFFF),
                  _fadeTrailing
                      ? const Color(0x00FFFFFF)
                      : const Color(0xFFFFFFFF),
                ],
                stops: <double>[
                  0,
                  (fade / bounds.width).clamp(0.0, 1.0),
                  1 - (fade / bounds.width).clamp(0.0, 1.0),
                ],
              ).createShader(bounds),
              blendMode: BlendMode.dstIn,
              child: SingleChildScrollView(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                child: row,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Chip extends StatefulWidget {
  const _Chip({required this.suggestion, required this.onTap});

  final ThreadSuggestion suggestion;
  final VoidCallback onTap;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Semantics(
      button: true,
      label: widget.suggestion.display,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: _hovered ? auiFg(theme, 0.03) : null,
              border: Border.all(
                color: auiFg(theme, _hovered ? 0.25 : 0.1),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  widget.suggestion.display,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    color: theme.foreground,
                  ),
                ),
                if (widget.suggestion.label != null) ...<Widget>[
                  const SizedBox(width: 4),
                  Text(
                    widget.suggestion.label!,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      color: theme.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
