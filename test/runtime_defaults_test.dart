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

  test('the file-backed adapter writes the bytes and hands back a path', () async {
    final Directory dir = Directory.systemTemp.createTempSync('aui_files');
    addTearDown(() => dir.deleteSync(recursive: true));
    final FileAttachmentAdapter adapter = FileAttachmentAdapter(
      directory: dir.path,
      stepDelay: Duration.zero,
      steps: 1,
    );

    final AttachmentAddResult status = await adapter
        .add(
          PendingAttachment(
            id: 'f1',
            filename: 'notes.txt',
            mimeType: 'text/plain',
            data: Uint8List.fromList(<int>[104, 105]),
          ),
        )
        .last;

    expect(status.status, AttachmentAddStatus.complete);
    final String? path = adapter.pathOf('f1');
    expect(path, isNotNull);
    expect(File(path!).readAsStringSync(), 'hi');
    // The attachment carries a file: URL, so a host can read it later.
    expect((status.attachment! as DocumentAttachment).data,
        startsWith('file://'));
    expect(adapter.attachments, hasLength(1));

    // Removing it takes the file with it.
    await adapter.remove(status.attachment!);
    expect(File(path).existsSync(), isFalse);
    expect(adapter.attachments, isEmpty);
  });

  test('a pick with no bytes is refused rather than stored empty', () async {
    final FileAttachmentAdapter adapter = FileAttachmentAdapter(
      stepDelay: Duration.zero,
      steps: 1,
    );
    final AttachmentAddResult status = await adapter
        .add(
          PendingAttachment(id: 'e', filename: 'empty.bin', mimeType: 'application/octet-stream'),
        )
        .last;
    expect(status.status, AttachmentAddStatus.incomplete);
    expect(adapter.attachments, isEmpty);
  });

  test('the system opener says no for a path that is not there', () async {
    // A real launch would take over the machine the test runs on, so this pins
    // the decision the opener makes before it shells out.
    const SystemFileOpener opener = SystemFileOpener();
    expect(await opener.open('/definitely/not/here.txt'), isFalse);
  });

  test('saveAndOpen writes the payload and reports what it managed', () async {
    final Directory dir = Directory.systemTemp.createTempSync('aui_open');
    addTearDown(() => dir.deleteSync(recursive: true));
    final SystemFileOpener opener = SystemFileOpener();
    final TempFileSaver saver = TempFileSaver(directory: dir.path);

    // The file is written; whether the OS then opens it is the platform's
    // business (it does on a desktop session, it does not in CI).
    final FilePart part = FilePart(
      data: 'data:text/plain;base64,aGk=',
      mimeType: 'text/plain',
      filename: 'note.txt',
    );
    await opener.saveAndOpen(part, saver: saver);
    expect(File('${dir.path}/note.txt').readAsStringSync(), 'hi');

    // Nothing to save: no file, and no claim that something opened.
    expect(
      await opener.saveAndOpen(const FilePart(mimeType: 'text/plain'),
          saver: saver),
      isFalse,
    );
  });
}
