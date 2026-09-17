import 'package:flutter/material.dart';

import '../core/attachments.dart';
import '../core/runtime_api.dart';
import '../primitives/composer.dart';
import '../primitives/runtime_provider.dart';
import '../primitives/state.dart';
import 'attachment.dart';
import 'theme.dart';
import 'tooltip_icon_button.dart';

/// The styled composer: attachments, input, attach button, and a send button
/// that turns into stop while a run is in flight.
class AssistantComposer extends StatelessWidget {
  const AssistantComposer({
    super.key,
    this.placeholder = 'Ask anything…',
    this.onPickAttachments,
    this.maxLines = 8,
    this.primaryAction,
    this.leading,
    this.trailing,
    this.footer,
    this.inputStyle,
    this.radius,
    this.surfaceColor,
    this.borderColor,
    this.padding = const EdgeInsets.fromLTRB(14, 10, 10, 10),
  });

  final String placeholder;
  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;
  final int maxLines;

  /// Replaces the default send/stop control. The clone pages pass a
  /// [AssistantPrimaryAction] configured to their vendor.
  final Widget? primaryAction;

  /// Extra controls before the input (attach button by default).
  final Widget? leading;

  /// Extra controls between the input and the primary action, for example a
  /// model picker.
  final Widget? trailing;

  /// Row rendered under the input row, inside the same surface.
  final Widget? footer;

  final TextStyle? inputStyle;
  final double? radius;
  final Color? surfaceColor;
  final Color? borderColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor ?? theme.background,
        borderRadius: BorderRadius.circular(radius ?? theme.composerRadius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AuiIf(
            condition: (AuiState state) => state.composer.attachments.isNotEmpty,
            child: const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: _ComposerAttachmentsRow(),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              leading ??
                  (onPickAttachments == null
                      ? const SizedBox.shrink()
                      : AuiComposerAddAttachment(
                          onPick: onPickAttachments!,
                          child: const _ComposerIconButton(
                            icon: Icons.add,
                            tooltip: 'Add photos & files',
                          ),
                        )),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: AuiComposerInput(
                    placeholder: placeholder,
                    maxLines: maxLines,
                    style: inputStyle ?? theme.body(context),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              primaryAction ?? const AssistantPrimaryAction(),
            ],
          ),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

class _ComposerAttachmentsRow extends StatelessWidget {
  const _ComposerAttachmentsRow();

  @override
  Widget build(BuildContext context) {
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    return AuiComposerAttachments(
      builder: (BuildContext context, AuiAttachment attachment, int _) =>
          Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: AssistantAttachmentCard(
          attachment: attachment,
          onRemove: () => runtime.composer.removeAttachment(attachment.id),
        ),
      ),
    );
  }
}

/// Compact composer shown in place of a message body while editing it.
class AssistantInlineComposer extends StatelessWidget {
  const AssistantInlineComposer({
    super.key,
    this.saveLabel = 'Save',
    this.cancelLabel = 'Cancel',
    this.discardNotice,
  });

  final String saveLabel;
  final String cancelLabel;

  /// Upstream warns how much history an edit throws away; the host formats it,
  /// e.g. `3 replies will be discarded`.
  final String? discardNotice;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(theme.composerRadius),
        border: Border.all(color: theme.border),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AuiComposerInput(
            autofocus: true,
            maxLines: 8,
            style: theme.body(context),
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintText: 'Edit message…',
              hintStyle: theme.body(context).copyWith(
                color: theme.mutedForeground,
              ),
            ),
          ),
          if (discardNotice != null) ...<Widget>[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                discardNotice!,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: theme.mutedForeground,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              AuiComposerCancel(child: _TextButton(label: cancelLabel)),
              const SizedBox(width: 8),
              AssistantPrimaryAction(saveLabel: saveLabel),
            ],
          ),
        ],
      ),
    );
  }
}

/// The four-state primary action the clone pages share, in upstream priority
/// order: Cancel (running) → Stop dictation (listening) → Send (text or
/// attachments) → Dictate.
///
/// Vocabularies differ per vendor (ChatGPT also shows a voice-mode button,
/// Gemini a grey disabled arrow), which is what the styling parameters are for.
class AssistantPrimaryAction extends StatelessWidget {
  const AssistantPrimaryAction({
    super.key,
    this.size = 32,
    this.iconSize = 18,
    this.saveLabel,
    this.backgroundColor,
    this.foregroundColor,
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
    this.sendIcon = Icons.arrow_upward,
    this.stopIcon = Icons.stop,
    this.micIcon = Icons.mic_none,
    this.dictationIcon = Icons.stop,
    this.showVoiceModeButton = false,
    this.onVoiceMode,
    this.detectIsEmpty,
  });

  final double size;
  final double iconSize;

  /// When set, the action renders as a labelled button (edit mode's "Save").
  final String? saveLabel;

  final Color? backgroundColor;
  final Color? foregroundColor;

  /// Colours of the idle-and-empty state, which vendors style individually
  /// (Gemini's grey arrow, ChatGPT's dimmed circle).
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;

  final IconData sendIcon;
  final IconData stopIcon;
  final IconData micIcon;
  final IconData dictationIcon;

  /// ChatGPT pairs dictation with a voice-mode button.
  final bool showVoiceModeButton;
  final VoidCallback? onVoiceMode;

