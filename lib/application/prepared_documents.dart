import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Explicit, session-only copies. Never persists document bytes or source paths.
final preparedDocumentsProvider =
    NotifierProvider<PreparedDocuments, List<PreparedDocument>>(
      PreparedDocuments.new,
    );

class PreparedDocument {
  final int id;
  final String name, format;
  final Uint8List _bytes;
  Uint8List get bytes => Uint8List.fromList(_bytes);
  int get byteCount => _bytes.length;
  PreparedDocument(this.id, this.name, this.format, Uint8List bytes)
    : _bytes = Uint8List.fromList(bytes);
}

class PreparedDocuments extends Notifier<List<PreparedDocument>> {
  static const maximumBytes = 64 * 1024 * 1024;
  static const maximumItems = 16;
  int _nextId = 0;
  @override
  List<PreparedDocument> build() => const [];

  void add(String name, String format, Uint8List bytes) {
    if (!['jpeg', 'png', 'pdf'].contains(format) || bytes.isEmpty) {
      throw const FormatException('Choose a prepared image or PDF.');
    }
    if (name.trim().isEmpty ||
        name.length > 255 ||
        name.codeUnits.any((c) => c < 32 || c == 127 || c == 47 || c == 92)) {
      throw const FormatException('Use a filename without folders.');
    }
    if (state.length >= maximumItems ||
        state.fold<int>(0, (n, item) => n + item.byteCount) + bytes.length >
            maximumBytes) {
      throw const FormatException(
        'Session documents support 16 items totalling 64 MiB. Remove an item first.',
      );
    }
    state = List.unmodifiable([
      ...state,
      PreparedDocument(_nextId++, name, format, bytes),
    ]);
  }

  void remove(int id) =>
      state = List.unmodifiable(state.where((item) => item.id != id));
  void clear() => state = const [];
}
