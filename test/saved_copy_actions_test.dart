import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:universal_studio_toolkit/application/saved_copy_actions.dart';

class ActionAdapter extends SavedCopyAccess {
  final Set<SavedAction> supported;
  final calls = <SavedAction>[];
  ActionAdapter(this.supported);
  @override
  Future<Set<SavedAction>> capabilities(String location, String format) async =>
      supported;
  @override
  Future<void> request(
    SavedAction action,
    String location,
    String format,
    Uint8List bytes,
  ) async {
    calls.add(action);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'only saved local document paths and content URIs can reach a handoff',
    () {
      validateSavedTarget('/tmp/আবেদন.pdf', 'pdf', SavedPlatform.linux);
      validateSavedTarget(
        r'C:\Documents\ছবি.png',
        'png',
        SavedPlatform.windows,
      );
      validateSavedTarget(
        'content://provider/document/123',
        'pdf',
        SavedPlatform.android,
      );
      for (final location in [
        'https://example.com/x.pdf',
        'file:///tmp/x.pdf',
        '../x.pdf',
        '/tmp/x.exe',
        '/tmp/x.pdf\u0000.exe',
      ]) {
        expect(
          () => validateSavedTarget(location, 'pdf', SavedPlatform.linux),
          throwsFormatException,
        );
      }
      expect(
        () => validateSavedTarget(
          'file:///tmp/x.pdf',
          'pdf',
          SavedPlatform.android,
        ),
        throwsFormatException,
      );
      expect(
        () => validateSavedTarget(
          'content:///document/123',
          'pdf',
          SavedPlatform.android,
        ),
        throwsFormatException,
      );
    },
  );
  test(
    'changed desktop copies are rejected before any native handoff',
    () async {
      final folder = Directory.systemTemp.createTempSync('ust-saved-action-');
      try {
        final path = '${folder.path}/copy.pdf';
        File(path).writeAsBytesSync([1, 2, 4]);
        final access = PlatformSavedCopyAccess(platform: SavedPlatform.linux);
        await expectLater(
          access.request(
            SavedAction.open,
            path,
            'pdf',
            Uint8List.fromList([1, 2, 3]),
          ),
          throwsFormatException,
        );
        expect(File(path).readAsBytesSync(), [1, 2, 4]);
      } finally {
        folder.deleteSync(recursive: true);
      }
    },
  );
  test(
    'Android handoff sends a verified-copy URI and MIME, never document bytes',
    () async {
      const channel = MethodChannel('dev.universalstudio/saved-test');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'capabilities') {
              return {'open': true, 'share': true, 'reveal': false};
            }
            return null;
          });
      try {
        final access = PlatformSavedCopyAccess(
          platform: SavedPlatform.android,
          channel: channel,
        );
        await access.request(
          SavedAction.share,
          'content://provider/document/123',
          'pdf',
          Uint8List.fromList([1]),
        );
        expect(calls.last.method, 'share');
        expect(calls.last.arguments, {
          'location': 'content://provider/document/123',
          'mime': 'application/pdf',
        });
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      }
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'saved actions use available capabilities and reset at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(390, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final adapter = ActionAdapter({SavedAction.open, SavedAction.reveal});
        var another = false;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [savedCopyAccessProvider.overrideWithValue(adapter)],
            child: MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SavedCopyActions(
                    location: '/tmp/copy.pdf',
                    format: 'pdf',
                    bytes: Uint8List.fromList([1]),
                    onAnother: () => another = true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Share copy'), findsNothing);
        await tester.tap(find.text('Open copy'));
        await tester.pumpAndSettle();
        expect(adapter.calls, [SavedAction.open]);
        expect(find.textContaining('Opening requested.'), findsOneWidget);
        await tester.tap(find.text('Show in folder'));
        await tester.pumpAndSettle();
        expect(adapter.calls.last, SavedAction.reveal);
        await tester.tap(find.text('Process another'));
        expect(another, isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'unavailable actions are hidden while process-another stays reachable',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            savedCopyAccessProvider.overrideWithValue(ActionAdapter({})),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SavedCopyActions(
                location: '/tmp/copy.pdf',
                format: 'pdf',
                bytes: Uint8List.fromList([1]),
                onAnother: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open copy'), findsNothing);
      expect(find.text('Share copy'), findsNothing);
      expect(find.text('Show in folder'), findsNothing);
      expect(find.text('Process another'), findsOneWidget);
    },
  );
}
