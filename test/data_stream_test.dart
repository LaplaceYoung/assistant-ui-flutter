import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DataStreamParser', () {
    test('accumulates text deltas into one part', () {
      final DataStreamParser parser = DataStreamParser()
        ..addLine('0:"Hello"')
        ..addLine('0:" world"');

      expect(parser.parts, hasLength(1));
      expect((parser.parts.single as TextPart).text, 'Hello world');
      expect(parser.messageFinished, isFalse);
    });

    test('keeps reasoning, text and tool calls in stream order', () {
      final DataStreamParser parser = DataStreamParser();
      parser
        ..addLine('g:"Thinking"')
        ..addLine('0:"Checking"')
        ..addLine(
          '9:{"toolCallId":"call_1","toolName":"get_weather","args":{"city":"SF"}}',
        )
        ..addLine('a:{"toolCallId":"call_1","result":"sunny"}')
        ..addLine('0:"It is sunny."');

      final List<MessagePart> parts = parser.parts;
      expect(parts, hasLength(4));
      expect(parts[0], isA<ReasoningPart>());
      expect((parts[0] as ReasoningPart).text, 'Thinking');
      expect((parts[1] as TextPart).text, 'Checking');
      expect((parts[2] as ToolCallPart).toolName, 'get_weather');
      expect((parts[2] as ToolCallPart).args, <String, Object?>{'city': 'SF'});
      expect((parts[2] as ToolCallPart).result, 'sunny');
      expect((parts[3] as TextPart).text, 'It is sunny.');
    });

    test('builds tool calls from start + args deltas', () {
      final DataStreamParser parser = DataStreamParser();
      parser
        ..addLine('b:{"toolCallId":"call_2","toolName":"lookup"}')
        ..addLine('c:{"toolCallId":"call_2","argsTextDelta":"{\\"q\\":"}')
        ..addLine('c:{"toolCallId":"call_2","argsTextDelta":"\\"flutter\\"}"}');

      final ToolCallPart call = parser.parts.single as ToolCallPart;
      expect(call.toolName, 'lookup');
      expect(call.args, <String, Object?>{'q': 'flutter'});
      expect(call.status, PartStatus.running);
    });

    test('splits frames on CRLF and ignores blanks', () {
      final DataStreamParser parser = DataStreamParser();
      parser.addChunk('0:"a"\r\n\r\n0:"b"\n');
      expect((parser.parts.single as TextPart).text, 'ab');
    });

    test('handles a chunk boundary inside a frame', () {
      final DataStreamParser parser = DataStreamParser();
      parser
        ..addChunk('0:"Hel')
        ..addChunk('lo"')
        ..addChunk('\n0:"!"\n');
      expect((parser.parts.single as TextPart).text, 'Hello!');
    });

    test('accepts SSE-wrapped frames', () {
      final DataStreamParser parser = DataStreamParser();
      parser.addChunk('data: 0:"via sse"\n\n');
      expect((parser.parts.single as TextPart).text, 'via sse');
    });

    test('drops malformed frames instead of throwing', () {
      final DataStreamParser parser = DataStreamParser();
      parser
        ..addLine('0:not json')
        ..addLine('nonsense')
        ..addLine('0:"ok"');
      expect((parser.parts.single as TextPart).text, 'ok');
    });

    test('records finish reason, usage and errors', () {
      final DataStreamParser done = DataStreamParser();
      done
        ..addLine('0:"hi"')
        ..addLine('d:{"finishReason":"stop","usage":{"inputTokens":1,"outputTokens":2}}');
      expect(done.messageFinished, isTrue);
      expect(done.finishReason, 'stop');
      expect(done.usage, <String, Object?>{'inputTokens': 1, 'outputTokens': 2});

      final DataStreamParser failed = DataStreamParser()
        ..addLine('3:"upstream exploded"');
      expect(failed.error, 'upstream exploded');
    });

    test('reads sources, files and data parts', () {
      final DataStreamParser parser = DataStreamParser();
      parser
        ..addLine('h:{"sourceType":"url","id":"s1","url":"https://a.b","title":"A"}')
        ..addLine('k:{"data":"Zm9v","mimeType":"application/pdf"}')
        ..addLine('aui-data:{"name":"chart","data":{"points":3}}');

      expect(parser.parts[0], isA<SourcePart>());
      expect((parser.parts[0] as SourcePart).url, 'https://a.b');
      expect((parser.parts[1] as FilePart).mimeType, 'application/pdf');
      expect((parser.parts[2] as DataPart).name, 'chart');
    });
  });

  group('DataStreamChatModelAdapter.toGenericMessages', () {
    test('maps thread messages onto the wire format', () {
      final List<ThreadMessage> messages = <ThreadMessage>[
        ThreadMessage.single(
          id: 's',
          role: MessageRole.system,
          content: const <MessagePart>[TextPart('Be nice')],
          createdAt: DateTime(2024),
        ),
        ThreadMessage.single(
          id: 'u',
          role: MessageRole.user,
          content: const <MessagePart>[
            TextPart('Hi'),
            ImagePart(image: 'https://a.b/cat.png'),
          ],
          createdAt: DateTime(2024),
        ),
        ThreadMessage.single(
          id: 'a',
          role: MessageRole.assistant,
          content: const <MessagePart>[
            TextPart('Checking'),
            ToolCallPart(
              toolCallId: 'call_1',
              toolName: 'get_weather',
              args: <String, Object?>{'city': 'SF'},
              result: 'sunny',
            ),
          ],
          createdAt: DateTime(2024),
        ),
      ];

      final List<Map<String, Object?>> generic =
          DataStreamChatModelAdapter.toGenericMessages(messages);

      expect(generic[0], <String, Object?>{'role': 'system', 'content': 'Be nice'});

      final List<Object?> userContent = generic[1]['content']! as List<Object?>;
      expect((userContent[0]! as Map<String, Object?>)['text'], 'Hi');
      final Map<String, Object?> imagePart = userContent[1]! as Map<String, Object?>;
      expect(imagePart['type'], 'file');
      expect(imagePart['mediaType'], 'image/png');

      final List<Object?> assistantContent = generic[2]['content']! as List<Object?>;
      expect(assistantContent, hasLength(2));
      final Map<String, Object?> call = assistantContent[1]! as Map<String, Object?>;
      expect(call['type'], 'tool-call');
      expect(call.containsKey('result'), isFalse);

      final Map<String, Object?> toolMessage = generic[3];
      expect(toolMessage['role'], 'tool');
      final Map<String, Object?> result =
          (toolMessage['content']! as List<Object?>).single! as Map<String, Object?>;
      expect(result['type'], 'tool-result');
      expect(result['result'], 'sunny');
    });
  });
}
