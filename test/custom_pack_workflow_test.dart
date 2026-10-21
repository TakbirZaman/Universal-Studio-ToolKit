import 'dart:convert';
import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_studio_toolkit/application/custom_pack.dart';
import 'package:universal_studio_toolkit/application/prepared_documents.dart';
import 'package:universal_studio_toolkit/src/rust/frb_generated.dart';

class DestinationPicker extends FileSelectorPlatform {
  final String destination;
  String? importPath;
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => importPath == null ? null : XFile(importPath!);
  DestinationPicker(this.destination);
  @override
  Future<String?> getDirectoryPath({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => destination;
}

Future<void> press(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
}

Future<void> finish(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    if (done()) return;
  }
  expect(done(), isTrue, reason: 'Native processing must finish');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FileSelectorPlatform picker;
  setUpAll(() async {
    picker = FileSelectorPlatform.instance;
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        Platform.environment['UST_CORE_LIBRARY'] ??
            '${Directory.current.path}/rust/target/debug/libstudio_core.so',
      ),
    );
  });
  tearDown(() => FileSelectorPlatform.instance = picker);
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'custom pack reuses session input and saves real ZIP at text scale $scale',
      (tester) async {
        tester.view.physicalSize = Size(scale == 1 ? 1100 : 390, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final dir = Directory.systemTemp.createTempSync('custom-pack-');
        addTearDown(() => dir.deleteSync(recursive: true));
        FileSelectorPlatform.instance = DestinationPicker(dir.path);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container
            .read(preparedDocumentsProvider.notifier)
            .add(
              'portrait.jpg',
              'jpeg',
              File('rust/tests/fixtures/orientation-6.jpg').readAsBytesSync(),
            );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const CustomPackScreen(),
            ),
          ),
        );
        await press(tester, 'Export preset');
        final presetFile = File('${dir.path}/application-preset.json');
        await finish(tester, () => presetFile.existsSync());
        final exported =
            jsonDecode(presetFile.readAsStringSync()) as Map<String, dynamic>;
        expect(exported['slots'], hasLength(1));
        expect(presetFile.readAsStringSync().contains('sourceName'), isFalse);
        await finish(
          tester,
          () => find
              .textContaining('Preset saved and verified')
              .evaluate()
              .isNotEmpty,
        );
        final presetName = find.widgetWithText(TextFormField, 'Preset name');
        await tester.ensureVisible(presetName);
        await tester.enterText(presetName, 'Changed settings');
        await tester.pump();
        (FileSelectorPlatform.instance as DestinationPicker).importPath =
            presetFile.path;
        await press(tester, 'Import preset');
        await finish(
          tester,
          () => find.text('My application').evaluate().isNotEmpty,
        );
        await press(tester, 'Prepare and validate pack');
        await finish(
          tester,
          () => find
              .textContaining('choose a source for this required slot')
              .evaluate()
              .isNotEmpty,
        );
        await press(tester, 'Use prepared portrait.jpg');
        await press(tester, 'Prepare and validate pack');
        await finish(
          tester,
          () => find.text('Save application ZIP').evaluate().isNotEmpty,
        );
        expect(tester.takeException(), isNull);
        final filename = find.widgetWithText(TextFormField, 'ZIP filename');
        await tester.ensureVisible(filename);
        await tester.enterText(filename, 'wrong.pdf');
        await tester.pump();
        await press(tester, 'Save application ZIP');
        await finish(
          tester,
          () => find
              .textContaining('Filename extension must match')
              .evaluate()
              .isNotEmpty,
        );
        expect(File('${dir.path}/wrong.pdf').existsSync(), isFalse);
        expect(find.text('Save application ZIP'), findsOneWidget);
        await tester.ensureVisible(filename);
        await tester.enterText(filename, 'custom.zip');
        await tester.pump();
        expect(find.text('Save application ZIP'), findsOneWidget);
        await press(tester, 'Save application ZIP');
        await finish(tester, () => File('${dir.path}/custom.zip').existsSync());
        final bytes = File('${dir.path}/custom.zip').readAsBytesSync();
        expect(bytes.take(2), [80, 75]);
        await finish(
          tester,
          () => find.textContaining('Saved and verified').evaluate().isNotEmpty,
        );
        expect(tester.takeException(), isNull);
        // Editing requirements invalidates the previous pack.
        final width = find.widgetWithText(
          TextFormField,
          'Output width (pixels)',
        );
        await tester.ensureVisible(width);
        await tester.enterText(width, '0');
        await tester.pump();
        expect(find.text('Save application ZIP'), findsNothing);
        await press(tester, 'Prepare and validate pack');
        expect(find.text('Enter a positive whole number.'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
