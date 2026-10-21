import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:universal_studio_toolkit/application/recipes.dart';
import 'package:universal_studio_toolkit/design/theme.dart';
import 'package:universal_studio_toolkit/src/rust/frb_generated.dart';

class RecipePicker extends FileSelectorPlatform {
  final Uint8List bytes;
  final String folder;
  RecipePicker(this.bytes, this.folder);
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async =>
      XFile.fromData(bytes, name: 'noisy-photo.png', path: 'noisy-photo.png');
  @override
  Future<String?> getDirectoryPath({
    String? initialDirectory,
    String? confirmButtonText,
  }) async => folder;
}

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 250; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 5));
    if (ready()) return;
  }
  expect(ready(), isTrue, reason: 'Actual flexible processing must finish.');
}

Future<void> click(WidgetTester tester, String text) async {
  await waitFor(
    tester,
    () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
  );
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

Future<void> field(WidgetTester tester, String label, String value) async {
  final target = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(target);
  await tester.enterText(target, value);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List source;
  late FileSelectorPlatform picker;
  setUpAll(() async {
    picker = FileSelectorPlatform.instance;
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        Platform.environment['UST_CORE_LIBRARY'] ??
            '${Directory.current.path}/rust/target/debug/libstudio_core.so',
      ),
    );
    const w = 256, h = 192;
    final pixels = Uint8List(w * h * 4);
    var seed = 17;
    for (var i = 0; i < pixels.length; i += 4) {
      for (var channel = 0; channel < 3; channel++) {
        seed = (seed * 1664525 + 1013904223) & 0xffffffff;
        pixels[i + channel] = seed >> 24;
      }
      pixels[i + 3] = 255;
    }
    final decoded = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      w,
      h,
      ui.PixelFormat.rgba8888,
      decoded.complete,
    );
    final image = await decoded.future;
    source = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    image.dispose();
    for (final e in {
      'StudioRoboto': 'assets/fonts/Roboto-Regular.ttf',
      'StudioNotoBengali': 'assets/fonts/NotoSansBengali.ttf',
    }.entries) {
      final loader = FontLoader(e.key)
        ..addFont(
          Future.value(ByteData.sublistView(File(e.value).readAsBytesSync())),
        );
      await loader.load();
    }
  });
  tearDownAll(() => FileSelectorPlatform.instance = picker);
  for (final variant in [
    ('desktop', const Size(1440, 1600), 1.0),
    ('narrow', const Size(390, 1100), 2.0),
  ]) {
    testWidgets(
      'approved flexible dimensions, invalid minima, recipe and actual JPEG save ${variant.$1}',
      (tester) async {
        final folder = Directory.systemTemp.createTempSync('ust-flex-recipe-');
        addTearDown(() => folder.deleteSync(recursive: true));
        FileSelectorPlatform.instance = RecipePicker(source, folder.path);
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
              home: const RecipesScreen(),
            ),
          ),
        );
        await click(
          tester,
          'Allow smaller dimensions to meet the file-size limit',
        );
        await field(tester, 'Maximum width (pixels)', '256');
        await field(tester, 'Maximum height (pixels)', '192');
        await field(tester, 'Minimum width (pixels)', '999');
        await field(tester, 'Minimum height (pixels)', '72');
        await field(tester, 'Maximum file size', '8');
        await click(tester, 'Prepare preview');
        expect(
          find.text('Must not exceed the maximum dimension.'),
          findsOneWidget,
        );
        await field(tester, 'Minimum width (pixels)', '96');
        await click(tester, 'Export recipe file');
        await waitFor(
          tester,
          () =>
              File('${folder.path}/recipe.json').existsSync() &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        final recipe =
            jsonDecode(File('${folder.path}/recipe.json').readAsStringSync())
                as Map;
        expect(recipe['schema_version'], 3);
        final resize =
            (recipe['steps'] as List).firstWhere(
                  (dynamic s) => s['type'] == 'flexible_resize',
                )
                as Map;
        expect((resize['minimum_width'], resize['minimum_height']), (96, 72));
        await click(tester, 'Choose a photo');
        await waitFor(
          tester,
          () => find.text('noisy-photo.png').evaluate().isNotEmpty,
        );
        await click(tester, 'Prepare preview');
        await waitFor(
          tester,
          () => find
              .textContaining('Approved dimensions verified:')
              .evaluate()
              .isNotEmpty,
        );
        expect(
          find.textContaining('Larger unsampled sizes may also fit'),
          findsOneWidget,
        );
        await click(tester, 'Save a copy');
        await waitFor(
          tester,
          () => File('${folder.path}/photo.jpg').existsSync(),
        );
        final saved = File('${folder.path}/photo.jpg').readAsBytesSync();
        expect(saved.length, lessThan(8192));
        await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(saved);
          final image = (await codec.getNextFrame()).image;
          expect(image.width, inInclusiveRange(96, 255));
          expect(image.height, inInclusiveRange(72, 191));
          image.dispose();
          codec.dispose();
        });
        final outputs = Platform.environment['UST_FLEX_OUTPUTS'];
        if (outputs != null) {
          Directory(outputs).createSync(recursive: true);
          File('$outputs/flexible-${variant.$1}.jpg').writeAsBytesSync(saved);
          File(
            '$outputs/recipe-${variant.$1}.json',
          ).writeAsStringSync(jsonEncode(recipe));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
