import 'package:flutter/material.dart';

import '../core/adapters.dart';
import '../core/message_part.dart';
import '../primitives/message.dart';
import 'markdown.dart';
import 'quote.dart';
import 'theme.dart';
import 'tool_group.dart';
import 'tooltip_icon_button.dart';

/// Part renderer used by the styled messages.
///
/// Text goes through [AssistantMarkdown], reasoning becomes a collapsible
/// card, tool calls render a registered UI or the built-in fallback card, and
/// files and sources render as chips.
class AssistantMessageParts extends StatelessWidget {
  const AssistantMessageParts({
    super.key,
    this.toolUIs = const <String, AuiToolUIBuilder>{},
    this.isUser = false,
    this.spacing = 10,
    this.groupToolCalls = false,
    this.toolGroupBuilder,
    this.onDownloadFile,
  });

  final Map<String, AuiToolUIBuilder> toolUIs;

  /// User bubbles render plain text styling without reasoning or tool cards.
  final bool isUser;

  final double spacing;

  /// Folds runs of consecutive tool calls into one [AssistantToolGroup] card,
  /// the way upstream's `GroupedParts` does with a `group-tool` group.
  ///
  /// Applies only to calls with no registered [toolUIs] entry: once a tool
  /// ships its own UI, that UI renders on its own instead of being summarized.
  final bool groupToolCalls;

  /// Overrides the grouped rendering; receives the tool parts of one run.
  final Widget Function(BuildContext context, List<ToolCallPart> parts)?
      toolGroupBuilder;

  /// Opens or saves a file part's payload; enables the download control.
  final ValueChanged<FilePart>? onDownloadFile;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool grouping = groupToolCalls && !isUser;
    return AuiMessageParts(
      spacing: spacing,
      textStyle: theme.body(context).copyWith(color: theme.foreground),
      toolUIs: isUser ? const <String, AuiToolUIBuilder>{} : toolUIs,
      partBuilder: isUser ? _userPart : _assistantPart,
      groupBy: grouping
          ? (MessagePart part, int index) =>
              part is ToolCallPart && !toolUIs.containsKey(part.toolName)
                  ? 'group-tool'
                  : null
          : null,
      partGroupBuilder: grouping
          ? (BuildContext context, String group,
              List<AuiPartGroupMember> members) {
              final List<ToolCallPart> parts = members
                  .map((AuiPartGroupMember member) => member.part)
                  .whereType<ToolCallPart>()
                  .toList();
              final Widget? custom = toolGroupBuilder?.call(context, parts);
              if (custom != null) return custom;
              return AssistantToolGroup(
                label: parts.length == 1
                    ? '1 tool call'
                    : '${parts.length} tool calls',
                tools: <GroupedTool>[
                  for (final ToolCallPart part in parts)
                    GroupedTool(
                      id: part.toolCallId,
                      name: part.toolName,
                      target: auiToolTarget(part),
                      state: switch (part.status) {
                        PartStatus.running => GroupedToolState.running,
                        PartStatus.complete => GroupedToolState.done,
                        PartStatus.incomplete => GroupedToolState.failed,
                      },
                    ),
                ],
              );
            }
          : null,
    );
  }

  /// Assistant parts: markdown text, a reasoning card, a tool-call card, and
  /// inline images and file chips.
  Widget? _assistantPart(
    BuildContext context,
    MessagePart part,
    int index,
    PartStatus status,
  ) {
    final AssistantTheme theme = AssistantTheme.of(context);
    switch (part) {
      case TextPart():
        return AssistantMarkdown(
          text: part.text,
          style: theme.body(context),
          trailing:
              status == PartStatus.running ? const AuiStreamingCursor() : null,
        );
      case ReasoningPart():
        return AssistantReasoning(part: part, status: status);
      case ToolCallPart():
        final AuiToolUIBuilder? custom = toolUIs[part.toolName];
        if (custom != null) return custom(context, part);
        return AssistantToolCallCard(part: part);
      case ImagePart():
        return ClipRRect(
          borderRadius: BorderRadius.circular(theme.cardRadius),
          child: AuiMessagePartImage(part: part, width: 320),
        );
      case FilePart():
        return _FileChip(part: part, onDownload: onDownloadFile);
      case QuotePart():
        return _QuoteBlock(part: part);
      case SourcePart():
        return _SourceChip(part: part);
      case DataPart():
        return null;
    }
  }

  Widget? _userPart(
    BuildContext context,
    MessagePart part,
    int index,
    PartStatus status,
  ) {
    final AssistantTheme theme = AssistantTheme.of(context);
    switch (part) {
      case TextPart():
        return AssistantMarkdown(
          text: part.text,
          style: theme.body(context),
          trailing:
              status == PartStatus.running ? const AuiStreamingCursor() : null,
        );
      case ImagePart():
        return ClipRRect(
          borderRadius: BorderRadius.circular(theme.cardRadius),
          child: AuiMessagePartImage(
            part: part,
            width: 240,
            fit: BoxFit.cover,
          ),
        );
      case FilePart():
        return _FileChip(part: part, onDownload: onDownloadFile);
      case QuotePart():
        return _QuoteBlock(part: part);
      default:
        return null;
    }
  }
}

