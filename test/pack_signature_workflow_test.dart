import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:universal_studio_toolkit/main.dart';
import 'package:universal_studio_toolkit/design/theme.dart';
import 'package:universal_studio_toolkit/src/rust/api.dart' as core;
import 'package:universal_studio_toolkit/src/rust/frb_generated.dart';

// Substitute only operating-system selection. Processing, validation and writes
// run through the actual Rust bridge and filesystem export service.
class WorkflowPicker extends FileSelectorPlatform {
  final List<XFile?> choices;
  final String destination;
  var index = 0;
  WorkflowPicker(this.choices, this.destination);
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => choices[index++];
  @override
  Future<String?> getDirectoryPath({
    String? initialDirectory,
    String? confirmButtonText,
  }) async => destination;
}

Future<void> settled(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 150; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 5));
    if (condition()) return;
  }
  expect(
    condition(),
    isTrue,
    reason: 'Actual processing and saving must finish.',
  );
}

Future<void> click(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pump();
}

XFile source(Uint8List data, String name) =>
    XFile.fromData(data, name: name, path: name);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List photo, replacement, signature, certificate;
  late FileSelectorPlatform originalPicker;
  setUpAll(() async {
    originalPicker = FileSelectorPlatform.instance;
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        Platform.environment['UST_CORE_LIBRARY'] ??
            '${Directory.current.path}/rust/target/debug/libstudio_core.so',
      ),
    );
    photo = File('rust/tests/fixtures/orientation-6.jpg').readAsBytesSync();
    replacement = File(
      'rust/tests/fixtures/orientation-3.jpg',
    ).readAsBytesSync();
    certificate = (await core.scanPdf(inputs: [photo])).bytes;
    const width = 400, height = 160;
    final pixels = Uint8List(width * height * 4);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final black =
            x > 35 && x < 365 && (y - (80 + math.sin(x / 18) * 20)).abs() < 3;
        final i = (y * width + x) * 4;
        pixels[i] = pixels[i + 1] = pixels[i + 2] = black ? 0 : 255;
        pixels[i + 3] = 255;
      }
    }
    final decoded = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      decoded.complete,
    );
    final image = await decoded.future;
    signature = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    image.dispose();
    for (final entry in {
      'StudioRoboto': 'assets/fonts/Roboto-Regular.ttf',
      'StudioNotoBengali': 'assets/fonts/NotoSansBengali.ttf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(
          Future.value(
            ByteData.sublistView(File(entry.value).readAsBytesSync()),
          ),
        );
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  tearDownAll(() => FileSelectorPlatform.instance = originalPicker);

  for (final variant in [
    ('desktop', const Size(1440, 1600), 1.0),
    ('narrow', const Size(390, 1100), 2.0),
  ]) {
    Future<void> launch(WidgetTester tester, Tool tool) async {
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
            home: Scaffold(body: ToolWorkspace(tool: tool)),
          ),
        ),
      );
    }

    testWidgets(
      'application pack replaces one slot and saves verified ZIP ${variant.$1}',
      (tester) async {
        final directory = Directory.systemTemp.createTempSync(
          'ust-pack-workflow-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final old = File('${directory.path}/application-pack.zip')
          ..writeAsBytesSync([4, 5, 6]);
        FileSelectorPlatform.instance = WorkflowPicker([
          source(photo, 'ছবি-original.jpg'),
          source(signature, 'signature-source.png'),
          source(certificate, 'certificate-source.pdf'),
          null,
          source(replacement, 'ছবি-corrected.jpg'),
        ], directory.path);
        await launch(tester, Tool.pack);
        for (final pair in [
          ('Choose photo', 'ছবি-original.jpg'),
          ('Choose signature', 'signature-source.png'),
          ('Choose certificate PDF', 'certificate-source.pdf'),
        ]) {
          await click(tester, pair.$1);
          await settled(tester, () => find.text(pair.$2).evaluate().isNotEmpty);
        }
        await click(
          tester,
          'Replace photo',
        ); // Cancel preserves all three sources.
        await settled(
          tester,
          () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
        );
        expect(find.text('ছবি-original.jpg'), findsOneWidget);
        expect(find.text('signature-source.png'), findsOneWidget);
        expect(find.text('certificate-source.pdf'), findsOneWidget);
        await click(tester, 'Replace photo');
        await settled(
          tester,
          () => find.text('ছবি-corrected.jpg').evaluate().isNotEmpty,
        );
        expect(find.text('ছবি-original.jpg'), findsNothing);
        expect(find.text('signature-source.png'), findsOneWidget);
        expect(find.text('certificate-source.pdf'), findsOneWidget);
        await click(tester, 'Prepare preview');
        await settled(
          tester,
          () => find
              .text('Choose location and save a copy')
              .evaluate()
              .isNotEmpty,
        );
        expect(find.textContaining('photo.jpg:'), findsOneWidget);
        expect(find.textContaining('300 × 300 pixels'), findsWidgets);
        expect(find.textContaining('signature.png:'), findsOneWidget);
        expect(find.textContaining('certificate.pdf:'), findsOneWidget);
        await click(tester, 'Choose location and save a copy');
        await settled(
          tester,
          () => find.textContaining('already exists').evaluate().isNotEmpty,
        );
        expect(old.readAsBytesSync(), [4, 5, 6]);
        final error = find.textContaining('already exists');
        expect(
          tester.getRect(error).top,
          greaterThan(tester.getRect(find.text('4  Save a copy')).top),
        );
        final filename = find.byType(TextField).last;
        await tester.ensureVisible(filename);
        await tester.enterText(filename, 'আবেদন.zip');
        await click(tester, 'Choose location and save a copy');
        await settled(
          tester,
          () => find.textContaining('Saved and verified').evaluate().isNotEmpty,
        );
        final saved = File('${directory.path}/আবেদন.zip');
        expect(saved.existsSync(), isTrue);
        expect(saved.readAsBytesSync().take(2), [0x50, 0x4b]);
        final outputs = Platform.environment['UST_WORKFLOW_OUTPUTS'];
        if (outputs != null) {
          Directory(outputs).createSync(recursive: true);
          saved.copySync('$outputs/pack-${variant.$1}.zip');
        }
        expect(old.readAsBytesSync(), [4, 5, 6]);
        expect(
          photo,
          File('rust/tests/fixtures/orientation-6.jpg').readAsBytesSync(),
        );
        expect(tester.takeException(), isNull);
        await click(tester, 'Process another');
        expect(find.text('Saved and verified'), findsNothing);
        expect(find.text('Choose photo'), findsOneWidget);
        expect(saved.existsSync(), isTrue);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'signature cleanup saves actual transparent pixels ${variant.$1}',
      (tester) async {
        final directory = Directory.systemTemp.createTempSync(
          'ust-signature-workflow-',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        FileSelectorPlatform.instance = WorkflowPicker([
          source(signature, 'signature-source.png'),
        ], directory.path);
        await launch(tester, Tool.signature);
        await click(tester, 'Choose image');
        await settled(
          tester,
          () => find.text('signature-source.png').evaluate().isNotEmpty,
        );
        await click(tester, 'Prepare preview');
        await settled(
          tester,
          () => find
              .text('Choose location and save a copy')
              .evaluate()
              .isNotEmpty,
        );
        await click(tester, 'Choose location and save a copy');
        await settled(
          tester,
          () => find.textContaining('Saved and verified').evaluate().isNotEmpty,
        );
        final saved = File('${directory.path}/signature.png').readAsBytesSync();
        await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(saved);
          final image = (await codec.getNextFrame()).image;
          expect((image.width, image.height), (300, 100));
          final rgba = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          final alpha = [for (var i = 3; i < rgba.length; i += 4) rgba[i]];
          expect(alpha, contains(0));
          expect(alpha, contains(255));
          image.dispose();
          codec.dispose();
        });
        final outputs = Platform.environment['UST_WORKFLOW_OUTPUTS'];
        if (outputs != null) {
          Directory(outputs).createSync(recursive: true);
          File('$outputs/signature-${variant.$1}.png').writeAsBytesSync(saved);
        }
        expect(tester.takeException(), isNull);
        await click(tester, 'Process another');
        expect(find.text('Choose image'), findsOneWidget);
        expect(
          File('${directory.path}/signature.png').readAsBytesSync(),
          saved,
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
