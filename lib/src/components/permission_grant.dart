import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// How long a capability is granted for.
enum GrantScope { session, always, denied }

/// What a requester wants and what granting it reaches — the
/// `permission-grant` element.
///
/// [scope] is `null` while the request is pending; the buttons render only
/// then, and only when [onGrant] is supplied.
class AssistantPermissionGrant extends StatelessWidget {
  const AssistantPermissionGrant({
    super.key,
    required this.capability,
    required this.requester,
    this.reach = const <String>[],
    this.scope,
    this.onGrant,
  });

  final String capability;
  final String requester;

  /// What the grant unlocks, one line each.
  final List<String> reach;

  final GrantScope? scope;
  final ValueChanged<GrantScope>? onGrant;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
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
              Row(
                children: <Widget>[
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: auiFg(theme, 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.key_outlined,
                      size: 14,
                      color: auiFg(theme, 0.45),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          capability,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color: theme.foreground,
                          ),
                        ),
                        Text(
                          'requested by $requester',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: auiFg(theme, 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (reach.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  'this grants',
                  style: auiMono(context, color: auiFg(theme, 0.3)),
                ),
                const SizedBox(height: 4),
                for (final String item in reach)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 8),
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: auiFg(theme, 0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: auiFg(theme, 0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (scope == null) ...<Widget>[
                      if (onGrant != null) ...<Widget>[
                        AuiPillButton(
                          label: 'Deny',
                          height: 32,
                          padding: 12,
                          onPressed: () => onGrant!(GrantScope.denied),
                        ),
                        AuiPillButton(
                          label: 'This session',
                          height: 32,
                          padding: 12,
                          onPressed: () => onGrant!(GrantScope.session),
                        ),
                        AuiPillButton(
                          label: 'Always',
                          height: 32,
                          padding: 12,
                          variant: AuiPillButtonVariant.ink,
                          onPressed: () => onGrant!(GrantScope.always),
                        ),
                      ] else
                        _Status(label: 'pending', theme: theme),
                    ] else
                      _Status(
                        label: scope == GrantScope.denied
                            ? 'denied'
                            : 'granted · ${scope!.name}',
                        theme: theme,
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

class _Status extends StatelessWidget {
  const _Status({required this.label, required this.theme});

  final String label;
  final AssistantTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: auiField(theme, radius: 999),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        label,
        style: auiMono(context, color: auiFg(theme, 0.55)),
      ),
    );
  }
}
