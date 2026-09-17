import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// Connection state of an MCP server in the config dialog.
enum McpConfigStatus {
  connected,
  connecting,
  authRequired,
  authPending,
  error,
  disconnected,
}

/// A server the config dialog lists.
@immutable
class McpServerConfig {
  const McpServerConfig({
    required this.id,
    required this.name,
    this.transport = 'stdio',
    this.command = '',
    this.url = '',
    this.args = const <String>[],
    this.env = const <String, String>{},

    /// Extra HTTP headers, typically an authorization token.
    this.headers = const <String, String>{},
    this.status = McpConfigStatus.disconnected,
    this.custom = false,
  });

  final String id;
  final String name;

  /// `stdio`, `sse` or `http`.
  final String transport;

  /// Command line for `stdio` transports.
  final String command;

  /// Endpoint for `sse` / `http`.
  final String url;

  final List<String> args;
  final Map<String, String> env;

  /// Extra headers for `http` / `sse` transports.
  final Map<String, String> headers;

  final McpConfigStatus status;

  /// App-defined connectors are not removable, custom ones are.
  final bool custom;

  McpServerConfig copyWith({
    String? name,
    String? transport,
    String? command,
    String? url,
    List<String>? args,
    Map<String, String>? env,
    McpConfigStatus? status,
  }) {
    return McpServerConfig(
      id: id,
      name: name ?? this.name,
      transport: transport ?? this.transport,
      command: command ?? this.command,
      url: url ?? this.url,
      args: args ?? this.args,
      env: env ?? this.env,
      status: status ?? this.status,
      custom: custom,
    );
  }
}

/// MCP server configuration: connectors, custom servers, an add form and the
/// per-server auth controls — the `mcp-config` element's visible surface.
///
/// Note: upstream drives this from the `@assistant-ui/react-mcp` runtime
/// (connect, authorize, list tools). The port keeps the editor and hands every
/// change to [onChange], so a Dart host wires its own MCP client.
class AssistantMcpConfig extends StatefulWidget {
  const AssistantMcpConfig({
    super.key,
    required this.servers,
    this.onChange,
    this.onAuthorize,
    this.onTest,
    this.title = 'MCP servers',
    this.description =
        'Connect to Model Context Protocol servers to expose their tools '
        'to this assistant.',
  });

  final List<McpServerConfig> servers;

  /// Receives the full list after every edit.
  final ValueChanged<List<McpServerConfig>>? onChange;

  final ValueChanged<String>? onAuthorize;

  /// Probes a server; the host reports back by updating [servers].
  final ValueChanged<String>? onTest;

  final String title;
  final String description;

  @override
  State<AssistantMcpConfig> createState() => _AssistantMcpConfigState();
}

class _AssistantMcpConfigState extends State<AssistantMcpConfig> {
  bool _adding = false;
  int _counter = 0;

  List<McpServerConfig> get _servers => widget.servers;

  void _update(List<McpServerConfig> next) => widget.onChange?.call(next);

  void _remove(String id) {
    _update(
      _servers
          .where((McpServerConfig server) => server.id != id)
          .toList(growable: false),
    );
  }

  void _add(McpServerConfig server) {
    _update(<McpServerConfig>[..._servers, server]);
    setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final List<McpServerConfig> connectors =
        _servers.where((McpServerConfig s) => !s.custom).toList();
    final List<McpServerConfig> custom =
        _servers.where((McpServerConfig s) => s.custom).toList();

    // A settings dialog scrolls rather than clipping: the add form can make
    // the card taller than a phone viewport.
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 512, maxHeight: maxHeight),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  color: theme.foreground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.description,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: theme.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                label: 'Connectors',
                children: <Widget>[
                  for (final McpServerConfig server in connectors)
                    _ServerCard(
                      server: server,
                      onRemove: null,
                      onAuthorize: widget.onAuthorize,
                      onTest: widget.onTest,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(height: 1, color: theme.border),
              const SizedBox(height: 16),
              _Section(
                label: 'Custom servers',
                children: <Widget>[
                  for (final McpServerConfig server in custom)
                    _ServerCard(
                      server: server,
                      onRemove: () => _remove(server.id),
                      onAuthorize: widget.onAuthorize,
                      onTest: widget.onTest,
                    ),
                  if (_adding)
                    _AddServerForm(
                      key: ValueKey<int>(_counter),
                      onCancel: () => setState(() => _adding = false),
                      onSubmit: _add,
                      nextId: () => 'custom-${_counter + 1}',
                    )
                  else
                    _AddTrigger(
                      onTap: () => setState(() {
                        _counter++;
                        _adding = true;
                      }),
                    ),
                ],
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.6,
            color: theme.mutedForeground,
          ),
        ),
        const SizedBox(height: 8),
        for (final (int index, Widget child) in children.indexed)
          Padding(
            padding: EdgeInsets.only(bottom: index == children.length - 1 ? 0 : 8),
            child: child,
          ),
      ],
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({
    required this.server,
    required this.onRemove,
    required this.onAuthorize,
    required this.onTest,
  });