/// Reasoning card: a collapsible block that opens itself while the model is
/// still thinking, mirroring the upstream reasoning disclosure.
class AssistantReasoning extends StatefulWidget {
  const AssistantReasoning({
    super.key,
    required this.part,
    this.status = PartStatus.complete,
  });

  final ReasoningPart part;
  final PartStatus status;

  @override
  State<AssistantReasoning> createState() => _AssistantReasoningState();
}

class _AssistantReasoningState extends State<AssistantReasoning> {
  bool _expanded = true;
  bool _userToggled = false;

  @override
  void didUpdateWidget(AssistantReasoning oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Auto-open while streaming unless the reader folded it away.
    if (widget.status == PartStatus.running && !_userToggled) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool running = widget.status == PartStatus.running;
    return Container(
      decoration: BoxDecoration(
        color: theme.muted,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              _expanded = !_expanded;
              _userToggled = true;
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: <Widget>[
                  if (running) ...<Widget>[
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: theme.mutedForeground,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      running ? 'Thinking…' : 'Thought process',
                      style: theme.small(context).copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.mutedForeground,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: theme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 150),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: AssistantMarkdown(
                text: widget.part.text,
                style: theme.body(context).copyWith(
                  color: theme.mutedForeground,
                  fontSize: (theme.body(context).fontSize ?? 14) - 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Best-effort target of a tool call for the grouped tool rows: the first
/// well-known argument (`path`, `command`, `query`, …), else a compact
/// rendering of the arguments, else nothing.
String auiToolTarget(ToolCallPart part) {
  const List<String> keys = <String>[
    'target', 'path', 'file', 'file_path', 'filename', 'command', 'cmd',
    'query', 'url', 'pattern', 'symbol', 'name',
  ];
  final Object? args = part.args;
  if (args is Map) {
    for (final String key in keys) {
      final Object? value = args[key];
      if (value is String && value.isNotEmpty) return value;
      if (value != null && value is! Map && value is! List) return '$value';
    }
    if (args.isEmpty) return '';
    return args.entries
        .take(2)
        .map((MapEntry<Object?, Object?> entry) =>
            '${entry.key}: ${entry.value}')
        .join(', ');
  }
  if (args is String) return args;
  return '';
}

/// Default rendering for a tool call: name, live state, and the result.
class AssistantToolCallCard extends StatelessWidget {
  const AssistantToolCallCard({
    super.key,
    required this.part,
    this.renderText,
  });

  final ToolCallPart part;

  /// Labels from the tool definition, mirroring `renderText` upstream.
  final ToolRenderText? renderText;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final PartStatus status = part.status;
    final Color accent = switch (status) {
      PartStatus.running => theme.mutedForeground,
      PartStatus.complete => theme.success,
      PartStatus.incomplete => theme.destructive,
    };
    final String label = switch (status) {
      PartStatus.running => renderText?.running ?? 'Running ${part.toolName}…',
      PartStatus.complete =>
        renderText?.complete ?? '${part.toolName} finished',
      PartStatus.incomplete => '${part.toolName} failed',
    };

    return Container(
      decoration: BoxDecoration(
        color: theme.background,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        border: Border.all(color: theme.border),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.small(context).copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.foreground,
                  ),
                ),
              ),
              if (status == PartStatus.running)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: theme.mutedForeground,
                  ),
                ),
            ],
          ),
          if (part.args != null) ...<Widget>[
            const SizedBox(height: 8),
            _JsonBlock(value: part.args),
          ],
          if (part.hasResult) ...<Widget>[
            const SizedBox(height: 8),
            _JsonBlock(value: part.result, error: part.isError),
          ],
        ],
      ),
    );
  }
}

class _JsonBlock extends StatelessWidget {
  const _JsonBlock({required this.value, this.error = false});

