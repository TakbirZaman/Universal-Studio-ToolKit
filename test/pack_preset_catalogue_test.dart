import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_studio_toolkit/application/custom_pack.dart';
import 'package:universal_studio_toolkit/application/preferences.dart';
import 'package:universal_studio_toolkit/application/prepared_documents.dart';
import 'package:universal_studio_toolkit/src/rust/api.dart' as core;
import 'package:universal_studio_toolkit/src/rust/frb_generated.dart';

import 'custom_pack_workflow_test.dart' show press, finish;

void main() {
  setUpAll(() async {
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        Platform.environment['UST_CORE_LIBRARY']!,
      ),
    );
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'save, restart, recover duplicate, load and delete private presets at $scale',
      (tester) async {
        final directory = Directory.systemTemp.createTempSync(
          'pack-catalogue-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        tester.view.physicalSize = Size(scale == 1 ? 1100 : 390, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final container = ProviderContainer(
          overrides: [dataDirectoryProvider.overrideWithValue(directory.path)],
        );
        addTearDown(container.dispose);
        container
            .read(preparedDocumentsProvider.notifier)
            .add(
              'private-secret.jpg',
              'jpeg',
              File('rust/tests/fixtures/orientation-1.jpg').readAsBytesSync(),
            );
        Widget app() => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            key: UniqueKey(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const CustomPackScreen(),
          ),
        );
        Finder field(String label) => find.widgetWithText(TextFormField, label);
        Future<void> edit(String label, String text) async {
          await tester.ensureVisible(field(label));
          await tester.enterText(field(label), text);
          await tester.pump();
        }

        await tester.pumpWidget(app());
        const name = 'আমার আবেদন';
        await edit('Preset name', name);
        await edit('Revision date', '2026-10-22');
        await press(tester, 'Use prepared private-secret.jpg');
        await press(tester, 'Save preset on this device');
        await finish(
          tester,
          () => find
              .textContaining('Preset saved on this device.')
              .evaluate()
              .isNotEmpty,
        );
        final stored = await tester.runAsync(
          () => core.listPackPresets(directory: directory.path),
        );
        expect(stored, hasLength(1));
        expect(stored!.single, isNot(contains('private-secret')));
        expect(stored.single, isNot(contains('sourceName')));
        expect((jsonDecode(stored.single) as Map)['name'], name);
        await edit('Revision date', '2026-10-23');
        await press(tester, 'Save preset on this device');
        await finish(
          tester,
          () => find.textContaining('already exists').evaluate().isNotEmpty,
        );
        // Restart the editor and load persisted settings, with no selected documents.
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        await tester.pumpWidget(app());
        await press(tester, 'Load saved preset');
        await tester.pump(const Duration(milliseconds: 300));
        await finish(
          tester,
          () => find.text('Use $name').evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        await press(tester, 'Use $name');
        await tester.pump(const Duration(milliseconds: 300));
        await finish(
          tester,
          () =>
              field('Preset name').evaluate().isNotEmpty &&
              tester
                      .widget<TextFormField>(field('Preset name'))
                      .controller!
                      .text ==
                  name,
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextFormField>(field('Revision date')).controller!.text,
          '2026-10-22',
        );
        expect(find.text('private-secret.jpg'), findsNothing);
        // Cancelling deletion keeps the database record; confirming removes only it.
        await press(tester, 'Load saved preset');
        await tester.pump(const Duration(milliseconds: 300));
        await finish(
          tester,
          () => find.text('Delete $name').evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        await press(tester, 'Delete $name');
        await tester.pumpAndSettle();
        await press(tester, 'Keep preset');
        await tester.pumpAndSettle();
        expect(
          await tester.runAsync(
            () => core.listPackPresets(directory: directory.path),
          ),
          hasLength(1),
        );
        await press(tester, 'Delete $name');
        await tester.pumpAndSettle();
        await press(tester, 'Delete preset');
        await finish(
          tester,
          () => find
              .text('No saved presets on this device.')
              .evaluate()
              .isNotEmpty,
        );
        expect(
          await tester.runAsync(
            () => core.listPackPresets(directory: directory.path),
          ),
          isEmpty,
        );
        expect(
          container.read(preparedDocumentsProvider).single.name,
          'private-secret.jpg',
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'unavailable local storage leaves JSON import and export available',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: CustomPackScreen())),
      );
      await press(tester, 'Save preset on this device');
      await finish(
        tester,
        () => find
            .textContaining('Local preset storage is unavailable')
            .evaluate()
            .isNotEmpty,
      );
      expect(find.text('Export preset'), findsOneWidget);
      expect(find.text('Import preset'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
