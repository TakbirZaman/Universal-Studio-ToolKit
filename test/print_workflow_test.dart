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

class PrintPicker extends FileSelectorPlatform {
  final Uint8List bytes;
  PrintPicker(this.bytes);
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => XFile.fromData(
    bytes,
    name: 'prepared-photo.png',
    path: 'prepared-photo.png',
    mimeType: 'image/png',
  );
}

Future<void> settleNative(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 120; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 1));
    if (ready()) return;
  }
  expect(
    ready(),
    isTrue,
    reason: 'Native PDF preparation and display must settle.',
  );
}

void main() {
  late Uint8List source;
  late FileSelectorPlatform original;
  setUpAll(() async {
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        Platform.environment['UST_CORE_LIBRARY'] ??
            '${Directory.current.path}/../universal-studio-current/rust/target/debug/libstudio_core.so',
      ),
    );
    final bytes = await File(
      'rust/tests/fixtures/orientation-6.jpg',
    ).readAsBytes();
    source = (await core.resizePhoto(
      data: bytes,
      width: 300,
      height: 300,
      png: true,
      cover: true,
      limitKib: null,
      minimumQuality: 60,
      flatten: false,
      rotation: 0,
      signatureThreshold: null,
    )).bytes;
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
  });
  tearDownAll(() {
    FileSelectorPlatform.instance = original;
  });
  for (final variant in [
    ('desktop', const Size(1440, 1600), 1.0),
    ('narrow', const Size(390, 1100), 2.0),
  ]) {
    testWidgets('custom sheet recovery and actual print PDF ${variant.$1}', (
      tester,
    ) async {
      tester.view.physicalSize = variant.$2;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      FileSelectorPlatform.instance = PrintPicker(source);
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
            home: const Scaffold(body: ToolWorkspace(tool: Tool.print)),
          ),
        ),
      );
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      Finder field(String label) => find.widgetWithText(TextFormField, label);
      Future<void> enter(String label, String value) async {
        await tester.ensureVisible(field(label));
        await tester.enterText(field(label), value);
        await tester.pump();
      }

      await tap(find.text('Choose image'));
      await settleNative(
        tester,
        () => find.text('prepared-photo.png').evaluate().isNotEmpty,
      );
      await enter('Number of copies', '4');
      await tap(find.text('A4 · 210 × 297 mm'));
      await tap(find.text('Custom paper').last);
      await enter('Paper width (mm)', '120');
      await enter('Paper height (mm)', '90');
      await tap(find.text('Margins, spacing & resolution'));
      await enter('Paper margins (mm)', '5');
      await enter('Space between photos (mm)', '10');
      await tap(find.text('Add cutting guides'));
      await tap(find.text('Set photo sampling DPI'));
      await enter('Photo sampling DPI', '300');
      await enter('Space between photos (mm)', '2');
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Add cutting guides'),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<TextFormField>(field('Space between photos (mm)'))
            .validator!('2'),
        'Use 3.0–1000.0 mm.',
      );
      await tap(find.text('Prepare preview'));
      expect(
        find.textContaining('Check the highlighted print settings.'),
        findsOneWidget,
      );
      expect(find.text('Use 3.0–1000.0 mm.'), findsOneWidget);
      await enter('Space between photos (mm)', '10');
      await tester.ensureVisible(find.text('Prepare preview'));
      await tester.tap(find.text('Prepare preview'));
      await tester.pump();
      await settleNative(
        tester,
        () => find.byType(PdfPreview).evaluate().isNotEmpty,
      );
      final preview = tester.widget<PdfPreview>(find.byType(PdfPreview));
      expect(preview.pageCount, 1);
      expect(find.textContaining('paper 120.00 × 90.00 mm'), findsOneWidget);
      expect(find.textContaining('299.72 DPI'), findsOneWidget);
      await settleNative(
        tester,
        () => find
            .descendant(
              of: find.byType(PdfPreview),
              matching: find.byType(RawImage),
            )
            .evaluate()
            .any((e) => (e.widget as RawImage).image != null),
      );
      expect(find.text('Choose location and save a copy'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
