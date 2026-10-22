import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../src/rust/api.dart' as core;
import 'export_service.dart';
import 'pdf_preview.dart';
import 'pdf_split_plan.dart';
import 'saved_copy_actions.dart';

class _Part {
  final TextEditingController pages;
  final TextEditingController filename;
  core.StudioOutput? output;
  SavedCopyReceipt? receipt;
  String? error;
  _Part(String range, String name)
    : pages = TextEditingController(text: range),
      filename = TextEditingController(text: name);
  void dispose() { pages.dispose(); filename.dispose(); }
}

class PdfSplitScreen extends StatefulWidget {
  final Uint8List source;
  const PdfSplitScreen({super.key, required this.source});
  @override
  State<PdfSplitScreen> createState() => _PdfSplitState();
}

class _PdfSplitState extends State<PdfSplitScreen> {
  final parts = <_Part>[];
  late final Uint8List source;
  int? count;
  bool busy = true;
  String? error;
  int serial = 0;
  @override
  void initState() { super.initState(); source = Uint8List.fromList(widget.source); read(); }
  Future<void> read() async {
    setState(() { busy = true; error = null; });
    try {
      final n = await core.countPdf(data: source);
      if (mounted) setState(() { count = n; if (parts.isEmpty) addPart(); });
    } catch (e) { if (mounted) setState(() => error = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }
  void addPart() { serial++; parts.add(_Part('1', 'part-$serial.pdf')); }
  void invalidate(_Part part) => setState(() { part.output = null; part.receipt = null; part.error = null; });
  int get preparedBytes => parts.fold(0, (total, p) => total + (p.output?.bytes.length ?? 0));
  Future<void> prepare(List<_Part> selected) async {
    setState(() { busy = true; error = null; });
    try {
      for (final part in selected) {
        if (!mounted) break;
        if (part.output != null) continue;
        try {
          final pages = parseSplitPages(part.pages.text, count!);
          final result = await core.combinePdfs(inputs: [source], pages: Uint32List.fromList(pages), rotation: 0);
          if (!mounted) break;
          if (preparedBytes + result.bytes.length > 64 * 1024 * 1024) {
            throw const FormatException('Prepared parts exceed 64 MiB. Remove a prepared part before retrying.');
          }
          setState(() { part.output = result; part.error = null; });
        } catch (e) { if (mounted) setState(() => part.error = e.toString()); }
      }
    } finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> save(_Part part) async {
    setState(() { busy = true; part.error = null; });
    try {
      final result = part.output!;
      final location = await ExportService.saveCopy(result, part.filename.text.trim());
      if (mounted && location != null) setState(() => part.receipt = SavedCopyReceipt(location, result.format, result.bytes));
    } catch (e) { if (mounted) setState(() => part.error = e.toString()); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  void dispose() { for (final part in parts) { part.dispose(); } super.dispose(); }
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Split PDF')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Create separate PDF copies from ordered page groups. Text and vectors are retained for supported PDFs. Forms, annotations, bookmarks, attachments and signatures are rejected. Your original stays unchanged.'),
          if (count != null) Text('Source: $count pages · ${parts.length}/32 parts'),
          if (busy) const Semantics(liveRegion: true, child: LinearProgressIndicator()),
          if (error != null) Semantics(liveRegion: true, child: Text(error!)),
          if (!busy && count == null) TextButton(onPressed: read, child: const Text('Try opening PDF again')),
          if (count != null) ...[
            ExpansionTile(title: const Text('Preview original pages'), children: [PdfPreview(data: source, pageCount: count)]),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: [
              OutlinedButton.icon(onPressed: busy || parts.length >= 32 ? null : () => setState(addPart), icon: const Icon(Icons.add), label: const Text('Add part')),
              FilledButton(onPressed: busy || parts.every((p) => p.output != null) ? null : () => prepare(List.of(parts)), child: const Text('Prepare unfinished parts')),
            ]),
            const Text('Use ranges such as 1-3,5. Separate parts may overlap. Up to 32 parts and 64 MiB of prepared copies are kept only in this session.'),
            for (final part in parts) Padding(
              key: ObjectKey(part), padding: const EdgeInsets.only(top: 16),
              child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [Expanded(child: Text('Part ${parts.indexOf(part) + 1}', style: Theme.of(context).textTheme.titleMedium)), IconButton(tooltip: 'Remove part ${parts.indexOf(part) + 1}', onPressed: busy || parts.length == 1 ? null : () => setState(() { parts.remove(part); part.dispose(); }), icon: const Icon(Icons.delete_outline))]),
                TextField(controller: part.pages, enabled: !busy, maxLength: 2048, decoration: const InputDecoration(labelText: 'Pages in this part', counterText: ''), onChanged: (_) => invalidate(part)),
                const SizedBox(height: 12),
                TextField(controller: part.filename, enabled: !busy, maxLength: 240, decoration: const InputDecoration(labelText: 'PDF filename'), onChanged: (_) => setState(() => part.receipt = null)),
                if (part.error != null) Semantics(liveRegion: true, child: Text(part.error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                if (part.output != null) ...[
                  Text('Ready: ${part.output!.pages} pages · ${part.output!.bytes.length} bytes'),
                  ExpansionTile(title: const Text('Preview this part'), children: [PdfPreview(data: part.output!.bytes, pageCount: part.output!.pages)]),
                ],
                Wrap(spacing: 12, runSpacing: 8, children: [
                  OutlinedButton(onPressed: busy || part.output != null ? null : () => prepare([part]), child: Text(part.error == null ? 'Prepare part' : 'Retry part')),
                  FilledButton.icon(onPressed: busy || part.output == null ? null : () => save(part), icon: const Icon(Icons.save_alt), label: const Text('Save PDF copy')),
                ]),
                if (part.receipt != null) ...[
                  Semantics(liveRegion: true, child: SelectableText('Saved and verified ${part.filename.text.trim()}\n${part.receipt!.location}')),
                  SavedCopyActions.receipt(part.receipt!),
                ],
              ]))),
            ),
          ],
        ]),
      ),
    ),
  );
}
