import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:universal_studio_toolkit/design/theme.dart';
import 'package:universal_studio_toolkit/main.dart';
import 'package:universal_studio_toolkit/application/pdf_preview.dart';
import 'package:universal_studio_toolkit/src/rust/api.dart' as core;
import 'package:universal_studio_toolkit/src/rust/frb_generated.dart';

class PdfPicker extends FileSelectorPlatform {
  final List<Uint8List> documents;
  final String directory;
  PdfPicker(this.documents, this.directory);
  @override
  Future<List<XFile>> openFiles({List<XTypeGroup>? acceptedTypeGroups,
      String? initialDirectory, String? confirmButtonText}) async => [
    for (var i = 0; i < documents.length; i++)
      XFile.fromData(documents[i], name: 'certificate-$i.pdf',
          path: 'certificate-$i.pdf', mimeType: 'application/pdf'),
  ];
  @override
  Future<String?> getDirectoryPath({String? initialDirectory,
      String? confirmButtonText}) async => directory;
}

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 160; attempt++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 1));
    if (ready()) return;
  }
  expect(ready(), isTrue, reason: 'Real native processing and save must finish.');
}

void main() {
  late List<Uint8List> documents;
  late FileSelectorPlatform original;
  setUpAll(() async {
    original = FileSelectorPlatform.instance;
    await RustLib.init(externalLibrary: ExternalLibrary.open(
      Platform.environment['UST_CORE_LIBRARY'] ?? '${Directory.current.path}/rust/target/debug/libstudio_core.so'));
    documents = [];
    for (final n in [1, 6]) {
      final image = await File('rust/tests/fixtures/orientation-$n.jpg').readAsBytes();
      documents.add((await core.scanPdf(inputs: [image])).bytes);
    }
    for (final entry in {
      'StudioRoboto': 'assets/fonts/Roboto-Regular.ttf',
      'StudioNotoBengali': 'assets/fonts/NotoSansBengali.ttf',
    }.entries) {
      final font = FontLoader(entry.key);
      font.addFont(Future.value(ByteData.sublistView(await File(entry.value).readAsBytes())));
      await font.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  tearDownAll(() => FileSelectorPlatform.instance = original);
  for (final variant in [
    ('desktop', const Size(1440, 1600), 1.0),
    ('narrow', const Size(390, 1100), 2.0),
  ]) {
    testWidgets('arrange, mark, preview and save actual PDF ${variant.$1}', (tester) async {
      final destination = await Directory.systemTemp.createTemp('studio-overlay-ui-');
      addTearDown(() => destination.delete(recursive: true));
      FileSelectorPlatform.instance = PdfPicker(documents, destination.path);
      tester.view.physicalSize = variant.$2;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ProviderScope(child: MaterialApp(
        theme: StudioTokens.theme(variant.$1 == 'desktop' ? Brightness.light : Brightness.dark),
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(variant.$3)), child: child!),
        home: const Scaffold(body: ToolWorkspace(tool: Tool.merge)),
      )));
      await tester.tap(find.text('Choose PDF files'));
      await waitFor(tester, () => find.text('certificate-1.pdf').evaluate().isNotEmpty);
      Future<void> tapText(String text) async {
        await tester.ensureVisible(find.text(text));
        await tester.tap(find.text(text));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
      Finder field(String label) => find.byWidgetPredicate((w) =>
          w is TextFormField && w.decoration?.labelText == label);
      await tester.ensureVisible(field('Pages to keep, in order'));
      await tester.enterText(field('Pages to keep, in order'), '2,1');
      await tapText('Rotate all pages: 0°');
      await tapText('Try lossless optimization');
      await tapText('Page numbers & watermark');
      await tapText('Add page numbers');
      await tapText('Add a text watermark');
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value, isTrue);
      await tester.ensureVisible(field('Watermark text'));
      await tester.enterText(field('Watermark text'), 'বাংলা');
      await tapText('Prepare preview');
      expect(find.text('Use 1–80 English letters, numbers or plain symbols.'), findsOneWidget);
      expect(find.byType(PdfPreview), findsNothing);
      await tester.ensureVisible(field('Watermark text'));
      await tester.enterText(field('Watermark text'), 'DRAFT (copy)');
      await tester.ensureVisible(field('Watermark text size (points)'));
      await tester.enterText(field('Watermark text size (points)'), '14');
      await tapText('Prepare preview');
      await waitFor(tester, () => find.byType(PdfPreview).evaluate().isNotEmpty);
      await waitFor(tester, () => find.descendant(of: find.byType(PdfPreview), matching: find.byType(RawImage))
          .evaluate().any((e) => (e.widget as RawImage).image != null));
      final actual = tester.widget<PdfPreview>(find.byType(PdfPreview));
      expect(actual.pageCount, 2);
      final expected = await tester.runAsync(() async {
        final arranged = await core.combinePdfs(inputs: documents, pages: Uint32List.fromList([2,1]), rotation: 90);
        final decorated = await core.decoratePdf(data: arranged.bytes, pageNumbers: true,
            watermark: 'DRAFT (copy)', watermarkFontPoints: 14);
        return core.optimizePdf(data: decorated.bytes);
      });
      for (var page = 0; page < 2; page++) {
        final renders = await tester.runAsync(() => Future.wait([
          core.renderPdfPage(data: actual.data, pageIndex: page, maxPixels: 600),
          core.renderPdfPage(data: expected!.bytes, pageIndex: page, maxPixels: 600),
        ]));
        expect(renders![0].bytes, orderedEquals(renders[1].bytes));
      }
      await tester.ensureVisible(field('Filename'));
      await tester.enterText(field('Filename'), 'নথি.pdf');
      await tapText('Choose location and save a copy');
      final target = File('${destination.path}/নথি.pdf');
      await waitFor(tester, target.existsSync);
      final saved = await tester.runAsync(target.readAsBytes);
      expect(saved, orderedEquals(actual.data));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
