import 'package:flutter/material.dart';

import '../core/attachments.dart';
import '../core/message.dart';
import '../core/message_part.dart';
import '../core/runtime_api.dart';
import '../primitives/message.dart' show AuiMessage, AuiToolUIBuilder;
import '../primitives/state.dart';
import '../primitives/thread.dart';
import 'surfaces.dart';
import 'action_bar.dart';
import 'composer.dart';
import 'parts.dart';
import 'theme.dart';

/// The styled thread: viewport, messages, empty state, and composer.
///
/// Mirrors the assistant-ui `Thread` element — a centered column capped at
/// [maxWidth], user messages as right-aligned bubbles, assistant messages with
/// an avatar and action bar, and the composer pinned at the bottom.
class AssistantThread extends StatelessWidget {
  const AssistantThread({
    super.key,
    this.turnAnchor = AuiTurnAnchor.top,
    this.emptyState,
    this.toolUIs = const <String, AuiToolUIBuilder>{},
    this.groupToolCalls = false,
    this.toolGroupBuilder,
    this.onDownloadFile,
    this.showScrollToLatest = true,
    this.maxWidth = 720,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    this.showComposer = true,
    this.onPickAttachments,
    this.composerPlaceholder = 'Ask anything…',
    this.avatarBuilder,
  });

  final AuiTurnAnchor turnAnchor;
  final Widget? emptyState;
  final Map<String, AuiToolUIBuilder> toolUIs;

  /// Shows the `Jump to latest` pill while the reader is scrolled away from
  /// the newest message.
  final bool showScrollToLatest;

  /// Opens or saves a file part's payload; enables the download control on
  /// file chips.
  final ValueChanged<FilePart>? onDownloadFile;

  /// Folds consecutive tool calls into one `AssistantToolGroup` card; see
  /// [AssistantMessageParts.groupToolCalls].
  final bool groupToolCalls;
  final Widget Function(BuildContext context, List<ToolCallPart> parts)?
      toolGroupBuilder;

  final double maxWidth;
  final EdgeInsets padding;
  final bool showComposer;

  /// Supplying this adds an attach button to the composer.
  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;

  final String composerPlaceholder;
  final Widget Function(BuildContext context)? avatarBuilder;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      color: theme.background,
      child: AuiThreadLayout(
        viewport: AuiThreadViewport(
          turnAnchor: turnAnchor,
          padding: padding,
          unpinnedOverlay:
              showScrollToLatest ? const AssistantScrollToLatest() : null,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  AuiIf(
                    condition: (AuiState state) => state.thread.isEmpty,
                    child: emptyState ??
                        AssistantThreadEmptyState(theme: theme),
                  ),
                  AuiThreadMessages(
                    builder: (
                      BuildContext context,
                      ThreadMessage message,
                      bool isLast,
                    ) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: message.isUser
                            ? AssistantUserMessage(message: message)
                            : AssistantAssistantMessage(
                                message: message,
                                isLast: isLast,
                                toolUIs: toolUIs,
                                groupToolCalls: groupToolCalls,
                                toolGroupBuilder: toolGroupBuilder,
                                onDownloadFile: onDownloadFile,
                                avatarBuilder: avatarBuilder,
                                isEditing: message.isEditing,
                              ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        footer: showComposer
            ? _ComposerFooter(
                placeholder: composerPlaceholder,
                maxWidth: maxWidth,
                padding: padding,
                onPickAttachments: onPickAttachments,
              )
            : null,
      ),
    );
  }
}

/// Empty state shown before the first message.
/// The pill the thread floats while the viewport is scrolled away from the
/// newest message — upstream's `scroll-anchor` affordance.
class AssistantScrollToLatest extends StatelessWidget {
  const AssistantScrollToLatest({super.key, this.label = 'Jump to latest'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Semantics(
      button: true,
      label: label,
      child: Container(
        decoration: auiPaper(theme, radius: 999),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: theme.foreground,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: theme.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

class AssistantThreadEmptyState extends StatelessWidget {
  const AssistantThreadEmptyState({
    super.key,
    required this.theme,
    this.title = 'How can I help you today?',
    this.subtitle,
  });

  final AssistantTheme theme;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: <Widget>[
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.body(context).copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.small(context),
              ),
            ],
          ],
        ),
      );
}

/// Right-aligned user bubble.
class AssistantUserMessage extends StatelessWidget {
  const AssistantUserMessage({
    super.key,
    required this.message,
    this.maxWidthFactor = 0.82,
  });

