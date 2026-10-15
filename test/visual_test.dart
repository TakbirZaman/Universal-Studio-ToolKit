import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_studio_toolkit/main.dart';

void main() {
  setUpAll(() async {
    final loader = FontLoader('StudioRoboto');
    loader.addFont(
      Future.value(
        ByteData.sublistView(
          await File('assets/fonts/Roboto-Regular.ttf').readAsBytes(),
        ),
      ),
    );
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets('render desktop home', (tester) async {
    tester.view.physicalSize = const Size(1440, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(StudioApp),
      matchesGoldenFile('goldens/desktop-home.png'),
    );
  });
  testWidgets('render narrow home', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(child: StudioApp()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(StudioApp),
      matchesGoldenFile('goldens/mobile-home.png'),
    );
  });
}
