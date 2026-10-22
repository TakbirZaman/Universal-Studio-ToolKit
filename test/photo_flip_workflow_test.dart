import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:universal_studio_toolkit/application/recipes.dart';
import 'package:universal_studio_toolkit/src/rust/api.dart' as core;
import 'package:universal_studio_toolkit/src/rust/frb_generated.dart';

import 'photo_crop_workflow_test.dart' show CropDestination, finish;

Future<Uint8List> pixels(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  frame.image.dispose();
  codec.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  late Uint8List source, baseline;
  late FileSelectorPlatform original;
  setUpAll(() async {
    original = FileSelectorPlatform.instance;
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        Platform.environment['UST_CORE_LIBRARY']!,
      ),
    );
    source = await File('rust/tests/fixtures/orientation-6.jpg').readAsBytes();
    baseline = (await core.runRecipe(
      data: source,
      recipeJson: jsonEncode({
        'schema_version': 1,
        'name': 'Original',
        'revision_date': '2026-10-22',
        'steps': [
          {'type': 'export', 'format': 'png'},
        ],
      }),
    )).bytes;
  });
  tearDownAll(() => FileSelectorPlatform.instance = original);
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'save reflected original pixels and versioned settings at $scale',
      (tester) async {
        final directory = Directory.systemTemp.createTempSync('photo-flip-');
        addTearDown(() => directory.deleteSync(recursive: true));
        FileSelectorPlatform.instance = CropDestination(directory.path);
        tester.view.physicalSize = Size(scale == 1 ? 1200 : 390, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: RecipesScreen(
                initialSource: source,
                initialSourceName: 'original.jpg',
              ),
            ),
          ),
        );
        Future<void> tap(Finder target) async {
          await tester.ensureVisible(target);
          await tester.pump();
          await tester.tap(target);
          await tester.pump();
        }

        Future<void> edit(String label, String value) async {
          final target = find.widgetWithText(TextFormField, label);
          await tester.ensureVisible(target);
          await tester.pump();
          await tester.enterText(target, value);
          await tester.pump();
        }

        await tap(find.text('Keep original dimensions'));
        await tap(find.text('Mirror left to right'));
        if (scale == 2) await tap(find.text('Flip top to bottom'));
        await tap(find.byKey(const ValueKey('Output format-jpeg')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('PNG').last);
        await tester.pumpAndSettle();
        await edit('Output filename including extension', 'reflected.png');
        await tap(find.text('Export recipe'));
        final recipeFile = File('${directory.path}/recipe.json');
        await finish(tester, () => recipeFile.existsSync());
        final json = await tester.runAsync(recipeFile.readAsString);
        final settings = jsonDecode(json!) as Map;
        expect(settings['schema_version'], 4);
        expect(
          (settings['steps'] as List).where((s) => s['type'] == 'flip').single,
          {'type': 'flip', 'horizontal': true, 'vertical': scale == 2},
        );
        await finish(
          tester,
          () => find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        await tap(find.text('Prepare preview'));
        await finish(
          tester,
          () => find.text('Save a copy').evaluate().isNotEmpty,
        );
        await tap(find.text('Save a copy'));
        final target = File('${directory.path}/reflected.png');
        await finish(
          tester,
          () =>
              target.existsSync() &&
              find
                  .textContaining('Your original file is unchanged.')
                  .evaluate()
                  .isNotEmpty,
        );
        final comparison = await tester.runAsync(
          () async => [
            await pixels(baseline),
            await pixels(await target.readAsBytes()),
          ],
        );
        final expected = comparison![0], actual = comparison[1];
        expect(actual.length, 20 * 40 * 4);
        for (var y = 0; y < 40; y++) {
          for (var x = 0; x < 20; x++) {
            final sx = 19 - x, sy = scale == 2 ? 39 - y : y;
            for (var channel = 0; channel < 4; channel++) {
              expect(
                actual[(y * 20 + x) * 4 + channel],
                expected[(sy * 20 + sx) * 4 + channel],
              );
            }
          }
        }
        final originalBytes = await tester.runAsync(
          () => File('rust/tests/fixtures/orientation-6.jpg').readAsBytes(),
        );
        expect(source, orderedEquals(originalBytes!));
        await tap(find.text('Mirror left to right'));
        expect(find.text('Save a copy'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
