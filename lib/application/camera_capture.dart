import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Native capture returns bytes; content URIs never become document paths.
class CameraCapture {
  static const channel = MethodChannel('dev.universalstudio/camera');
  Future<bool> available() async {
    try { return await channel.invokeMethod<bool>('available') ?? false; }
    on PlatformException { return false; }
    on MissingPluginException { return false; }
  }
  Future<Uint8List?> capture() async {
    final bytes = await channel.invokeMethod<Uint8List>('capture');
    if (bytes != null && (bytes.isEmpty || bytes.length > 64 * 1024 * 1024)) {
      throw const FormatException('The captured image exceeds the supported size.');
    }
    return bytes;
  }
}
