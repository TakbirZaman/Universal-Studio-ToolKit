import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_studio_toolkit/application/scan_drafts.dart';

void main() {
  test('draft preserves page order and edits and rejects damaged content', () async {
    final temp = await Directory.systemTemp.createTemp('ust-draft-test-');
    try {
      final store = ScanDrafts(temp.path);
      final id = await store.save([
        DraftPage('সনদ.png', Uint8List.fromList([1,2,3]), mode:'grayscale', rotation:1, brightness:20),
        DraftPage('second.png', Uint8List.fromList([4,5])),
      ], 7);
      expect((await store.list()).single.pages, 2);
      final restored = await store.restore(id);
      expect(restored.map((p)=>p.name), ['সনদ.png','second.png']);
      expect(restored.first.bytes, [1,2,3]);
      expect(restored.first.rotation, 1);
      expect(restored.first.brightness, 20);
      await File('${temp.path}/scan-drafts/$id/page-000.bin').writeAsBytes([9,9,9]);
      await expectLater(store.restore(id), throwsA(isA<FormatException>()));
      await store.delete(id);
      expect(await store.list(), isEmpty);
    } finally { await temp.delete(recursive:true); }
  });
  test('retention cleanup and traversal rejection protect outside files', () async {
    final temp = await Directory.systemTemp.createTemp('ust-draft-test-');
    try {
      final store = ScanDrafts(temp.path);
      final outside = File('${temp.path}/keep.txt');
      await outside.writeAsString('keep');
      await store.save([DraftPage('a.png', Uint8List.fromList([1]))], 1);
      expect(await store.list(now:DateTime.now().add(const Duration(days:2))), isEmpty);
      await expectLater(store.delete('../keep.txt'), throwsA(isA<FormatException>()));
      expect(await outside.readAsString(), 'keep');
      await expectLater(store.save([],1), throwsA(isA<FormatException>()));
    } finally { await temp.delete(recursive:true); }
  });
}
