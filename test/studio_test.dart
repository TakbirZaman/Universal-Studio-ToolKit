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
  testWidgets('keyboard preview shortcut reports missing input without engine work', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(
      home: Scaffold(body: ToolWorkspace(tool: Tool.photo)),
    )));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(find.textContaining('Choose a file to get started.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