  /// Extra emptiness check, for vendors that treat attachments as optional.
  final bool Function(ComposerState state)? detectIsEmpty;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);

    return AuiStateBuilder<
        ({bool running, bool dictating, bool canSend, bool empty, bool canDictate})>(
      selector: (AuiState state) => (
        running: state.thread.isRunning,
        dictating: state.composer.dictation != null,
        canSend: state.composer.canSend,
        empty: detectIsEmpty?.call(state.composer) ?? state.composer.isEmpty,
        canDictate: state.thread.capabilities.dictation,
      ),
      builder: (
        BuildContext context,
        ({bool running, bool dictating, bool canSend, bool empty, bool canDictate})
            state,
      ) {
        // Priority order matters: a paused dictation still wins over Send.
        if (state.running) {
          return _PrimaryButton(
            size: size,
            iconSize: iconSize,
            icon: stopIcon,
            tooltip: 'Stop',
            background: backgroundColor ?? theme.primary,
            foreground: foregroundColor ?? theme.primaryForeground,
            onPressed: runtime.thread.cancelRun,
          );
        }
        if (state.dictating) {
          return _PrimaryButton(
            size: size,
            iconSize: iconSize,
            icon: dictationIcon,
            tooltip: 'Stop dictation',
            background: backgroundColor ?? theme.primary,
            foreground: foregroundColor ?? theme.primaryForeground,
            onPressed: runtime.thread.stopDictation,
          );
        }
        if (!state.empty) {
          return _PrimaryButton(
            size: size,
            iconSize: iconSize,
            icon: sendIcon,
            label: saveLabel,
            tooltip: saveLabel ?? 'Send',
            background: backgroundColor ?? theme.primary,
            foreground: foregroundColor ?? theme.primaryForeground,
            onPressed: state.canSend ? runtime.composer.send : null,
          );
        }
        if (saveLabel != null) {
          return _PrimaryButton(
            size: size,
            iconSize: iconSize,
            icon: sendIcon,
            label: saveLabel,
            tooltip: saveLabel!,
            background: backgroundColor ?? theme.primary,
            foreground: foregroundColor ?? theme.primaryForeground,
            onPressed: runtime.composer.send,
          );
        }
        if (state.canDictate) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _PrimaryButton(
                size: size,
                iconSize: iconSize,
                icon: micIcon,
                tooltip: 'Dictate',
                background: Colors.transparent,
                foreground: theme.mutedForeground,
                onPressed: runtime.thread.startDictation,
              ),
              if (showVoiceModeButton) ...<Widget>[
                const SizedBox(width: 4),
                _PrimaryButton(
                  size: size,
                  iconSize: iconSize,
                  icon: Icons.graphic_eq,
                  tooltip: 'Use voice mode',
                  background: backgroundColor ?? theme.primary,
                  foreground: foregroundColor ?? theme.primaryForeground,
                  onPressed: onVoiceMode,
                ),
              ],
            ],
          );
        }
        // Idle and empty: the disabled arrow every vendor shows.
        return _PrimaryButton(
          size: size,
          iconSize: iconSize,
          icon: sendIcon,
          tooltip: 'Send',
          background: disabledBackgroundColor ?? backgroundColor ?? theme.muted,
          foreground: disabledForegroundColor ?? theme.mutedForeground,
          onPressed: null,
        );
      },
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.size,
    required this.iconSize,
    required this.icon,
    required this.tooltip,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.label,
  });

  final double size;
  final double iconSize;
  final IconData icon;
  final String tooltip;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool enabled = onPressed != null;
    final Widget button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: enabled ? 1 : 0.45,
        child: Container(
          width: label == null ? size : null,
          height: size,
          padding: label == null
              ? null
              : const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            shape: label == null ? BoxShape.circle : BoxShape.rectangle,
            borderRadius:
                label == null ? null : BorderRadius.circular(theme.bubbleRadius),
          ),
          child: label == null
              ? Icon(icon, size: iconSize, color: foreground)
              : Text(
                  label!,
                  style: theme.body(context).copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
    return Tooltip(message: tooltip, child: button);
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({required this.icon, this.tooltip});

  final IconData icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final Widget button = Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: theme.muted, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: theme.mutedForeground),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.bubbleRadius),
        border: Border.all(color: theme.border),
      ),
      child: Text(
        label,
        style: theme.body(context).copyWith(color: theme.foreground),
      ),
    );
  }
}

/// Convenience wrapper so hosts can drop the attach button in with a picker,
/// keeping the styling local to the composer.
class AssistantComposerAttachButton extends StatelessWidget {
  const AssistantComposerAttachButton({
    super.key,
    required this.onPick,
    this.icon = Icons.add,
    this.tooltip = 'Add photos & files',
    this.size = 32,
    this.backgroundColor,
    this.foregroundColor,
  });

  final Future<List<PendingAttachment>> Function(BuildContext context) onPick;
  final IconData icon;
  final String tooltip;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return AuiComposerAddAttachment(
      onPick: onPick,
      child: AssistantTooltipIconButton(
        icon: icon,
        tooltip: tooltip,
        size: size,
        iconSize: size * 0.56,
        shape: AssistantIconButtonShape.circle,
        backgroundColor: backgroundColor ?? theme.muted,
        foregroundColor: foregroundColor ?? theme.mutedForeground,
      ),
    );
  }
}
