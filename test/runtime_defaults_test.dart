import 'dart:io';
import 'dart:typed_data';

import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// The defaults that make an attachment work with no backend, and a file chip
/// do something sensible with no wiring.
void main() {
  test('the in-memory adapter reports progress and hands back an attachment', () async {
    final InMemoryAttachmentAdapter adapter = InMemoryAttachmentAdapter(
      stepDelay: Duration.zero,
      steps: 2,
    );
    final List<AttachmentAddStatus> statuses = <AttachmentAddStatus>[];
    AuiAttachment? result;
    await for (final AttachmentAddResult step in adapter.add(
      PendingAttachment(
        id: 'a1',
        filename: 'notes.txt',
        mimeType: 'text/plain',
        data: Uint8List.fromList(<int>[104, 105]),
      ),
    )) {
      statuses.add(step.status);
      if (step.attachment != null) result = step.attachment;
    }

    expect(statuses.first, AttachmentAddStatus.running);
    expect(statuses.last, AttachmentAddStatus.complete);
    expect(result, isA<DocumentAttachment>());
    expect(result!.filename, 'notes.txt');
    expect(adapter.attachments, hasLength(1));
    expect(adapter.payloadOf('a1'), <int>[104, 105]);

    await adapter.remove(result);
    expect(adapter.attachments, isEmpty);
    expect(adapter.payloadOf('a1'), isNull);
  });

  test('an image pick becomes an image attachment', () async {
    final InMemoryAttachmentAdapter adapter =
        InMemoryAttachmentAdapter(stepDelay: Duration.zero, steps: 1);
    final AttachmentAddResult status = await adapter
        .add(
          PendingAttachment(
            id: 'img',
            filename: 'cat.png',
            mimeType: 'image/png',
            url: 'data:image/png;base64,AAAA',
          ),
        )
        .last;
    expect(status.attachment, isA<ImageAttachment>());
    expect(status.attachment!.id, 'img');
  });

  test('a rejected pick comes back incomplete', () async {
    final InMemoryAttachmentAdapter adapter = InMemoryAttachmentAdapter(
      stepDelay: Duration.zero,
      accept: (PendingAttachment pending) => pending.mimeType.startsWith('image/'),
    );
    final AttachmentAddResult status = await adapter
        .add(
          PendingAttachment(
            id: 'x',
            filename: 'big.zip',
            mimeType: 'application/zip',
          ),
        )
        .last;
    expect(status.status, AttachmentAddStatus.incomplete);
    expect(adapter.attachments, isEmpty);
  });

  test('the temp saver writes the decoded bytes where it says', () async {
    final Directory dir = Directory.systemTemp.createTempSync('aui_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final TempFileSaver saver = TempFileSaver(directory: dir.path);

    final String? path = await saver.save(
      const FilePart(
        data: 'data:text/plain;base64,aGk=',
        mimeType: 'text/plain',
        filename: 'note.txt',
      ),
    );
    expect(path, isNotNull);
    expect(File(path!).readAsStringSync(), 'hi');
    expect(path, endsWith('note.txt'));

    // A plain payload is written as text, not misread as base64.
    final String? second = await saver.save(
      const FilePart(data: 'hello', mimeType: 'text/plain', filename: 'b.txt'),
    );
    expect(File(second!).readAsStringSync(), 'hello');

    // No payload, no file.
    expect(
      await saver.save(const FilePart(mimeType: 'text/plain')),
      isNull,
    );
  });
}
