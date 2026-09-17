import 'package:flutter/material.dart';

import 'theme.dart';

/// One row of an [AssistantMenuButton].
class AssistantMenuItem {
  const AssistantMenuItem({
    required this.label,
    this.description,
    this.icon,
    this.selected = false,
    this.enabled = true,
    this.isSeparator = false,
    this.onSelected,
  });

  const AssistantMenuItem.separator()
      : label = '',
        description = null,
        icon = null,
        selected = false,
        enabled = false,
        isSeparator = true,
        onSelected = null;

  final String label;

  /// Second line, used by model pickers ("Fast — answers in a blink").
  final String? description;

  final IconData? icon;

  /// Draws a trailing check, the way the model pickers mark the active model.
  final bool selected;

  final bool enabled;
  final bool isSeparator;
  final VoidCallback? onSelected;
}

/// Dropdown menu anchored to any child — the `dropdown-menu` dependency the
/// clone pages use for model pickers, `+` menus, and overflow actions.
class AssistantMenuButton extends StatelessWidget {
  const AssistantMenuButton({
    super.key,
    required this.child,
    required this.items,
    this.width = 260,
    this.alignment = Alignment.topLeft,
    this.controller,
  });

  final Widget child;
  final List<AssistantMenuItem> items;
  final double width;

  /// Where the panel opens relative to the anchor.
  final Alignment alignment;

  final MenuController? controller;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return MenuAnchor(
      controller: controller,
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(theme.background),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
        elevation: const WidgetStatePropertyAll<double>(8),
        padding: const WidgetStatePropertyAll<EdgeInsets>(
          EdgeInsets.symmetric(vertical: 6),
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.cardRadius),
            side: BorderSide(color: theme.border),
          ),
        ),
      ),
      menuChildren: <Widget>[
        for (final AssistantMenuItem item in items)
          if (item.isSeparator)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Divider(height: 1, color: theme.border),
            )
          else
            SizedBox(
              width: width,
              child: _MenuRow(item: item, theme: theme),
            ),
      ],
      builder: (
        BuildContext context,
        MenuController controller,
        Widget? _,
      ) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => controller.isOpen ? controller.close() : controller.open(),
          child: child,
        );
      },
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.theme});

  final AssistantMenuItem item;
  final AssistantTheme theme;

  @override
  Widget build(BuildContext context) {
    final Color foreground = item.enabled ? theme.foreground : theme.border;
    return MenuItemButton(
      onPressed: item.enabled ? item.onSelected : null,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith<Color?>(
          (Set<WidgetState> states) => states.contains(WidgetState.hovered)
              ? theme.muted
              : null,
        ),
        padding: const WidgetStatePropertyAll<EdgeInsets>(
          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      child: Row(
        children: <Widget>[
          if (item.icon != null) ...<Widget>[
            Icon(item.icon, size: 16, color: theme.mutedForeground),
            const SizedBox(width: 10),
          ],
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
                    color: foreground,
                  ),
                ),
                if (item.description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.description!,
                      style: theme.small(context).copyWith(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          if (item.selected)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.check, size: 16, color: theme.foreground),
            ),
        ],
      ),
    );
  }
}
