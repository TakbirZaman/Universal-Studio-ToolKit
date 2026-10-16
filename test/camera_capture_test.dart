import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_studio_toolkit/application/camera_capture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(CameraCapture.channel, null));
  test('camera adapter preserves cancellation and returned source bytes', () async {
    var cancelled = true;
    messenger.setMockMethodCallHandler(CameraCapture.channel, (call) async {
      if (call.method == 'available') { return true; }
      return cancelled ? null : Uint8List.fromList([255, 216, 255]);
    });
    final camera = CameraCapture();
    expect(await camera.available(), isTrue);
    expect(await camera.capture(), isNull);
    cancelled = false;
    expect(await camera.capture(), [255, 216, 255]);
  });
  test('camera errors remain actionable and empty output is rejected', () async {
    messenger.setMockMethodCallHandler(CameraCapture.channel, (call) async {
      throw PlatformException(code: 'camera_unavailable', message: 'Import an image instead.');
    });
    final camera = CameraCapture();
    expect(await camera.available(), isFalse);
    await expectLater(camera.capture(), throwsA(isA<PlatformException>()));
    messenger.setMockMethodCallHandler(CameraCapture.channel, (_) async => Uint8List(0));
    await expectLater(camera.capture(), throwsA(isA<FormatException>()));
  });
}
