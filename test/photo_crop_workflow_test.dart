import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_studio_toolkit/application/recipes.dart';
import 'package:universal_studio_toolkit/src/rust/api.dart' as core;
import 'package:universal_studio_toolkit/src/rust/frb_generated.dart';

class CropDestination extends FileSelectorPlatform {
  final String directory;
  CropDestination(this.directory);
  @override
  Future<String?> getDirectoryPath({
    String? initialDirectory,
    String? confirmButtonText,
  }) async => directory;
}

Future<void> press(WidgetTester tester, String label) async {
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
}

Future<void> finish(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 20));
    if (done()) return;
  }
  expect(done(), isTrue, reason: 'Native crop and preview must finish');
}

Finder field(String label) => find.widgetWithText(TextField, label);
Future<void> enter(WidgetTester tester, String label, String value) async {
  final target = field(label);
  await tester.ensureVisible(target);
  await tester.enterText(target, value);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FileSelectorPlatform original;
  setUpAll(() async {
    original = FileSelectorPlatform.instance;
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        Platform.environment['UST_CORE_LIBRARY'] ??
            '${Directory.current.path}/rust/target/debug/libstudio_core.so',
      ),
    );
  });
  tearDown(() => FileSelectorPlatform.instance = original);
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'visual crop, aspect, keyboard, exact pixels and real saved output at $scale',
      (tester) async {
        tester.view.physicalSize = Size(scale == 1 ? 1200 : 390, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final directory = Directory.systemTemp.createTempSync('photo-crop-');
        addTearDown(() => directory.deleteSync(recursive: true));
        FileSelectorPlatform.instance = CropDestination(directory.path);
        final source = File('rust/tests/fixtures/orientation-6.jpg')
            .readAsBytesSync();
        final unchanged = source.toList();
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData(
                brightness: scale == 1 ? Brightness.light : Brightness.dark,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: RecipesScreen(
                initialSource: source,
                initialSourceName: 'camera.jpg',
                openCrop: true,
              ),
            ),
          ),
        );
        final use = find.widgetWithText(FilledButton, 'Use crop');
        await finish(
          tester,
          () =>
              use.evaluate().isNotEmpty &&
              tester.widget<FilledButton>(use).onPressed != null,
        );
        await tester.pumpAndSettle();
        expect(find.text('Original: 20 × 40 pixels'), findsOneWidget);
        final handle = find.bySemanticsLabel('Top left crop handle');
        await tester.ensureVisible(handle);
        await tester.drag(handle, const Offset(55, 55));
        await tester.pump();
        final left = field('Left edge (pixels)');
        final before = int.parse(
          tester.widget<TextField>(left).controller!.text,
        );
        expect(before, greaterThan(0));
        await tester.ensureVisible(handle);
        await tester.tap(handle);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(
          int.parse(tester.widget<TextField>(left).controller!.text),
          before + 1,
        );
        await press(tester, 'Undo');
        final aspect = find.byType(DropdownButtonFormField<String>);
        await tester.ensureVisible(aspect);
        await tester.tap(aspect);
        await tester.pumpAndSettle();
        await tester.tap(find.text('1:1').last);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(field('Crop width (pixels)'))
              .controller!
              .text,
          '20',
        );
        expect(
          tester
              .widget<TextField>(field('Crop height (pixels)'))
              .controller!
              .text,
          '20',
        );
        await enter(tester, 'Left edge (pixels)', '2');
        await enter(tester, 'Top edge (pixels)', '3');
        await enter(tester, 'Crop width (pixels)', '8');
        await enter(tester, 'Crop height (pixels)', '8');
        await press(tester, 'Update crop');
        expect(find.text('Selected: 8 × 8 pixels'), findsOneWidget);
        await enter(tester, 'Left edge (pixels)', '200');
        await press(tester, 'Use crop');
        expect(find.text('Crop photo'), findsOneWidget);
        expect(find.textContaining('Crop must fit inside'), findsOneWidget);
        await enter(tester, 'Left edge (pixels)', '2');
        await press(tester, 'Update crop');
        await press(tester, 'Use crop');
        await tester.pumpAndSettle();
        expect(find.text('Crop photo'), findsNothing);
        await press(tester, 'Keep original dimensions');
        await press(tester, 'Prepare preview');
        await finish(
          tester,
          () => find.text('Save a copy').evaluate().isNotEmpty,
        );
        await press(tester, 'Save a copy');
        final saved = File('${directory.path}/photo.jpg');
        await finish(
          tester,
          () =>
              saved.existsSync() &&
              find
                  .textContaining('Saved: ${directory.path}')
                  .evaluate()
                  .isNotEmpty,
        );
        final dimensions = await tester.runAsync(
          () => core.photoSourceDimensions(data: saved.readAsBytesSync()),
        );
        expect(dimensions, [8, 8]);
        expect(source, unchanged);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('cancelling visual crop keeps the recipe and source unchanged', (
    tester,
  ) async {
    final source = File('rust/tests/fixtures/orientation-6.jpg')
        .readAsBytesSync();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: RecipesScreen(
            initialSource: source,
            initialSourceName: 'camera.jpg',
            openCrop: true,
          ),
        ),
      ),
    );
    await finish(
      tester,
      () =>
          find.text('Crop photo').evaluate().isNotEmpty &&
          find.byType(Image).evaluate().isNotEmpty,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await press(tester, 'Crop before resizing');
    final toggle = find.widgetWithText(SwitchListTile, 'Apply crop');
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(find.text('camera.jpg'), findsOneWidget);
    expect(
      source,
      File('rust/tests/fixtures/orientation-6.jpg').readAsBytesSync(),
    );
    expect(tester.takeException(), isNull);
  });
}
