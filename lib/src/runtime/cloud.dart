import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Raised for transport failures and API errors alike.
class CloudException implements Exception {
  const CloudException({required this.status, required this.message});

  final int status;
  final String message;

  @override
  String toString() => 'CloudException($status): $message';
}

/// One row of the hosted thread list.
class CloudThread {
  const CloudThread({
    required this.id,
    required this.title,
    this.externalId,
    this.isArchived = false,
    this.lastMessageAt,
    this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  final String id;
  final String title;

  /// The app's own id for the thread.
  final String? externalId;
  final bool isArchived;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Object? metadata;

  static CloudThread? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? id = raw['id'];
    if (id is! String) return null;
    return CloudThread(
      id: id,
      title: (raw['title'] as String?) ?? '',
      externalId: raw['external_id'] as String?,
      isArchived: raw['is_archived'] == true,
      lastMessageAt: _time(raw['last_message_at']),
      createdAt: _time(raw['created_at']),
      updatedAt: _time(raw['updated_at']),
      metadata: raw['metadata'],
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'title': title,
        if (externalId != null) 'external_id': externalId,
        'is_archived': isArchived,
        if (lastMessageAt != null)
          'last_message_at': lastMessageAt!.toUtc().toIso8601String(),
        if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toUtc().toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      };
}

/// A page of threads.
class CloudThreadPage {
  const CloudThreadPage({required this.threads, this.nextCursor});

  final List<CloudThread> threads;
  final String? nextCursor;
}

/// The hosted platform client: threads and their messages.
///
/// The token comes from a callback so an app can refresh it without rebuilding
/// the client, matching upstream's auth-strategy split.
class CloudClient {
  CloudClient({
    String baseUrl = 'https://api.assistant-ui.com/v1',
    this.projectId,
    this.workspaceId,
    this.token,
    this.headers = const <String, String>{},
    http.Client? client,
  })  : baseUrl =
            baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = client ?? http.Client();

  final String baseUrl;
  final String? projectId;
  final String? workspaceId;

  /// A bearer token, or a callback that resolves one per request.
  final FutureOr<String?> Function()? token;
  final Map<String, String> headers;
  final http.Client _client;

  Future<Map<String, String>> _headers() async {
    final String? resolved = token == null ? null : await token!();
    return <String, String>{
      'content-type': 'application/json',
      'accept': 'application/json',
      if (resolved != null) 'authorization': 'Bearer $resolved',
      if (projectId != null) 'x-project-id': projectId!,
      if (workspaceId != null) 'x-workspace-id': workspaceId!,
      ...headers,
    };
  }

  String get _scope {
    final List<String> segments = <String>[
      if (workspaceId != null) 'workspaces/${Uri.encodeComponent(workspaceId!)}',
      if (projectId != null) 'projects/${Uri.encodeComponent(projectId!)}',
    ];
    return segments.isEmpty ? '' : '/${segments.join('/')}';
  }

  /// Lists threads, newest first.
  Future<CloudThreadPage> listThreads({
    bool? isArchived,
    int? limit,
    String? after,
  }) async {
    final Uri uri = Uri.parse('$baseUrl$_scope/threads').replace(
      queryParameters: <String, String>{
        if (isArchived != null) 'is_archived': '$isArchived',
        if (limit != null) 'limit': '$limit',
        if (after != null) 'after': after,
      },
    );
    final Object? decoded = await _send('GET', uri, expectMap: false);
    final Map<String, Object?> body =
        decoded is Map<String, Object?> ? decoded : const <String, Object?>{};
    final Object? raw = body['threads'];
    return CloudThreadPage(
      threads: <CloudThread>[
        if (raw is List<Object?>)
          for (final Object? entry in raw)
            if (CloudThread.fromJson(entry) case final CloudThread thread) thread,
      ],
      nextCursor: body['next_cursor'] as String?,
    );
  }

  /// Creates a thread and returns its id.
  Future<String> createThread({
    String? title,
    DateTime? lastMessageAt,
    Object? metadata,
    String? externalId,
  }) async {
    final Object? decoded = await _send(
      'POST',
      Uri.parse('$baseUrl$_scope/threads'),
      payload: <String, Object?>{
        if (title != null) 'title': title,
        'last_message_at':
            (lastMessageAt ?? DateTime.now()).toUtc().toIso8601String(),
        if (metadata != null) 'metadata': metadata,
        if (externalId != null) 'external_id': externalId,
      },
      expectMap: false,
    );
    final Object? id =
        decoded is Map<String, Object?> ? decoded['thread_id'] : null;
    if (id is! String) {
      throw const CloudException(status: 200, message: 'No thread_id in the reply');
    }
    return id;
  }

  /// Updates a thread's title, timestamp, metadata or archive flag.
  Future<void> updateThread(
    String threadId, {
    String? title,
    DateTime? lastMessageAt,
    Object? metadata,
    bool? isArchived,
  }) async {
    await _send(
      'PATCH',
      Uri.parse('$baseUrl$_scope/threads/$threadId'),
      payload: <String, Object?>{
        if (title != null) 'title': title,
        if (lastMessageAt != null)
          'last_message_at': lastMessageAt.toUtc().toIso8601String(),
        if (metadata != null) 'metadata': metadata,
        if (isArchived != null) 'is_archived': isArchived,
      },
    );
  }

  /// Deletes a thread.
  Future<void> deleteThread(String threadId) async {
    await _send('DELETE', Uri.parse('$baseUrl$_scope/threads/$threadId'));
  }

  /// The messages of a thread, oldest first.
  Future<List<Map<String, Object?>>> listMessages(
    String threadId, {
    String? format,
  }) async {
    final Uri uri = Uri.parse('$baseUrl$_scope/threads/$threadId/messages').replace(
      queryParameters: <String, String>{if (format != null) 'format': format},
    );
    final Object? body = await _send('GET', uri, expectMap: false);
    final Object? raw = body is Map<String, Object?> ? body['messages'] : body;
    return <Map<String, Object?>>[
      if (raw is List<Object?>)
        for (final Object? entry in raw)
          if (entry is Map<String, Object?>) entry,
    ];
  }

  /// Appends a message to a thread.
  Future<Map<String, Object?>> appendMessage(
    String threadId,
    Map<String, Object?> message,
  ) async {
    final Object? body = await _send(
      'POST',
      Uri.parse('$baseUrl$_scope/threads/$threadId/messages'),
      payload: <String, Object?>{'message': message},
      expectMap: false,
    );
    return body is Map<String, Object?> ? body : const <String, Object?>{};
  }

  void close() => _client.close();

  Future<Object?> _send(
    String method,
    Uri uri, {
    Map<String, Object?>? payload,
    bool expectMap = true,
  }) async {
    final Map<String, String> headers = await _headers();
    final http.Response response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'DELETE' => await _client.delete(uri, headers: headers),
      'PATCH' => await _client.patch(
          uri,
          headers: headers,
          body: jsonEncode(payload ?? const <String, Object?>{}),
        ),
      _ => await _client.post(
          uri,
          headers: headers,
          body: jsonEncode(payload ?? const <String, Object?>{}),
        ),
    };

    if (response.statusCode >= 400) {
      throw CloudException(
        status: response.statusCode,
        message: _errorMessage(response.body),
      );
    }
    if (response.body.trim().isEmpty) {
      return expectMap ? const <String, Object?>{} : null;
    }
    final Object? decoded = jsonDecode(response.body);
    if (expectMap && decoded is! Map<String, Object?>) {
      throw CloudException(
        status: response.statusCode,
        message: 'Expected an object, got ${response.body}',
      );
    }
    return decoded;
  }

  String _errorMessage(String body) {
    if (body.trim().isEmpty) return 'The request failed';
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, Object?>) {
        final Object? error = decoded['error'] ?? decoded['message'];
        if (error is String) return error;
        if (error is Map<String, Object?>) {
          final Object? message = error['message'];
          if (message is String) return message;
        }
      }
    } on FormatException {
      // Fall through to the raw body.
    }
    return body.trim();
  }
}

DateTime? _time(Object? raw) {
  if (raw is String) return DateTime.tryParse(raw);
  if (raw is int) {
    return DateTime.fromMillisecondsSinceEpoch(
      raw > 10000000000 ? raw : raw * 1000,
      isUtc: true,
    );
  }
  return null;
}
