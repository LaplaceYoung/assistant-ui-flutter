import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One switch in a settings panel.
@immutable
class SettingToggle {
  const SettingToggle({
    required this.key,
    required this.label,
    required this.detail,
    required this.on,
  });

  final String key;
  final String label;
  final String detail;
  final bool on;
}

/// Model, system prompt, temperature and the feature switches — the
/// `settings-panel` element.
class AssistantSettingsPanel extends StatelessWidget {
  const AssistantSettingsPanel({
    super.key,
    required this.model,
    required this.models,
    required this.systemPrompt,
    required this.temperature,
    this.toggles = const <SettingToggle>[],
    this.onModelChange,
    this.onSystemPromptChange,
    this.onTemperatureChange,
    this.onToggle,
  });

  final String model;
  final List<String> models;
  final String systemPrompt;

  /// Clamped to 0..2, as upstream does.
  final double temperature;

  final List<SettingToggle> toggles;

  final ValueChanged<String>? onModelChange;
  final ValueChanged<String>? onSystemPromptChange;
  final ValueChanged<double>? onTemperatureChange;
  final ValueChanged<String>? onToggle;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final double clamped = temperature.clamp(0, 2);
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
              Text('model', style: auiMono(context, color: auiFg(theme, 0.3))),
              const SizedBox(height: 6),
              Container(
                decoration: auiField(theme, radius: 999),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: <Widget>[
                    for (final String option in models)
                      Expanded(
                        child: _Segment(
                          label: option,
                          active: option == model,
                          onTap: onModelChange == null
                              ? null
                              : () => onModelChange!(option),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'system prompt',
                style: auiMono(context, color: auiFg(theme, 0.3)),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: auiField(theme, radius: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: TextField(
                  controller: TextEditingController(text: systemPrompt),
                  onChanged: onSystemPromptChange,
                  maxLines: 3,
                  minLines: 3,
                  cursorColor: theme.foreground,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: auiFg(theme, 0.8),
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    isCollapsed: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Text(
                    'temperature',
                    style: auiMono(context, color: auiFg(theme, 0.3)),
                  ),
                  const Spacer(),
                  Text(
                    clamped.toStringAsFixed(1),
                    style: auiMono(context, color: auiFg(theme, 0.55))
                        .copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  activeTrackColor: auiFg(theme, 0.8),
                  inactiveTrackColor: auiFg(theme, 0.1),
                  thumbColor: auiFg(theme, 0.8),
                  overlayColor: auiFg(theme, 0.06),
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                ),
                child: Slider(
                  value: clamped,
                  min: 0,
                  max: 2,
                  divisions: 20,
                  label: clamped.toStringAsFixed(1),
                  onChanged: onTemperatureChange,
                ),
              ),
              if (toggles.isNotEmpty) const SizedBox(height: 8),
              for (final (int index, SettingToggle toggle) in toggles.indexed)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: index == toggles.length - 1 ? 0 : 12,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              toggle.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.3,
                                color: theme.foreground,
                              ),
                            ),
                            Text(
                              toggle.detail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                                color: auiFg(theme, 0.35),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _Switch(
                        on: toggle.on,
                        label: toggle.label,
                        onTap: onToggle == null
                            ? null
                            : () => onToggle!(toggle.key),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Semantics(
      button: onTap != null,
      selected: active,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? theme.background : null,
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: auiFg(theme, active ? 0.9 : 0.45),
            ),
          ),
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.on, required this.label, required this.onTap});

  final bool on;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Semantics(
      toggled: on,
      enabled: onTap != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: MouseRegion(
          cursor: onTap == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 20,
            padding: const EdgeInsets.all(2),
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: on ? auiFg(theme, 0.8) : auiFg(theme, 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: theme.background,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