  final McpServerConfig server;
  final VoidCallback? onRemove;
  final ValueChanged<String>? onAuthorize;
  final ValueChanged<String>? onTest;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: server.status == McpConfigStatus.error
              ? theme.destructive.withValues(alpha: 0.4)
              : theme.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.muted,
                  border: Border.all(color: theme.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.dns_outlined,
                  size: 16,
                  color: theme.mutedForeground,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      server.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: theme.foreground,
                      ),
                    ),
                    _StatusLine(status: server.status),
                  ],
                ),
              ),
              if (server.status == McpConfigStatus.authRequired &&
                  onAuthorize != null)
                AuiPillButton(
                  label: 'Authorize',
                  height: 28,
                  padding: 10,
                  onPressed: () => onAuthorize!(server.id),
                ),
              if (onTest != null) ...<Widget>[
                const SizedBox(width: 4),
                AuiIconAction(
                  icon: Icons.play_arrow,
                  label: 'Test ${server.name}',
                  size: 28,
                  onPressed: () => onTest!(server.id),
                ),
              ],
              if (onRemove != null)
                AuiIconAction(
                  icon: Icons.delete_outline,
                  label: 'Remove ${server.name}',
                  size: 28,
                  onPressed: onRemove,
                ),
            ],
          ),
          if (server.status == McpConfigStatus.error) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Could not reach the server.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: theme.destructive,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.status});

  final McpConfigStatus status;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final (Color dot, String label) = switch (status) {
      McpConfigStatus.connected => (theme.success, 'Connected'),
      McpConfigStatus.connecting => (theme.mutedForeground, 'Connecting…'),
      McpConfigStatus.authRequired => (
          const Color(0xFFF59E0B),
          'Auth required',
        ),
      McpConfigStatus.authPending => (
          const Color(0xFFF59E0B),
          'Authorizing…',
        ),
      McpConfigStatus.error => (theme.destructive, 'Error'),
      McpConfigStatus.disconnected => (
          theme.mutedForeground.withValues(alpha: dark ? 0.6 : 0.5),
          'Disconnected',
        ),
    };
    return Row(
      children: <Widget>[
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            height: 1.3,
            color: theme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _AddTrigger extends StatelessWidget {
  const _AddTrigger({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border.all(color: theme.border),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: <Widget>[
              Icon(Icons.add, size: 16, color: theme.foreground),
              const SizedBox(width: 8),
              Text(
                'Add server',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: theme.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddServerForm extends StatefulWidget {
  const _AddServerForm({
    super.key,
    required this.onCancel,
    required this.onSubmit,
    required this.nextId,
  });

  final VoidCallback onCancel;
  final ValueChanged<McpServerConfig> onSubmit;
  final String Function() nextId;

  @override
  State<_AddServerForm> createState() => _AddServerFormState();
}

class _AddServerFormState extends State<_AddServerForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _command = TextEditingController();
  final TextEditingController _url = TextEditingController();
  String _transport = 'stdio';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _command.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'The server needs a name.');
      return;
    }
    if (_transport == 'stdio' && _command.text.trim().isEmpty) {
      setState(() => _error = 'A stdio server needs a command.');
      return;
    }
    if (_transport != 'stdio' && _url.text.trim().isEmpty) {
      setState(() => _error = 'A remote server needs an endpoint.');
      return;
    }
    widget.onSubmit(
      McpServerConfig(
        id: widget.nextId(),
        name: name,
        transport: _transport,
        command: _command.text.trim(),
        url: _url.text.trim(),
        custom: true,
        status: McpConfigStatus.connecting,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _Field(controller: _name, hint: 'Name', label: 'name'),
          const SizedBox(height: 10),
          Text(
            'transport',
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              color: theme.mutedForeground,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              for (final String option in const <String>['stdio', 'sse', 'http'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(option),
                    selected: _transport == option,
                    onSelected: (bool selected) =>
                        setState(() => _transport = option),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_transport == 'stdio')
            _Field(
              controller: _command,
              hint: 'npx -y @modelcontextprotocol/server-filesystem',
              label: 'command',
            )
          else
            _Field(
              controller: _url,
              hint: 'https://example.com/mcp',
              label: 'endpoint',
            ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: theme.destructive,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              AuiPillButton(
                label: 'Cancel',
                height: 32,
                onPressed: widget.onCancel,
              ),
              const SizedBox(width: 8),
              AuiPillButton(
                label: 'Add',
                height: 32,
                variant: AuiPillButtonVariant.ink,
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.label,
  });

  final TextEditingController controller;
  final String hint;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            height: 1.2,
            color: theme.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: auiField(theme, radius: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: TextField(
            controller: controller,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color: theme.foreground,
            ),
            cursorColor: theme.foreground,
            decoration: InputDecoration(
              isDense: true,
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 13,
                color: theme.mutedForeground,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
