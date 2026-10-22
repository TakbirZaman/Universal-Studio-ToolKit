import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:universal_studio_toolkit/application/pdf_split.dart';
import 'package:universal_studio_toolkit/src/rust/api.dart' as core;
import 'package:universal_studio_toolkit/src/rust/frb_generated.dart';
import 'pdf_text_workflow_test.dart' show PdfPicker, waitFor;

void main() {
  late Uint8List source;
  late FileSelectorPlatform picker;
  setUpAll(() async {
    picker = FileSelectorPlatform.instance;
    await RustLib.init(externalLibrary: ExternalLibrary.open(Platform.environment['UST_CORE_LIBRARY']!));
    final image = await File('rust/tests/fixtures/orientation-1.jpg').readAsBytes();
    final page = await core.scanPdf(inputs: [image]);
    final documents = <Uint8List>[];
    for (var i = 1; i <= 3; i++) {
      documents.add((await core.decoratePdf(data: page.bytes, pageNumbers: false, watermark: 'SOURCE PAGE $i', watermarkFontPoints: 14)).bytes);
    }
    source = (await core.combinePdfs(inputs: documents, rotation: 0)).bytes;
  });
  tearDownAll(() => FileSelectorPlatform.instance = picker);
  for (final scale in [1.0, 2.0]) {
    testWidgets('split, selectively recover and save actual page groups at $scale scale', (tester) async {
      final directory = Directory.systemTemp.createTempSync('studio-split-');
      addTearDown(() => directory.deleteSync(recursive: true));
      FileSelectorPlatform.instance = PdfPicker([], directory.path);
      tester.view.physicalSize = Size(scale == 1 ? 1100 : 390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!), home: PdfSplitScreen(source: source)));
      await waitFor(tester, () => find.textContaining('Source: 3 pages').evaluate().isNotEmpty);
      Finder fields(String label) => find.widgetWithText(TextField, label);
      Future<void> tap(String label) async { final target = find.text(label); await tester.ensureVisible(target); await tester.tap(target); await tester.pump(); }
      await tester.enterText(fields('Pages in this part').first, '3,1');
      await tap('Add part');
      await tester.ensureVisible(fields('Pages in this part').last);
      await tester.enterText(fields('Pages in this part').last, '4');
      await tap('Prepare unfinished parts');
      await waitFor(tester, () => find.textContaining('Ready: 2 pages').evaluate().isNotEmpty && find.textContaining('Pages must be within').evaluate().isNotEmpty);
      expect(find.textContaining('Ready: 2 pages'), findsOneWidget);
      await tester.ensureVisible(fields('Pages in this part').last);
      await tester.enterText(fields('Pages in this part').last, '2');
      await tester.ensureVisible(find.text('Prepare part').last);
      await tester.tap(find.text('Prepare part').last);
      await waitFor(tester, () => find.textContaining('Ready: 1 pages').evaluate().isNotEmpty);
      // Editing one group preserves the successful first part.
      expect(find.textContaining('Ready: 2 pages'), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        final save = find.text('Save PDF copy').at(i);
        await tester.ensureVisible(save);
        await tester.tap(save);
        await waitFor(tester, () => find.textContaining('Saved and verified part-${i + 1}.pdf').evaluate().isNotEmpty);
      }
      final first = await tester.runAsync(() => File('${directory.path}/part-1.pdf').readAsBytes());
      final second = await tester.runAsync(() => File('${directory.path}/part-2.pdf').readAsBytes());
      final texts = await tester.runAsync(() async => [await core.extractPdfText(data: first!), await core.extractPdfText(data: second!)]);
      final ordered = String.fromCharCodes(texts![0].bytes);
      expect(ordered.indexOf('SOURCE PAGE 3'), lessThan(ordered.indexOf('SOURCE PAGE 1')));
      expect(ordered, isNot(contains('SOURCE PAGE 2')));
      expect(String.fromCharCodes(texts[1].bytes), contains('SOURCE PAGE 2'));
      expect(await tester.runAsync(() => core.countPdf(data: source)), 3);
      // A collision must keep the existing verified file and report a recoverable error.
      await tester.ensureVisible(find.text('Save PDF copy').first);
      await tester.tap(find.text('Save PDF copy').first);
      await waitFor(tester, () => find.textContaining('already exists').evaluate().isNotEmpty);
      expect(await tester.runAsync(() => File('${directory.path}/part-1.pdf').readAsBytes()), orderedEquals(first!));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
