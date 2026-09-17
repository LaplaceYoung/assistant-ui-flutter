import 'package:flutter/material.dart';

import '../primitives/composer_triggers.dart';
import 'theme.dart';

/// A person or agent a mention can reference.
class AssistantMention {
  const AssistantMention({
    required this.id,
    required this.name,
    this.description,
    this.initials,
  });

  final String id;
  final String name;
  final String? description;

  /// Avatar text; defaults to the name's initials.
  final String? initials;
}

/// A slash command: label, blurb and the action it runs.
class AssistantSlashCommand {
  const AssistantSlashCommand({
    required this.name,
    required this.label,
    this.description,
    this.icon,
    required this.onRun,
  });

  final String name;
  final String label;
  final String? description;
  final IconData? icon;
  final Future<void> Function() onRun;
}

/// Trigger adapter over a fixed list of people, mirroring the upstream mention
/// adapter's behavior: filter by name, insert a directive.
class AssistantMentionAdapter extends AuiTriggerAdapter {
  AssistantMentionAdapter(this.people);

  final List<AssistantMention> people;

  @override
  String get triggerChar => '@';

  @override
  Future<List<TriggerItem>> search(String query) async {
    final String needle = query.toLowerCase();
    return people
        .where((AssistantMention person) =>
            needle.isEmpty ||
            person.name.toLowerCase().contains(needle) ||
            person.id.toLowerCase().contains(needle))
        .map((AssistantMention person) => TriggerItem(
              id: person.id,
              label: person.name,
              description: person.description,
              data: person,
            ))
        .toList(growable: false);
  }

  /// The directive form: `@[Name](id) `.
  @override
  String? insertText(TriggerItem item) => '@[${item.label}](${item.id}) ';
}

/// Trigger adapter over slash commands: the token is consumed and the command
/// runs instead of leaving text behind.
class AssistantSlashCommandAdapter extends AuiTriggerAdapter {
  AssistantSlashCommandAdapter(this.commands);

  final List<AssistantSlashCommand> commands;

  @override
  String get triggerChar => '/';

  @override
  Future<List<TriggerItem>> search(String query) async {
    final String needle = query.toLowerCase();
    return commands
        .where((AssistantSlashCommand command) =>
            needle.isEmpty ||
            command.name.toLowerCase().contains(needle) ||
            command.label.toLowerCase().contains(needle))
        .map((AssistantSlashCommand command) => TriggerItem(
              id: command.name,
              label: command.label,
              description: command.description,
              icon: command.icon,
              data: command,
            ))
        .toList(growable: false);
  }

  @override
  Future<void> onSelect(TriggerItem item) async {
    final Object? data = item.data;
    if (data is AssistantSlashCommand) await data.onRun();
  }
}

/// Mention popover: avatars, names and blurbs, keyboard-driven.
class AssistantMentionPopover extends StatelessWidget {
  const AssistantMentionPopover({
    super.key,
    required this.people,
    this.width = 320,
    this.title = 'Mention',
    this.placement = AuiTriggerPlacement.above,
  });

  final List<AssistantMention> people;
  final double width;
  final String title;
  final AuiTriggerPlacement placement;

  @override
  Widget build(BuildContext context) => AuiComposerTriggerPopover(
        adapter: AssistantMentionAdapter(people),
        width: width,
        placement: placement,
        builder: (BuildContext context, AuiTriggerState state) =>
            _TriggerSurface(
          title: title,
          empty: state.items.isEmpty,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < state.items.length; i++)
                _TriggerRow(
                  item: state.items[i],
                  highlighted: i == state.highlightedIndex,
                  leading: _MentionAvatar(
                    mention: state.items[i].data is AssistantMention
                        ? state.items[i].data! as AssistantMention
                        : null,
                  ),
                  onTap: () => state.select(state.items[i]),
                ),
            ],
          ),
        ),
      );
}

