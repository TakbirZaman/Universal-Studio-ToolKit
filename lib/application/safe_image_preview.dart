import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../src/rust/api.dart' as core;
import '../src/rust/scanner.dart';
import 'transparency_preview.dart';

/// Only canonical, bounded engine output reaches the Flutter image decoder.
/// One request runs at a time; rapid edits coalesce into the latest request.
class SafeImagePreview extends StatefulWidget {
  final Uint8List bytes;
  final ScanOptions? scanOptions;
  final bool transparency;
  final double height;
  final String semanticLabel;
  const SafeImagePreview({
    super.key,
    required this.bytes,
    this.scanOptions,
    this.transparency = false,
    this.height = 360,
    required this.semanticLabel,
  });
  @override
  State<SafeImagePreview> createState() => _SafeImagePreviewState();
}

class _SafeImagePreviewState extends State<SafeImagePreview> {
  Uint8List? display;
  String? failure, validation;
  bool working = false, pending = false;
  int revision = 0;
  @override
  void initState() {
    super.initState();
    request();
  }

  bool sameOptions(ScanOptions? a, ScanOptions? b) =>
      a?.mode == b?.mode &&
      a?.rotateQuarters == b?.rotateQuarters &&
      a?.brightness == b?.brightness &&
      a?.contrast == b?.contrast &&
      a?.threshold == b?.threshold;
  @override
  void didUpdateWidget(covariant SafeImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes) ||
        !sameOptions(oldWidget.scanOptions, widget.scanOptions)) {
      request();
    }
  }

  void request() {
    revision++;
    pending = true;
    display = null;
    failure = null;
    validation = null;
    if (!working) {
      drain();
    }
  }

  Future<void> drain() async {
    working = true;
    while (mounted && pending) {
      pending = false;
      final token = revision,
          bytes = widget.bytes,
          options = widget.scanOptions;
      try {
        final result = options == null
            ? await core.previewSourceImage(data: bytes, maxPixels: 1200)
            : await core.previewScanPage(
                data: bytes,
                options: options,
                maxPixels: 1200,
              );
        if (mounted && token == revision) {
          setState(() {
            display = result.bytes;
            validation = result.validation;
          });
        }
      } catch (_) {
        if (mounted && token == revision) {
          setState(
            () => failure = 'Could not preview this image. Choose a supported JPEG or PNG within the processing limits.',
          );
        }
      }
    }
    working = false;
  }

  @override
  Widget build(BuildContext context) {
    final bytes = display;
    if (failure != null) {
      return Semantics(liveRegion: true, child: Text(failure!));
    }
    if (bytes == null) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Text('Preparing image preview…')),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.transparency)
          TransparencyPreview(bytes: bytes)
        else
          Image.memory(
            bytes,
            height: widget.height,
            fit: BoxFit.contain,
            semanticLabel: widget.semanticLabel,
            errorBuilder: (_, _, _) => const Text('Image preview unavailable.'),
          ),
        if (validation?.isNotEmpty == true) Text(validation!),
      ],
    );
  }
}
