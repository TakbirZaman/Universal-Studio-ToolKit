import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../src/rust/api.dart' as core;
import '../src/rust/scanner.dart';

final studioServiceProvider = Provider((ref) => StudioService());

class StudioService {
  Future<core.StudioOutput> photo(
    Uint8List data, {
    required int width,
    required int height,
    required bool png,
    required bool cover,
    required int? limit,
    required int quality,
    required bool flatten,
    required int rotation,
    int? threshold,
  }) => core.resizePhoto(
    data: data,
    width: width,
    height: height,
    png: png,
    cover: cover,
    limitKib: limit,
    minimumQuality: quality,
    flatten: flatten,
    rotation: rotation,
    signatureThreshold: threshold,
  );
  Future<core.StudioOutput> physicalPhoto(
    Uint8List data, {
    required double widthMm,
    required double heightMm,
    required int dpi,
    required bool png,
    required bool cover,
    required int? limit,
    required int quality,
    required bool flatten,
    required int rotation,
    int? threshold,
  }) => core.resizePhysicalPhoto(
    data: data,
    widthMm: widthMm,
    heightMm: heightMm,
    dpi: dpi,
    png: png,
    cover: cover,
    limitKib: limit,
    minimumQuality: quality,
    flatten: flatten,
    rotation: rotation,
    signatureThreshold: threshold,
  );

  Future<core.StudioOutput> merge(
    List<Uint8List> inputs,
    List<int>? pages,
    int rotation, {
    bool optimize = false,
  }) async {
    if (optimize && inputs.length == 1 && pages == null && rotation == 0) {
      return core.optimizePdf(data: inputs.first);
    }
    final output = await core.combinePdfs(
      inputs: inputs,
      pages: pages == null ? null : Uint32List.fromList(pages),
      rotation: rotation,
    );
    return optimize ? core.optimizePdf(data: output.bytes) : output;
  }

  Future<core.StudioOutput> scan(List<ScanPage> pages) =>
      core.prepareScanPdf(pages: pages);
  Future<core.StudioOutput> pack(List<Uint8List> inputs, int limit) =>
      core.createApplicationPack(
        photo: inputs[0],
        signature: inputs[1],
        certificate: inputs[2],
        limitKib: limit,
      );
  Future<core.StudioOutput> printSheet(
    Uint8List data,
    double width,
    double height,
    int copies,
  ) => core.createPrintSheet(
    data: data,
    widthMm: width,
    heightMm: height,
    copies: copies,
  );
  Future<void> save(
    String directory,
    String filename,
    core.StudioOutput output,
  ) =>
      core.saveOutput(directory: directory, filename: filename, output: output);
}

ScanOptions scanSettings({
  required String mode,
  required int rotation,
  required int brightness,
  required double contrast,
}) => ScanOptions(
  mode: switch (mode) {
    'original' => ScanMode.original,
    'colour' => ScanMode.colour,
    'grayscale' => ScanMode.grayscale,
    'black_white' => ScanMode.blackWhite,
    _ => throw const FormatException('Choose a supported scan mode.'),
  },
  rotateQuarters: rotation,
  brightness: brightness,
  contrast: contrast,
  threshold: 128,
);
