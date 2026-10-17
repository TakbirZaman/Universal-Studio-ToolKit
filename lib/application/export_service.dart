import 'dart:io';

import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';

import '../src/rust/api.dart' as core;

class ExportService {
  static const _documents = MethodChannel('dev.universalstudio/documents');
  static Future<String?> saveCopy(
    core.StudioOutput output,
    String filename,
  ) async {
    await core.validatePreparedOutput(output: output, filename: filename);
    if (Platform.isAndroid) {
      final mime = switch (output.format) {
        'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'pdf' => 'application/pdf',
        'zip' => 'application/zip',
        'json' => 'application/json',
        'txt' => 'text/plain',
        _ => throw const FormatException('Unsupported output format'),
      };
      return _documents.invokeMethod<String>('saveCopy', {
        'bytes': output.bytes,
        'name': filename,
        'mime': mime,
      });
    }
    final directory = await getDirectoryPath(
      confirmButtonText: 'Save copy here',
    );
    if (directory == null) return null;
    await core.saveOutput(
      directory: directory,
      filename: filename,
      output: output,
    );
    return '$directory${Platform.pathSeparator}$filename';
  }
}