/// Slash command menu: icon, label and blurb above the input.
class AssistantSlashCommandMenu extends StatelessWidget {
  const AssistantSlashCommandMenu({
    super.key,
    required this.commands,
    this.width = 340,
    this.title = 'Commands',
    this.placement = AuiTriggerPlacement.above,
  });

  final List<AssistantSlashCommand> commands;
  final double width;
  final String title;
  final AuiTriggerPlacement placement;

  @override
  Widget build(BuildContext context) => AuiComposerTriggerPopover(
        adapter: AssistantSlashCommandAdapter(commands),
        width: width,
        placement: placement,
        builder: (BuildContext context, AuiTriggerState state) =>
            _TriggerSurface(
          title: title,
          empty: state.items.isEmpty,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int i = 0; i < state.items.length; i++)
                _TriggerRow(
                  item: state.items[i],
                  highlighted: i == state.highlightedIndex,
                  onTap: () => state.select(state.items[i]),
                ),
            ],
          ),
        ),
      );
}

class _TriggerSurface extends StatelessWidget {
  const _TriggerSurface({
    required this.child,
    required this.title,
    required this.empty,
  });

  final Widget child;
  final String title;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: theme.background,
          borderRadius: BorderRadius.circular(theme.cardRadius),
          border: Border.all(color: theme.border),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.45 : 0.12,
              ),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              child: Text(
                title.toUpperCase(),
                style: theme.small(context).copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: theme.mutedForeground,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: empty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Text(
                          'No matches',
                          style: theme.small(context),
                        ),
                      )
                    : child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TriggerRow extends StatelessWidget {
  const _TriggerRow({
    required this.item,
    required this.highlighted,
    required this.onTap,
    this.leading,
  });

  final TriggerItem item;
  final bool highlighted;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          // `transition-colors` as the highlighted row moves.
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          color: highlighted ? theme.muted : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: <Widget>[
              leading ??
                  Icon(
                    item.icon ?? Icons.terminal,
                    size: 16,
                    color: theme.mutedForeground,
                  ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      item.label,
                      style: theme.body(context).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.foreground,
                      ),
                    ),
                    if (item.description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.small(context).copyWith(fontSize: 11.5),
                        ),
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

class _MentionAvatar extends StatelessWidget {
  const _MentionAvatar({this.mention});

  final AssistantMention? mention;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final String label = mention?.initials ??
        _initials(mention?.name ?? '?');
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.muted,
        shape: BoxShape.circle,
        border: Border.all(color: theme.border),
      ),
      child: Text(
        label,
        style: theme.small(context).copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: theme.foreground,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final List<String> parts = name
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first).toUpperCase();
  }
}

/// Renders mention directives (`@[Name](id)`) as inline chips — the
/// `directive-text` element.
class AssistantDirectiveText extends StatelessWidget {
  const AssistantDirectiveText({
    super.key,
    required this.text,
    this.style,
    this.chipBuilder,
  });

  final String text;
  final TextStyle? style;

  /// Custom chip for a directive; defaults to the muted pill.
  final Widget Function(BuildContext context, String label, String id)? chipBuilder;

  static final RegExp _directive = RegExp(r'@\[([^\]]+)\]\(([^)]+)\)');

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final List<InlineSpan> spans = <InlineSpan>[];
    int index = 0;
    for (final RegExpMatch match in _directive.allMatches(text)) {
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      final String label = match.group(1)!;
      final String id = match.group(2)!;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: chipBuilder?.call(context, label, id) ??
              _DirectiveChip(label: label, id: id, theme: theme),
        ),
      );
      index = match.end;
    }
    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }

    return Text.rich(
      TextSpan(
        style: style ?? theme.body(context).copyWith(color: theme.foreground),
        children: spans,
      ),
    );
  }
}

class _DirectiveChip extends StatelessWidget {
  const _DirectiveChip({
    required this.label,
    required this.id,
    required this.theme,
  });

  final String label;
  final String id;
  final AssistantTheme theme;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: theme.muted,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: theme.border),
        ),
        child: Text(
          '@$label',
          style: theme.small(context).copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.foreground,
          ),
        ),
      );
}
