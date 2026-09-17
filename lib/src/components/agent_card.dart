import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// A capability an agent advertises.
@immutable
class AgentSkill {
  const AgentSkill({required this.name, required this.description});

  final String name;
  final String description;
}

/// What a remote agent is and how to reach it — the `agent-card` element.
class AssistantAgentCard extends StatelessWidget {
  const AssistantAgentCard({
    super.key,
    required this.name,
    required this.description,
    required this.provider,
    required this.version,
    required this.model,
    required this.endpoint,
    this.skills = const <AgentSkill>[],
    this.connected = false,
    this.onConnect,
  });

  final String name;
  final String description;
  final String provider;
  final String version;
  final String model;
  final String endpoint;
  final List<AgentSkill> skills;

  /// Connected cards show a check and stop accepting taps.
  final bool connected;
  final VoidCallback? onConnect;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: auiFg(theme, 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.smart_toy_outlined,
                      size: 16,
                      color: auiFg(theme, 0.45),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.3,
                                  fontWeight: FontWeight.w500,
                                  color: theme.foreground,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'v$version',
                              style:
                                  auiMono(context, color: auiFg(theme, 0.3)),
                            ),
                          ],
                        ),
                        Text(
                          provider,
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
              const SizedBox(height: 14),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: auiFg(theme, 0.6),
                ),
              ),
              if (skills.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                for (final AgentSkill skill in skills)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Container(
                          decoration: auiField(theme, radius: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            skill.name,
                            style: auiMono(
                              context,
                              color: auiFg(theme, 0.55),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            skill.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: auiFg(theme, 0.45),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: auiFg(theme, 0.07))),
                ),
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        endpoint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: auiMono(context, color: auiFg(theme, 0.3)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      model,
                      style: auiMono(context, color: auiFg(theme, 0.3)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ConnectButton(connected: connected, onConnect: onConnect),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConnectButton extends StatelessWidget {
  const _ConnectButton({required this.connected, required this.onConnect});

  final bool connected;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    if (connected) {
      return Container(
        height: 32,
        width: double.infinity,
        decoration: BoxDecoration(
          color: auiFieldColor(theme),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.check, size: 14, color: Color(0xFF10B981)),
            const SizedBox(width: 6),
            Text(
              'Connected',
              style: TextStyle(
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.w500,
                color: auiFg(theme, 0.55),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: 32,
      width: double.infinity,
      child: AuiPillButton(
        label: 'Connect',
        height: 32,
        padding: 14,
        variant: AuiPillButtonVariant.ink,
        onPressed: onConnect,
      ),
    );
  }
}
