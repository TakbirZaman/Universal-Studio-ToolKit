import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'safe_image_preview.dart';

/// A display-only comparison. Both sides use the bounded native preview path.
class ImageInspector extends StatefulWidget {
  final Uint8List original;
  final Uint8List prepared;
  final bool transparency;
  const ImageInspector({
    super.key,
    required this.original,
    required this.prepared,
    this.transparency = false,
  });

  @override
  State<ImageInspector> createState() => _ImageInspectorState();
}

class _ImageInspectorState extends State<ImageInspector> {
  bool original = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Compare images')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Original'),
              selected: original,
              onSelected: (_) => setState(() => original = true),
            ),
            ChoiceChip(
              label: const Text('Prepared'),
              selected: !original,
              onSelected: (_) => setState(() => original = false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SafeImagePreview(
          key: ValueKey(original),
          bytes: original ? widget.original : widget.prepared,
          transparency: !original && widget.transparency,
          semanticLabel: original ? 'Original image' : 'Prepared image',
        ),
        const SizedBox(height: 12),
        const Text(
          'Switch images to inspect the changes. Each side starts fitted to the preview. '
          'Previews are limited to 1200 pixels; zoom enlarges the preview. '
          'Comparison and background controls do not change the saved image.',
        ),
      ],
    ),
  );
}
