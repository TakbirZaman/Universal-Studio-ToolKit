import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'export_service.dart';
import 'saved_copy_actions.dart';
import '../src/rust/api.dart' as core;

class PdfPreview extends StatefulWidget {
  final Uint8List data;
  final int? pageCount;
  const PdfPreview({super.key, required this.data, this.pageCount});
  @override
  State<PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<PdfPreview> {
  int index = 0, count = 0, generation = 0;
  bool loading = true;
  core.StudioOutput? preview;
  String? error, saved;
  SavedCopyReceipt? savedCopy;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant PdfPreview old) {
    super.didUpdateWidget(old);
    if (!identical(old.data, widget.data)) {
      index = 0;
      count = 0;
      load();
    }
  }

  Future<void> load() async {
    final current = ++generation;
    setState(() {
      loading = true;
      error = null;
      saved = null;
      savedCopy = null;
      preview = null;
    });
    try {
      final n = widget.pageCount ?? await core.countPdf(data: widget.data);
      final p = await core.renderPdfPage(
        data: widget.data,
        pageIndex: index,
        maxPixels: 1200,
      );
      if (mounted && current == generation) {
        setState(() {
          count = n;
          preview = p;
        });
      }
    } catch (e) {
      if (mounted && current == generation) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted && current == generation) setState(() => loading = false);
    }
  }

  Future<void> savePage() async {
    final value = preview;
    if (value == null) return;
    try {
      final name = 'page-${index + 1}.png';
      final destination = await ExportService.saveCopy(value, name);
      if (destination != null && mounted) {
        setState(() {
          saved = 'Saved $name at $destination. The original PDF is unchanged.';
          savedCopy = SavedCopyReceipt(destination, value.format, value.bytes);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (loading)
        const SizedBox(
          height: 280,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Rendering this page locally…'),
              ],
            ),
          ),
        ),
      if (preview != null)
        Image.memory(
          preview!.bytes,
          fit: BoxFit.contain,
          height: 460,
          semanticLabel: 'PDF page ${index + 1} of $count',
        ),
      if (error != null)
        Semantics(
          liveRegion: true,
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: loading || index == 0
                ? null
                : () {
                    index--;
                    load();
                  },
            icon: const Icon(Icons.chevron_left),
          ),
          Text(count == 0 ? 'PDF preview' : 'Page ${index + 1} of $count'),
          IconButton(
            tooltip: 'Next page',
            onPressed: loading || index + 1 >= count
                ? null
                : () {
                    index++;
                    load();
                  },
            icon: const Icon(Icons.chevron_right),
          ),
          OutlinedButton.icon(
            onPressed: loading || preview == null ? null : savePage,
            icon: const Icon(Icons.image_outlined),
            label: const Text('Save page as PNG'),
          ),
        ],
      ),
      if (saved != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(liveRegion: true, child: SelectableText(saved!)),
        ),
      if (savedCopy != null) SavedCopyActions.receipt(savedCopy!),
      const SizedBox(height: 8),
      const Text(
        'PNG export is a raster image. It does not retain selectable text, forms or vector editing.',
        textAlign: TextAlign.center,
      ),
    ],
  );
}
