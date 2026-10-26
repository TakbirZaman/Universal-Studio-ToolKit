import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_studio_toolkit/application/image_inspector.dart';
import 'package:universal_studio_toolkit/application/safe_image_preview.dart';
import 'package:universal_studio_toolkit/application/zoomable_image.dart';
import 'package:universal_studio_toolkit/src/rust/api.dart' as core;
import 'package:universal_studio_toolkit/src/rust/frb_generated.dart';

import 'photo_crop_workflow_test.dart' show finish;

void main() {
  late Uint8List source, prepared;
  setUpAll(() async {
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        Platform.environment['UST_CORE_LIBRARY']!,
      ),
    );
    source = await File('rust/tests/fixtures/orientation-6.jpg').readAsBytes();
    prepared = (await core.runRecipe(
      data: source,
      recipeJson:
          '{"schema_version":1,"name":"Preview test",'
          '"revision_date":"2026-10-26",'
          '"steps":[{"type":"export","format":"png"}]}',
    )).bytes;
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets('compare real images and reset view at text scale $textScale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sourceCopy = Uint8List.fromList(source);
      final outputCopy = Uint8List.fromList(prepared);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ImageInspector(
                      original: source,
                      prepared: prepared,
                      transparency: true,
                    ),
                  ),
                ),
                child: const Text('Inspect'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Inspect'));
      await finish(
        tester,
        () => find.byType(InteractiveViewer).evaluate().isNotEmpty,
      );
      expect(
        tester.widget<SafeImagePreview>(find.byType(SafeImagePreview)).bytes,
        same(prepared),
      );
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final controller = viewer.transformationController!;
      for (var i = 0; i < 3; i++) {
        await tester.ensureVisible(find.byTooltip('Zoom in'));
        await tester.pump();
        await tester.tap(find.byTooltip('Zoom in'));
        await tester.pump();
      }
      expect(controller.value.getMaxScaleOnAxis(), 8);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Zoom in',
              ),
            )
            .onPressed,
        isNull,
      );
      final beforePan = controller.value.clone();
      await tester.drag(
        find.byType(InteractiveViewer),
        const Offset(-5000, -5000),
      );
      await tester.pumpAndSettle();
      expect(controller.value, isNot(beforePan));
      await tester.ensureVisible(find.text('Reset zoom'));
      await tester.pump();
      await tester.tap(find.text('Reset zoom'));
      await tester.pump();
      expect(controller.value, Matrix4.identity());
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Zoom out',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Original'));
      await tester.pump();
      await tester.tap(find.text('Original'));
      await finish(
        tester,
        () => find.byType(InteractiveViewer).evaluate().isNotEmpty,
      );
      expect(
        tester.widget<SafeImagePreview>(find.byType(SafeImagePreview)).bytes,
        same(source),
      );
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!
            .value,
        Matrix4.identity(),
      );
      expect(source, orderedEquals(sourceCopy));
      expect(prepared, orderedEquals(outputCopy));
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Inspect'), findsOneWidget);
    });
  }

  testWidgets(
    'replacement image resets zoom and stale unsupported input fails closed',
    (tester) async {
      final first = Object();
      Future<void> mount(Object identity) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomableImage(
              imageIdentity: identity,
              child: const ColoredBox(color: Colors.red),
            ),
          ),
        ),
      );
      await mount(first);
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pump();
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!
            .value
            .getMaxScaleOnAxis(),
        2,
      );
      await mount(Object());
      expect(
        tester
            .widget<InteractiveViewer>(find.byType(InteractiveViewer))
            .transformationController!
            .value,
        Matrix4.identity(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeImagePreview(
              bytes: Uint8List.fromList([1, 2, 3]),
              semanticLabel: 'Invalid image',
            ),
          ),
        ),
      );
      await finish(
        tester,
        () => find.textContaining('Could not preview').evaluate().isNotEmpty,
      );
      expect(find.byType(InteractiveViewer), findsNothing);
      expect(find.byType(Image), findsNothing);
    },
  );
}