  final ThreadMessage message;
  final double maxWidthFactor;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return AuiMessage(
      message: message,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: constraints.maxWidth * maxWidthFactor),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: theme.muted,
                borderRadius: BorderRadius.circular(theme.bubbleRadius),
              ),
              child: AuiStateBuilder<bool>(
                selector: (AuiState state) => state.message?.isEditing ?? false,
                builder: (BuildContext context, bool isEditing) {
                  if (isEditing) return const AssistantInlineComposer();
                  return const AssistantMessageParts(isUser: true);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Assistant message: avatar, content, action bar, branch picker.
class AssistantAssistantMessage extends StatelessWidget {
  const AssistantAssistantMessage({
    super.key,
    required this.message,
    this.isLast = true,
    this.toolUIs = const <String, AuiToolUIBuilder>{},
    this.groupToolCalls = false,
    this.toolGroupBuilder,
    this.onDownloadFile,
    this.avatarBuilder,
    this.isEditing = false,
  });

  final ThreadMessage message;
  final bool isLast;
  final Map<String, AuiToolUIBuilder> toolUIs;
  final bool groupToolCalls;
  final Widget Function(BuildContext context, List<ToolCallPart> parts)?
      toolGroupBuilder;
  final ValueChanged<FilePart>? onDownloadFile;
  final Widget Function(BuildContext context)? avatarBuilder;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return AuiMessage(
      message: message,
      isLast: isLast,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          avatarBuilder?.call(context) ?? AssistantAvatar(theme: theme),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                AuiStateBuilder<bool>(
                  selector: (AuiState state) =>
                      state.message?.isEditing ?? false,
                  builder: (BuildContext context, bool editing) => editing
                      ? const AssistantInlineComposer()
                      : AssistantMessageParts(
                          toolUIs: toolUIs,
                          groupToolCalls: groupToolCalls,
                          toolGroupBuilder: toolGroupBuilder,
                          onDownloadFile: onDownloadFile,
                        ),
                ),
                const SizedBox(height: 4),
                AssistantMessageMeta(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Branch picker plus action bar under an assistant message.
class AssistantMessageMeta extends StatelessWidget {
  const AssistantMessageMeta({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const AssistantBranchPickerBar(),
        const Spacer(),
        const AssistantActionBar(),
      ],
    );
  }
}

/// Circular avatar shown next to assistant messages.
class AssistantAvatar extends StatelessWidget {
  const AssistantAvatar({super.key, required this.theme, this.size = 28});

  final AssistantTheme theme;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.muted,
          shape: BoxShape.circle,
          border: Border.all(color: theme.border),
        ),
        child: Text(
          theme.avatarLabel,
          style: theme.small(context).copyWith(
            fontSize: size * 0.36,
            fontWeight: FontWeight.w600,
            color: theme.foreground,
          ),
        ),
      );
}

/// Composer pinned below the viewport, capped to the thread's width.
class _ComposerFooter extends StatelessWidget {
  const _ComposerFooter({
    required this.placeholder,
    required this.maxWidth,
    required this.padding,
    required this.onPickAttachments,
  });

  final String placeholder;
  final double maxWidth;
  final EdgeInsets padding;
  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.background,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      padding: EdgeInsets.only(
        left: padding.left,
        right: padding.right,
        top: 12,
        bottom: padding.bottom < 12 ? 12 : padding.bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: AssistantComposer(
            placeholder: placeholder,
            onPickAttachments: onPickAttachments,
          ),
        ),
      ),
    );
  }
}