  final Object? value;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.muted,
        borderRadius: BorderRadius.circular(theme.cardRadius - 4),
      ),
      child: Text(
        _format(value),
        style: theme.code(context).copyWith(
          fontSize: 12,
          color: error ? theme.destructive : theme.mutedForeground,
        ),
      ),
    );
  }

  static String _format(Object? value) {
    if (value == null) return 'null';
    if (value is String) return value;
    if (value is Map || value is List) {
      return _prettyJson(value);
    }
    return '$value';
  }

  static String _prettyJson(Object? value) {
    // Minimal pretty printer: avoids a dart:convert round trip losing number
    // formatting, and keeps the output stable across platforms.
    final StringBuffer buffer = StringBuffer();
    void write(Object? node, int indent) {
      final String pad = '  ' * indent;
      if (node is Map) {
        if (node.isEmpty) {
          buffer.write('{}');
          return;
        }
        buffer.writeln('{');
        final List<MapEntry<Object?, Object?>> entries =
            node.entries.toList(growable: false);
        for (int i = 0; i < entries.length; i++) {
          buffer.write('$pad  ${_key(entries[i].key)}: ');
          write(entries[i].value, indent + 1);
          if (i != entries.length - 1) buffer.write(',');
          buffer.writeln();
        }
        buffer.write('$pad}');
        return;
      }
      if (node is List) {
        if (node.isEmpty) {
          buffer.write('[]');
          return;
        }
        buffer.writeln('[');
        for (int i = 0; i < node.length; i++) {
          buffer.write('$pad  ');
          write(node[i], indent + 1);
          if (i != node.length - 1) buffer.write(',');
          buffer.writeln();
        }
        buffer.write('$pad]');
        return;
      }
      buffer.write(node is String ? '"$node"' : '$node');
    }

    write(value, 0);
    return buffer.toString();
  }

  static String _key(Object? key) => key is String ? '"$key"' : '$key';
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.part});

  final SourcePart part;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final String label = part.title ?? part.url ?? part.id ?? 'Source';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.muted,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.link, size: 14, color: theme.mutedForeground),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: theme.small(context).copyWith(color: theme.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// A quoted passage inside a message: the same block the composer preview
/// uses, with the source role shown when it is known.
class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.part});

  final QuotePart part;

  @override
  Widget build(BuildContext context) {
    return AssistantQuoteBlock(text: part.text);
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.part, this.onDownload});

  final FilePart part;

  /// Opens or saves the payload; without it the chip is inert.
  final ValueChanged<FilePart>? onDownload;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final String? payload = part.data;
    final bool downloadable =
        onDownload != null && payload != null && payload.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.muted,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            attachmentIcon(part.mimeType),
            size: 14,
            color: theme.mutedForeground,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              part.filename ?? part.mimeType,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.small(context).copyWith(color: theme.foreground),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            attachmentSizeLabel(payload) ?? attachmentTypeLabel(part.mimeType),
            style: theme.small(context),
          ),
          if (downloadable) ...<Widget>[
            const SizedBox(width: 6),
            AssistantTooltipIconButton(
              icon: Icons.download_outlined,
              tooltip: 'Download ${part.filename ?? 'the file'}',
              size: 22,
              iconSize: 12,
              onPressed: () => onDownload!(part),
            ),
          ],
        ],
      ),
    );
  }
}

/// File-type icon for a mime type: the `file` element's icon set.
IconData attachmentIcon(String mimeType) {
  final String mime = mimeType.toLowerCase();
  if (mime.startsWith('image/')) return Icons.image_outlined;
  if (mime.startsWith('audio/')) return Icons.audiotrack_outlined;
  if (mime.startsWith('video/')) return Icons.movie_outlined;
  if (mime.contains('zip') || mime.contains('tar') || mime.contains('gzip')) {
    return Icons.folder_zip_outlined;
  }
  if (mime.contains('pdf')) return Icons.picture_as_pdf_outlined;
  if (mime.contains('json') ||
      mime.contains('xml') ||
      mime.contains('yaml') ||
      mime.contains('csv')) {
    return Icons.data_object;
  }
  if (mime.startsWith('text/')) return Icons.description_outlined;
  return Icons.attach_file;
}

/// Byte size of a base64 payload, or null when the part carries a URL (or
/// nothing) instead of bytes.
String? attachmentSizeLabel(String? data) {
  if (data == null || data.isEmpty) return null;
  if (data.startsWith('http://') ||
      data.startsWith('https://') ||
      data.startsWith('data:')) {
    return null;
  }
  final int padding = data.endsWith('==')
      ? 2
      : data.endsWith('=')
          ? 1
          : 0;
  final int bytes = (data.length ~/ 4) * 3 - padding;
  if (bytes <= 0) return null;
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Short human label for a mime type, used where upstream shows a size.
String attachmentTypeLabel(String mimeType) {
  final String mime = mimeType.toLowerCase();
  if (mime.endsWith('json')) return 'JSON';
  if (mime.endsWith('csv')) return 'CSV';
  if (mime.endsWith('pdf')) return 'PDF';
  if (mime.endsWith('zip')) return 'ZIP';
  if (mime.endsWith('plain')) return 'TXT';
  final int slash = mime.indexOf('/');
  return slash == -1 ? mime.toUpperCase() : mime.substring(slash + 1).toUpperCase();
}
