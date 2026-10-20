import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:universal_studio_toolkit/application/scan_corner_editor.dart';
import 'package:universal_studio_toolkit/application/scan_corners.dart';
import 'package:universal_studio_toolkit/design/theme.dart';
import 'package:universal_studio_toolkit/src/rust/api.dart' as core;
import 'package:universal_studio_toolkit/src/rust/frb_generated.dart';
import 'package:universal_studio_toolkit/src/rust/scanner.dart';

Future<void> ready(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 10));
    if (condition()) return;
  }
  expect(condition(), isTrue, reason: 'The actual local engine must finish.');
}

void main() {
  setUpAll(() async {
    for (final entry in {
      'StudioRoboto': 'assets/fonts/Roboto-Regular.ttf',
      'StudioNotoBengali': 'assets/fonts/NotoSansBengali.ttf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(
          Future.value(
            ByteData.sublistView(await File(entry.value).readAsBytes()),
          ),
        );
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        Platform.environment['UST_CORE_LIBRARY'] ??
            '${Directory.current.path}/rust/target/debug/libstudio_core.so',
      ),
    );
  });
  for (final variant in [
    ('desktop', const Size(1440, 1600), 1.0),
    ('narrow', const Size(390, 1100), 2.0),
  ]) {
    testWidgets(
      'review corners, drag, undo, keyboard, apply and save actual PDF ${variant.$1}',
      (tester) async {
        expect(
          await tester.runAsync(core.scanGeometryAvailable),
          isTrue,
          reason:
              'This integration suite requires a provisioned native adapter.',
        );
        tester.view.physicalSize = variant.$2;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final source = File(
              'rust/tests/fixtures/orientation-6.jpg',
            ).readAsBytesSync(),
            original = File(
              'rust/tests/fixtures/orientation-6.jpg',
            ).readAsBytesSync();
        CornerEditResult? result;
        final captureKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: StudioTokens.theme(
              variant.$1 == 'narrow' ? Brightness.dark : Brightness.light,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(variant.$3)),
              child: RepaintBoundary(key: captureKey, child: child!),
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      result = await Navigator.of(context)
                          .push<CornerEditResult>(
                            MaterialPageRoute(
                              builder: (_) => ScanCornerEditor(source: source),
                            ),
                          );
                    },
                    child: const Text('Set page corners'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Set page corners'));
        await tester.pump();
        final handle = find.byTooltip(
          'Top left corner. Drag or use arrow keys; Shift for larger steps.',
        );
        await ready(
          tester,
          () => find
              .byKey(const ValueKey('corner-image-ready'))
              .evaluate()
              .isNotEmpty,
        );
        await tester.pumpAndSettle();
        final captureDirectory = Platform.environment['UST_CAPTURE_DIR'];
        if (captureDirectory != null) {
          await tester.runAsync(() async {
            final boundary =
                captureKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final capture = await boundary.toImage(pixelRatio: 1);
            final data = await capture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            Directory(captureDirectory).createSync(recursive: true);
            File(
              '$captureDirectory/corners-${variant.$1}.png',
            ).writeAsBytesSync(data!.buffer.asUint8List());
            capture.dispose();
          });
        }
        await tester.drag(handle, const Offset(12, 20));
        await tester.pump();
        await tester.ensureVisible(find.text('Undo'));
        await tester.tap(find.text('Undo'));
        await tester.pump();
        await tester.ensureVisible(handle);
        await tester.tap(handle);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        await tester.ensureVisible(find.text('Straighten tilted text'));
        await tester.tap(find.text('Straighten tilted text'));
        await tester.pumpAndSettle();
        final angleSlider = find.byKey(const ValueKey('straighten-angle'));
        await tester.ensureVisible(angleSlider);
        await tester.drag(angleSlider, const Offset(30, 0));
        await tester.pump();
        expect(
          find.text(
            'Manual straightening selected. Check cropped edges before applying.',
          ),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Undo'));
        await tester.tap(find.text('Undo'));
        await tester.pump();
        await tester.ensureVisible(find.text('Precise corner adjustment'));
        await tester.tap(find.text('Precise corner adjustment'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final apply = find.text('Apply corners and preview');
        await tester.ensureVisible(apply);
        await tester.tap(apply);
        await tester.pumpAndSettle();
        expect(result, isNotNull);
        expect(result!.corners, isNotNull);
        expect(cornerError(result!.corners!), isNull);
        expect(result!.corners!.topLeft.x, closeTo(0.001, 0.000001));
        final options = ScanOptions(
          mode: ScanMode.original,
          rotateQuarters: 1,
          brightness: 0,
          contrast: 0,
          threshold: 128,
          corners: result!.corners,
        );
        final preview = await tester.runAsync(
          () => core.previewScanPage(
            data: source,
            options: options,
            maxPixels: 128,
          ),
        );
        expect(preview!.format, 'png');
        expect(preview.validation, contains('Page corners were corrected'));
        final output = await tester.runAsync(
          () => core.prepareScanPdf(
            pages: [ScanPage(data: source, options: options)],
          ),
        );
        expect(output!.pages, 1);
        expect(output.validation, contains('Page corners were corrected'));
        final folder = Directory.systemTemp.createTempSync('ust-corner-save-');
        try {
          await tester.runAsync(
            () => core.saveOutput(
              directory: folder.path,
              filename: 'সনদ.pdf',
              output: output,
            ),
          );
          expect(
            File('${folder.path}/সনদ.pdf').readAsBytesSync(),
            output.bytes,
          );
        } finally {
          folder.deleteSync(recursive: true);
        }
        expect(source, original);
        expect(tester.takeException(), isNull);
      },
      skip: Platform.environment['UST_VISION_LIBRARY'] == null,
    );
  }
}
