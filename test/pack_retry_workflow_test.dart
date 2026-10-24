import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:universal_studio_toolkit/application/custom_pack.dart';
import 'package:universal_studio_toolkit/application/pack_processor.dart';
import 'package:universal_studio_toolkit/application/prepared_documents.dart';
import 'package:universal_studio_toolkit/src/rust/api.dart' as core;
import 'package:universal_studio_toolkit/src/rust/frb_generated.dart';

import 'custom_pack_workflow_test.dart' show DestinationPicker, finish;

class RecordingProcessor extends PackProcessor {
  final calls = <int>[];
  final results = <int, core.StudioOutput>{};
  core.StudioOutput? archive;
  Completer<void>? gate;
  bool blocked = false;
  @override
  Future<core.StudioOutput> prepare(
    Uint8List bytes,
    String preset,
    int index,
  ) async {
    calls.add(index);
    final result = await super.prepare(bytes, preset, index);
    final pending = gate;
    if (pending != null) {
      blocked = true;
      await pending.future;
      gate = null;
    }
    results[index] = result;
    return result;
  }

  @override
  Future<core.StudioOutput> build(
    List<core.StudioOutput?> outputs,
    String preset,
  ) async {
    archive = await super.build(outputs, preset);
    return archive!;
  }
}

Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

void main() {
  late FileSelectorPlatform picker;
  setUpAll(() async {
    picker = FileSelectorPlatform.instance;
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        Platform.environment['UST_CORE_LIBRARY']!,
      ),
    );
  });
  tearDown(() => FileSelectorPlatform.instance = picker);
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'retry only failed or edited document and save verified pack at $scale',
      (tester) async {
        final destination = Directory.systemTemp.createTempSync('pack-retry-');
        addTearDown(() => destination.deleteSync(recursive: true));
        FileSelectorPlatform.instance = DestinationPicker(destination.path);
        tester.view.physicalSize = Size(scale == 1 ? 1200 : 390, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final processor = RecordingProcessor();
        final container = ProviderContainer(
          overrides: [packProcessorProvider.overrideWithValue(processor)],
        );
        addTearDown(container.dispose);
        final documents = container.read(preparedDocumentsProvider.notifier);
        documents.add(
          'portrait.jpg',
          'jpeg',
          File('rust/tests/fixtures/orientation-1.jpg').readAsBytesSync(),
        );
        documents.add('broken.jpg', 'jpeg', Uint8List.fromList([1, 2, 3]));
        documents.add(
          'fixed.jpg',
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
        await tap(tester, find.text('Use prepared portrait.jpg'));
        await tap(tester, find.text('Add document slot'));
        await tap(tester, find.text('Use prepared broken.jpg').last);
        await tap(tester, find.text('Required document').last);
        await tap(tester, find.text('Prepare and validate pack'));
        await finish(
          tester,
          () =>
              find.text('Retry document').evaluate().isNotEmpty &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        expect(processor.calls, [0, 1]);
        expect(find.text('Save application ZIP'), findsNothing);
        expect(find.textContaining('Document ready'), findsOneWidget);
        final first = processor.results[0]!;
        await tap(tester, find.text('Retry document'));
        await finish(
          tester,
          () =>
              processor.calls.length == 3 &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty,
        );
        expect(processor.calls, [0, 1, 1]);
        expect(identical(processor.results[0], first), isTrue);
        await tap(tester, find.text('Use prepared fixed.jpg').last);
        await tap(tester, find.text('Prepare and validate pack'));
        await finish(
          tester,
          () => find.text('Save application ZIP').evaluate().isNotEmpty,
        );
        expect(processor.calls, [0, 1, 1, 1]);
        expect(identical(processor.results[0], first), isTrue);
        final second = processor.results[1]!;
        final width = find
            .widgetWithText(TextFormField, 'Output width (pixels)')
            .first;
        await tester.ensureVisible(width);
        await tester.pump();
        await tester.enterText(width, '301');
        await tester.pump();
        expect(find.textContaining('Document ready'), findsOneWidget);
        expect(find.text('Save application ZIP'), findsNothing);
        await tap(tester, find.text('Prepare and validate pack'));
        await finish(
          tester,
          () => find.text('Save application ZIP').evaluate().isNotEmpty,
        );
        expect(processor.calls, [0, 1, 1, 1, 0]);
        expect(identical(processor.results[1], second), isTrue);
        // An explicitly empty optional slot crosses the nullable native boundary.
        await tap(tester, find.text('Add document slot'));
        await tap(tester, find.text('Required document').last);
        await tap(tester, find.text('Prepare and validate pack'));
        await finish(
          tester,
          () => find.text('Save application ZIP').evaluate().isNotEmpty,
        );
        expect(processor.calls, [0, 1, 1, 1, 0]);
        await tap(tester, find.text('Save application ZIP'));
        final target = File('${destination.path}/application-pack.zip');
        await finish(
          tester,
          () =>
              target.existsSync() &&
              find.textContaining('Saved and verified').evaluate().isNotEmpty,
        );
        final bytes = await tester.runAsync(target.readAsBytes);
        expect(bytes, orderedEquals(processor.archive!.bytes));
        await tester.runAsync(
          () => core.validatePreparedOutput(
            output: core.StudioOutput(
              bytes: bytes!,
              format: 'zip',
              validation: '',
            ),
            filename: 'application-pack.zip',
          ),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('stop retains active success and resume skips it', (
    tester,
  ) async {
    final processor = RecordingProcessor()..gate = Completer<void>();
    final container = ProviderContainer(
      overrides: [packProcessorProvider.overrideWithValue(processor)],
    );
    addTearDown(container.dispose);
    container
        .read(preparedDocumentsProvider.notifier)
        .add(
          'photo.jpg',
          'jpeg',
          File('rust/tests/fixtures/orientation-1.jpg').readAsBytesSync(),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CustomPackScreen()),
      ),
    );
    await tap(tester, find.text('Use prepared photo.jpg'));
    await tap(tester, find.text('Add document slot'));
    await tap(tester, find.text('Use prepared photo.jpg').last);
    await tap(tester, find.text('Prepare and validate pack'));
    await finish(tester, () => processor.blocked);
    await tap(tester, find.text('Stop after current operation'));
    processor.gate!.complete();
    await finish(
      tester,
      () => find
          .textContaining('Stopped after the active operation.')
          .evaluate()
          .isNotEmpty,
    );
    expect(processor.calls, [0]);
    expect(find.textContaining('Document ready'), findsOneWidget);
    expect(find.text('Save application ZIP'), findsNothing);
    await tap(tester, find.text('Prepare and validate pack'));
    await finish(
      tester,
      () => find.text('Save application ZIP').evaluate().isNotEmpty,
    );
    expect(processor.calls, [0, 1]);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
