import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// Connection state of one MCP server.
enum McpServerStatus { connected, connecting, needsAuth, failed }

/// One MCP server as the panel shows it.
@immutable
class McpServer {
  const McpServer({
    required this.id,
    required this.name,
    required this.transport,
    required this.status,
    this.tools = const <String>[],
  });

  final String id;
  final String name;

  /// Transport line, e.g. `stdio` or an endpoint URL.
  final String transport;

  final McpServerStatus status;

  /// Tool names the server exposes.
  final List<String> tools;
}

/// Which MCP servers are connected and what they expose — the
/// `mcp-server-panel` element.
class AssistantMcpServerPanel extends StatelessWidget {
  const AssistantMcpServerPanel({
    super.key,
    required this.servers,
    this.expandedId,
    this.onToggle,
    this.onAuthorize,
  });

  final List<McpServer> servers;

  /// Server whose detail is open; null collapses every row.
  final String? expandedId;

  /// Called with the server id; null makes the rows inert.
  final ValueChanged<String>? onToggle;

  /// Called with the server id when its `Authorize` control is used.
  final ValueChanged<String>? onAuthorize;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final int connected = servers
        .where((McpServer server) => server.status == McpServerStatus.connected)
        .length;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Servers',
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                          color: theme.foreground,
                        ),
                      ),
                    ),
                    Text(
                      '$connected of ${servers.length} connected',
                      style: auiMono(context, color: auiFg(theme, 0.35)),
                    ),
                  ],
                ),
              ),
              for (final McpServer server in servers)
                _ServerRow(
                  server: server,
                  expanded: expandedId == server.id,
                  onToggle: onToggle,
                  onAuthorize: onAuthorize,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServerRow extends StatefulWidget {
  const _ServerRow({
    required this.server,
    required this.expanded,
    required this.onToggle,
    required this.onAuthorize,
  });

  final McpServer server;
  final bool expanded;
  final ValueChanged<String>? onToggle;
  final ValueChanged<String>? onAuthorize;

  @override
  State<_ServerRow> createState() => _ServerRowState();
}

class _ServerRowState extends State<_ServerRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final McpServer server = widget.server;
    final bool tappable = widget.onToggle != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        MouseRegion(
          cursor:
              tappable ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: tappable ? () => widget.onToggle!(server.id) : null,
            child: Semantics(
              button: tappable,
              expanded: widget.expanded,
              child: Container(
                color: tappable && _hovered ? auiFg(theme, 0.04) : null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 8,
                ),
                child: Row(
                  children: <Widget>[
                    AnimatedRotation(
                      turns: widget.expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.chevron_right,
                        size: 12,
                        color: auiFg(theme, 0.25),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      Icons.power,
                      size: 14,
                      color: auiFg(theme, 0.35),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        server.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.2,
                          color: theme.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${server.tools.length} tools',
                      style: auiMono(context, color: auiFg(theme, 0.3)),
                    ),
                    const SizedBox(width: 10),
                    _StatusDot(status: server.status),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (widget.expanded)
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 6, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    // A long endpoint must not push the authorize control
                    // out of reach.
                    Expanded(
                      child: Text(
                        server.transport,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: auiMono(context, color: auiFg(theme, 0.3)),
                      ),
                    ),
                    Text(
                      ' · ${_label(server.status)}',
                      style: auiMono(context, color: auiFg(theme, 0.3)),
                    ),
                    if (server.status == McpServerStatus.needsAuth &&
                        widget.onAuthorize != null) ...<Widget>[
                      const SizedBox(width: 8),
                      _AuthorizeButton(
                        onTap: () => widget.onAuthorize!(server.id),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: <Widget>[
                    for (final String tool in server.tools)
                      Container(
                        decoration: auiField(theme, radius: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        child: Text(
                          tool,
                          style:
                              auiMono(context, color: auiFg(theme, 0.55)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.status});

  final McpServerStatus status;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.status == McpServerStatus.connecting) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == McpServerStatus.connecting) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final Color color = switch (widget.status) {
      McpServerStatus.connected => theme.success,
      McpServerStatus.connecting => auiFg(theme, 0.3),
      McpServerStatus.needsAuth => const Color(0xFFF59E0B),
      McpServerStatus.failed => theme.destructive,
    };
    final Widget dot = Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
    return Semantics(
      // `container` keeps this node its own: without it the label is folded
      // into the enclosing server row and never announced.
      container: true,
      label: _label(widget.status),
      child: widget.status == McpServerStatus.connecting
          ? FadeTransition(
              opacity: Tween<double>(begin: 0.3, end: 1).animate(_pulse),
              child: dot,
            )
          : dot,
    );
  }
}

class _AuthorizeButton extends StatelessWidget {
  const _AuthorizeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: 'Authorize',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B)
                .withValues(alpha: dark ? 0.22 : 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            'Authorize',
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: dark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
            ),
          ),
        ),
      ),
    );
  }
}

String _label(McpServerStatus status) => switch (status) {
      McpServerStatus.connected => 'connected',
      McpServerStatus.connecting => 'connecting',
      McpServerStatus.needsAuth => 'needs auth',
      McpServerStatus.failed => 'failed',
    };
