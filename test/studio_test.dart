import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_studio_toolkit/main.dart';

void main() {
  testWidgets('home exposes first-use actions and search', (tester) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    expect(find.text('Resize Photo'), findsWidgets);
    expect(find.text('Combine PDFs'), findsWidgets);
    expect(find.text('Prepare Application'), findsWidgets);
    await tester.enterText(find.byType(TextField), 'smaller');
    await tester.pump();
    expect(find.text('Get started'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'straighten');
    await tester.pump();
    expect(find.text('Get started'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'OCR');
    await tester.pump();
    expect(find.text('Get started'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'mobile workspace validates missing file without calling engine',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: ToolWorkspace(tool: Tool.photo)),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Prepare preview'));
      await tester.tap(find.text('Prepare preview'));
      await tester.pump();
      expect(
        find.textContaining('Choose a file to get started.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('large text and dark theme retain usable home', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              textScaler: TextScaler.linear(2),
            ),
            child: StudioHome(onTheme: () {}),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Resize Photo'), findsWidgets);
  });
  testWidgets(
    'keyboard preview shortcut reports missing input without engine work',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: ToolWorkspace(tool: Tool.photo)),
          ),
        ),
      );
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(
        find.textContaining('Choose a file to get started.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'physical size units are explicit and invalid DPI is recoverable',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: ToolWorkspace(tool: Tool.photo)),
          ),
        ),
      );
      await tester.tap(find.text('Set a print size in millimetres'));
      await tester.pumpAndSettle();
      expect(find.text('Width (mm)'), findsOneWidget);
      expect(find.text('Height (mm)'), findsOneWidget);
      final resolution = find.widgetWithText(
        TextFormField,
        'Print resolution (DPI)',
      );
      await tester.ensureVisible(resolution);
      await tester.enterText(resolution, '2401');
      await tester.ensureVisible(find.text('Prepare preview'));
      await tester.tap(find.text('Prepare preview'));
      await tester.pump();
      expect(find.text('Use 1–2400 DPI.'), findsOneWidget);
      await tester.ensureVisible(find.text('Set a print size in millimetres'));
      await tester.tap(find.text('Set a print size in millimetres'));
      await tester.pumpAndSettle();
      final pixels = find.widgetWithText(TextFormField, 'Width (pixels)');
      expect(tester.widget<TextFormField>(pixels).controller!.text, '300');
      expect(tester.takeException(), isNull);
    },
  );
}
