import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:universal_studio_toolkit/design/theme.dart';
import 'package:universal_studio_toolkit/main.dart';
import 'package:universal_studio_toolkit/application/pdf_text.dart';
import 'package:universal_studio_toolkit/src/rust/api.dart' as core;
import 'package:universal_studio_toolkit/src/rust/frb_generated.dart';

class PdfPicker extends FileSelectorPlatform {
  final List<Uint8List> documents;
  final String directory;
  PdfPicker(this.documents, this.directory);
  @override
  Future<List<XFile>> openFiles({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => [
    for (var i = 0; i < documents.length; i++)
      XFile.fromData(
        documents[i],
        name: 'certificate-$i.pdf',
        path: 'certificate-$i.pdf',
        mimeType: 'application/pdf',
      ),
  ];
  @override
  Future<String?> getDirectoryPath({
    String? initialDirectory,
    String? confirmButtonText,
  }) async => directory;
}

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 160; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump(const Duration(milliseconds: 1));
    if (ready()) return;
  }
  expect(
    ready(),
    isTrue,
    reason: 'Real native processing and save must finish.',
  );
}

void main() {
  late List<Uint8List> documents;
  late Uint8List imageOnly;
  late FileSelectorPlatform original;
  setUpAll(() async {
    original = FileSelectorPlatform.instance;
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        Platform.environment['UST_CORE_LIBRARY'] ??
            '${Directory.current.path}/rust/target/debug/libstudio_core.so',
      ),
    );
    documents = [];
    for (final n in [1, 6]) {
      final image = await File(
        'rust/tests/fixtures/orientation-$n.jpg',
      ).readAsBytes();
      imageOnly = (await core.scanPdf(inputs: [image])).bytes;
      documents.add(
        (await core.decoratePdf(
          data: imageOnly,
          pageNumbers: true,
          watermark: 'CERTIFICATE $n',
          watermarkFontPoints: 14,
        )).bytes,
      );
    }
    for (final entry in {
      'StudioRoboto': 'assets/fonts/Roboto-Regular.ttf',
      'StudioNotoBengali': 'assets/fonts/NotoSansBengali.ttf',
    }.entries) {
      final font = FontLoader(entry.key);
      font.addFont(
        Future.value(
          ByteData.sublistView(await File(entry.value).readAsBytes()),
        ),
      );
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
    testWidgets(
      'read existing text, edit Bangla and save actual UTF-8 ${variant.$1}',
      (tester) async {
        final destination = Directory.systemTemp.createTempSync(
          'studio-pdf-text-ui-',
        );
        addTearDown(() => destination.deleteSync(recursive: true));
        FileSelectorPlatform.instance = PdfPicker([
          documents.first,
        ], destination.path);
        tester.view.physicalSize = variant.$2;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: StudioTokens.theme(
                variant.$1 == 'desktop' ? Brightness.light : Brightness.dark,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(variant.$3)),
                child: child!,
              ),
              home: const Scaffold(body: ToolWorkspace(tool: Tool.merge)),
            ),
          ),
        );
        await tester.tap(find.text('Add PDF files'));
        await waitFor(
          tester,
          () => find.text('certificate-0.pdf').evaluate().isNotEmpty,
        );
        await tester.ensureVisible(find.text('Read selectable text'));
        await tester.tap(find.text('Read selectable text'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        Finder field(String label) => find.widgetWithText(TextFormField, label);
        await waitFor(
          tester,
          () =>
              field('Editable document text').evaluate().isNotEmpty &&
              tester
                  .widget<TextFormField>(field('Editable document text'))
                  .controller!
                  .text
                  .contains('CERTIFICATE 1'),
        );
        final editor = field('Editable document text');
        expect(
          tester.widget<TextFormField>(editor).controller!.text,
          contains('Page 1 of 1'),
        );
        const edited = 'সনদ নম্বর ১২৩\nReviewed certificate';
        await tester.ensureVisible(editor);
        await tester.enterText(editor, edited);
        await tester.ensureVisible(field('Text filename'));
        await tester.enterText(field('Text filename'), 'সনদের-লেখা.txt');
        await tester.ensureVisible(
          find.text('Choose location and save text copy'),
        );
        await tester.tap(find.text('Choose location and save text copy'));
        final target = File('${destination.path}/সনদের-লেখা.txt');
        await waitFor(
          tester,
          () =>
              target.existsSync() &&
              find.textContaining('Saved and verified').evaluate().isNotEmpty,
        );
        final saved = await tester.runAsync(target.readAsBytes);
        expect(saved, orderedEquals(utf8.encode(edited)));
        expect(
          find.textContaining('Your original PDF is unchanged.'),
          findsOneWidget,
        );
        final captureDirectory = Platform.environment['UST_CAPTURE_PDF_TEXT'];
        if (captureDirectory != null) {
          await waitFor(
            tester,
            () => find
                .byType(RawImage)
                .evaluate()
                .any((element) => (element.widget as RawImage).image != null),
          );
          await tester.ensureVisible(editor);
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byType(RepaintBoundary).first,
            );
            final capture = await boundary.toImage();
            final png = await capture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$captureDirectory/pdf-text-${variant.$1}.png',
            ).writeAsBytes(png!.buffer.asUint8List());
            capture.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('image-only PDF explains missing text and disables text export', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: StudioTokens.theme(Brightness.light),
        home: PdfTextScreen(source: imageOnly),
      ),
    );
    await waitFor(
      tester,
      () => find
          .textContaining('No selectable text was found')
          .evaluate()
          .isNotEmpty,
    );
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Choose location and save text copy'),
    );
    expect(save.onPressed, isNull);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Editable document text'),
          )
          .controller!
          .text,
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
