import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:universal_studio_toolkit/design/theme.dart';
import 'package:universal_studio_toolkit/main.dart';
import 'package:universal_studio_toolkit/src/rust/frb_generated.dart';

// Only the operating-system picker is substituted. Image processing, typed FFI,
// output validation and result UI all use the real application services.
class FixturePicker extends FileSelectorPlatform {
  final Uint8List bytes;
  FixturePicker(this.bytes);
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => XFile.fromData(
    bytes,
    name: 'synthetic-orientation.jpg',
    path: 'synthetic-orientation.jpg',
    mimeType: 'image/jpeg',
  );
}

void main() {
  late Uint8List source;
  late FileSelectorPlatform originalPicker;
  setUpAll(() async {
    source = await File('rust/tests/fixtures/orientation-6.jpg').readAsBytes();
    originalPicker = FileSelectorPlatform.instance;
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        Platform.environment['UST_CORE_LIBRARY'] ??
            '${Directory.current.path}/rust/target/debug/libstudio_core.so',
      ),
    );
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
    FileSelectorPlatform.instance = originalPicker;
  });
  for (final variant in [
    ('desktop', const Size(1440, 1400), Brightness.light, 1.0),
    ('narrow-dark', const Size(390, 1100), Brightness.dark, 2.0),
  ]) {
    testWidgets(
      'select, adjust, process and review physical photo ${variant.$1}',
      (tester) async {
        FileSelectorPlatform.instance = FixturePicker(source);
        tester.view.physicalSize = variant.$2;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ProviderScope(
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: StudioTokens.theme(variant.$3),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(variant.$4)),
                  child: child!,
                ),
                home: const Scaffold(body: ToolWorkspace(tool: Tool.photo)),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Choose image'));
        for (var attempt = 0; attempt < 20; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
          if (find.text('synthetic-orientation.jpg').evaluate().isNotEmpty) {
            break;
          }
        }
        expect(find.text('synthetic-orientation.jpg'), findsOneWidget);
        await tester.ensureVisible(
          find.text('Set a print size in millimetres'),
        );
        await tester.tap(find.text('Set a print size in millimetres'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Prepare preview'));
        await tester.tap(find.text('Prepare preview'));
        for (var attempt = 0; attempt < 100; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
          if (find.textContaining('Saved print size:').evaluate().isNotEmpty) {
            break;
          }
        }
        final measurements = find.textContaining(
          'Saved print size: 34.97 × 44.96 mm',
        );
        expect(measurements, findsOneWidget);
        expect(find.textContaining('413 × 531 pixels'), findsOneWidget);
        expect(find.text('Choose location and save a copy'), findsOneWidget);
        await tester.ensureVisible(measurements);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final captureDirectory = Platform.environment['UST_CAPTURE_PHYSICAL'];
        if (captureDirectory != null) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '$captureDirectory/physical-${variant.$1}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
