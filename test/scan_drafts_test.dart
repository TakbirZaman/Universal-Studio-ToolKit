import 'dart:convert';
import 'package:universal_studio_toolkit/application/scan_corners.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_studio_toolkit/application/scan_drafts.dart';

void main() {
  test(
    'draft preserves page order and edits and rejects damaged content',
    () async {
      final temp = await Directory.systemTemp.createTemp('ust-draft-test-');
      try {
        final store = ScanDrafts(temp.path);
        final id = await store.save([
          DraftPage(
            'সনদ.png',
            Uint8List.fromList([1, 2, 3]),
            mode: 'grayscale',
            rotation: 1,
            brightness: 20,
          ),
          DraftPage('second.png', Uint8List.fromList([4, 5])),
        ], 7);
        expect((await store.list()).single.pages, 2);
        final restored = await store.restore(id);
        expect(restored.map((p) => p.name), ['সনদ.png', 'second.png']);
        expect(restored.first.bytes, [1, 2, 3]);
        expect(restored.first.rotation, 1);
        expect(restored.first.brightness, 20);
        await File(
          '${temp.path}/scan-drafts/$id/page-000.bin',
        ).writeAsBytes([9, 9, 9]);
        await expectLater(store.restore(id), throwsA(isA<FormatException>()));
        await store.delete(id);
        expect(await store.list(), isEmpty);
      } finally {
        await temp.delete(recursive: true);
      }
    },
  );
  test(
    'corner edits round trip, old drafts restore, corrupt and future geometry is rejected',
    () async {
      final temp = await Directory.systemTemp.createTemp('ust-corner-draft-');
      try {
        final store = ScanDrafts(temp.path), corners = fullPageCorners();
        final id = await store.save([
          DraftPage('সনদ.png', Uint8List.fromList([1, 2, 3]), corners: corners),
        ], 7);
        expect(
          encodeCorners((await store.restore(id)).single.corners),
          encodeCorners(corners),
        );
        final file = File('${store.root}/$id/manifest.json');
        final data =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        expect(data['schema'], 2);
        data['pages'][0]['corners'] = [0, 0, 1, 1, 1, 0, 0, 1];
        await file.writeAsString(jsonEncode(data));
        await expectLater(store.restore(id), throwsA(isA<FormatException>()));
        data['schema'] = 1;
        (data['pages'][0] as Map).remove('corners');
        await file.writeAsString(jsonEncode(data));
        expect((await store.restore(id)).single.corners, isNull);
        data['schema'] = 3;
        await file.writeAsString(jsonEncode(data));
        await expectLater(store.restore(id), throwsA(isA<FormatException>()));
        expect(await File('${store.root}/$id/page-000.bin').readAsBytes(), [
          1,
          2,
          3,
        ]);
      } finally {
        await temp.delete(recursive: true);
      }
    },
  );
  test(
    'retention cleanup and traversal rejection protect outside files',
    () async {
      final temp = await Directory.systemTemp.createTemp('ust-draft-test-');
      try {
        final store = ScanDrafts(temp.path);
        final outside = File('${temp.path}/keep.txt');
        await outside.writeAsString('keep');
        await store.save([
          DraftPage('a.png', Uint8List.fromList([1])),
        ], 1);
        expect(
          await store.list(now: DateTime.now().add(const Duration(days: 2))),
          isEmpty,
        );
        await expectLater(
          store.delete('../keep.txt'),
          throwsA(isA<FormatException>()),
        );
        expect(await outside.readAsString(), 'keep');
        await expectLater(store.save([], 1), throwsA(isA<FormatException>()));
      } finally {
        await temp.delete(recursive: true);
      }
    },
  );
  test(
    'clear removes incomplete drafts but preserves unrelated storage',
    () async {
      final temp = await Directory.systemTemp.createTemp('ust-draft-clear-');
      try {
        final store = ScanDrafts(temp.path);
        await store.save([
          DraftPage('a.png', Uint8List.fromList([1])),
        ], 7);
        final incomplete = Directory('${store.root}/draft-interrupted');
        await incomplete.create();
        await File(
          '${incomplete.path}/manifest.tmp',
        ).writeAsString('incomplete');
        final unrelated = Directory('${store.root}/unrelated');
        await unrelated.create();
        await File('${unrelated.path}/keep.txt').writeAsString('keep');
        expect(await store.clear(), 2);
        expect(await store.list(), isEmpty);
        expect(await File('${unrelated.path}/keep.txt').readAsString(), 'keep');
        expect(await store.clear(), 0);
      } finally {
        await temp.delete(recursive: true);
      }
    },
  );

  test(
    'draft cleanup refuses linked roots and never follows linked drafts',
    () async {
      final temp = await Directory.systemTemp.createTemp('ust-draft-link-');
      try {
        final outside = await Directory('${temp.path}/outside').create();
        final keep = File('${outside.path}/keep.txt');
        await keep.writeAsString('keep');
        final store = ScanDrafts('${temp.path}/app');
        await Directory('${temp.path}/app').create();
        final rootLink = Link(store.root);
        await rootLink.create(outside.path);
        await expectLater(store.list(), throwsA(isA<FormatException>()));
        await expectLater(store.clear(), throwsA(isA<FormatException>()));
        await rootLink.delete();
        await Directory(store.root).create();
        await Link('${store.root}/draft-link').create(outside.path);
        expect(await store.clear(), 0);
        expect(await keep.readAsString(), 'keep');
      } finally {
        await temp.delete(recursive: true);
      }
    },
    skip: Platform.isWindows,
  );
}
