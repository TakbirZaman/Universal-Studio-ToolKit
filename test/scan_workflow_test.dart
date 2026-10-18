import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
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
import 'package:universal_studio_toolkit/application/safe_image_preview.dart';
import 'package:universal_studio_toolkit/src/rust/api.dart' as core;
import 'package:universal_studio_toolkit/src/rust/scanner.dart';
import 'package:universal_studio_toolkit/src/rust/frb_generated.dart';

class ScanPicker extends FileSelectorPlatform {
  final List<Uint8List> sources;
  ScanPicker(this.sources);
  @override
  Future<List<XFile>> openFiles({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => [
    for (var i = 0; i < sources.length; i++)
      XFile.fromData(
        sources[i],
        name: 'page-${i + 1}.jpg',
        path: 'page-${i + 1}.jpg',
        mimeType: 'image/jpeg',
      ),
  ];
}

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 1));
    if (ready()) return;
  }
  expect(ready(), isTrue, reason: 'Actual native processing must settle.');
}

void main() {
  late List<Uint8List> sources;
  late FileSelectorPlatform original;
  setUpAll(() async {
    sources = await Future.wait(
      [1, 6, 3].map(
        (n) => File('rust/tests/fixtures/orientation-$n.jpg').readAsBytes(),
      ),
    );
    original = FileSelectorPlatform.instance;
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

    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        Platform.environment['UST_CORE_LIBRARY'] ??
            '${Directory.current.path}/rust/target/debug/libstudio_core.so',
      ),
    );
  });
  tearDownAll(() {
    FileSelectorPlatform.instance = original;
  });
  for (final variant in [
    ('desktop', const Size(1440, 1600), 1.0),
    ('narrow', const Size(390, 1100), 2.0),
  ]) {
    testWidgets(
      'import three pages, reorder, rotate, prepare and verify actual PDF ${variant.$1}',
      (tester) async {
        tester.view.physicalSize = variant.$2;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        FileSelectorPlatform.instance = ScanPicker(sources);
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
              home: const Scaffold(body: ToolWorkspace(tool: Tool.scan)),
            ),
          ),
        );
        await tester.tap(find.text('Add page images'));
        await waitFor(
          tester,
          () => find.text('page-3.jpg').evaluate().isNotEmpty,
        );
        await tester.ensureVisible(find.byTooltip('Move page up').first);
        await tester.tap(find.byTooltip('Move page up').first);
        await tester.pump();
        expect(find.text('Editing page 2: page-1.jpg'), findsOneWidget);
        await tester.ensureVisible(find.text('Rotate: 0°'));
        await tester.tap(find.text('Rotate: 0°'));
        await tester.pump();
        await waitFor(
          tester,
          () => find.byType(SafeImagePreview).evaluate().isNotEmpty,
        );
        await tester.ensureVisible(find.text('Prepare preview'));
        await tester.tap(find.text('Prepare preview'));
        await waitFor(
          tester,
          () => find.byType(PdfPreview).evaluate().isNotEmpty,
        );
        await waitFor(
          tester,
          () => find
              .descendant(
                of: find.byType(PdfPreview),
                matching: find.byType(RawImage),
              )
              .evaluate()
              .any((element) => (element.widget as RawImage).image != null),
        );
        final preview = tester.widget<PdfPreview>(find.byType(PdfPreview));
        expect(preview.pageCount, 3);
        final expected = await tester.runAsync(
          () => core.prepareScanPdf(
            pages: [
              ScanPage(
                data: sources[1],
                options: const ScanOptions(
                  mode: ScanMode.original,
                  rotateQuarters: 0,
                  brightness: 0,
                  contrast: 0,
                  threshold: 128,
                ),
              ),
              ScanPage(
                data: sources[0],
                options: const ScanOptions(
                  mode: ScanMode.original,
                  rotateQuarters: 1,
                  brightness: 0,
                  contrast: 0,
                  threshold: 128,
                ),
              ),
              ScanPage(
                data: sources[2],
                options: const ScanOptions(
                  mode: ScanMode.original,
                  rotateQuarters: 0,
                  brightness: 0,
                  contrast: 0,
                  threshold: 128,
                ),
              ),
            ],
          ),
        );
        for (var index = 0; index < 3; index++) {
          final rendered = await tester.runAsync(
            () => Future.wait([
              core.renderPdfPage(
                data: preview.data,
                pageIndex: index,
                maxPixels: 600,
              ),
              core.renderPdfPage(
                data: expected!.bytes,
                pageIndex: index,
                maxPixels: 600,
              ),
            ]),
          );
          expect(rendered![0].bytes, orderedEquals(rendered[1].bytes));
        }
        await tester.runAsync(() async {
          final directory = await Directory.systemTemp.createTemp(
            'studio-scan-test-',
          );
          try {
            await core.saveOutput(
              directory: directory.path,
              filename: 'সনদ.pdf',
              output: expected!,
            );
            final saved = await File('${directory.path}/সনদ.pdf').readAsBytes();
            expect(saved, orderedEquals(expected.bytes));
          } finally {
            await directory.delete(recursive: true);
          }
        });
        expect(find.text('Choose location and save a copy'), findsOneWidget);
        final captureDirectory = Platform.environment['UST_CAPTURE_SCAN'];
        if (captureDirectory != null) {
          await tester.ensureVisible(find.byType(PdfPreview));
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
              '$captureDirectory/scan-${variant.$1}.png',
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
  testWidgets('invalid source never reaches Flutter image decoder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SafeImagePreview(
          bytes: Uint8List.fromList('GIF89a'.codeUnits),
          semanticLabel: 'Invalid source',
        ),
      ),
    );
    await waitFor(
      tester,
      () => find.textContaining('Could not preview').evaluate().isNotEmpty,
    );
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
