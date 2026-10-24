import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../src/rust/api.dart' as core;

final packProcessorProvider = Provider((ref) => PackProcessor());

class PackProcessor {
  Future<core.StudioOutput> prepare(
    Uint8List bytes,
    String preset,
    int index,
  ) => core.prepareCustomPackSlot(
    data: bytes,
    presetJson: preset,
    slotIndex: index,
  );
  Future<core.StudioOutput> build(
    List<core.StudioOutput?> outputs,
    String preset,
  ) => core.buildCustomApplicationPack(outputs: outputs, presetJson: preset);
}
