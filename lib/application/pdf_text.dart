import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../src/rust/api.dart' as core;
import 'export_service.dart';
import 'pdf_preview.dart';

String _decode(Uint8List bytes) => utf8.decode(bytes);
Uint8List _encode(String text) {
  if (text.length > 4 * 1024 * 1024) {
    throw const FormatException('Text must be at most 4 MiB in UTF-8.');
  }
  final bytes = Uint8List.fromList(utf8.encode(text));
  if (bytes.length > 4 * 1024 * 1024) {
    throw const FormatException('Text must be at most 4 MiB in UTF-8.');
  }
  return bytes;
}

class PdfTextScreen extends StatefulWidget {
  final Uint8List source;
  const PdfTextScreen({super.key, required this.source});
  @override
  State<PdfTextScreen> createState() => _PdfTextState();
}

class _PdfTextState extends State<PdfTextScreen> {
  final text = TextEditingController();
  final filename = TextEditingController(text: 'document-text.txt');
  final form = GlobalKey<FormState>();
  bool reading = true, saving = false;
  String? error, findings, saved;
  @override
  void initState() {
    super.initState();
    read();
  }

  @override
  void dispose() {
    text.dispose();
    filename.dispose();
    super.dispose();
  }

  Future<void> read() async {
    setState(() {
      reading = true;
      error = null;
    });
    try {
      final output = await core.extractPdfText(data: widget.source);
      final decoded = await compute(_decode, output.bytes);
      if (mounted) {
        setState(() {
          text.text = decoded;
          findings = output.validation;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => reading = false);
    }
  }

  Future<void> save() async {
    if (reading || saving || !form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
      saved = null;
    });
    try {
      final encoded = await compute(_encode, text.text);
      final output = await core.preparePlainText(data: encoded);
      final location = await ExportService.saveCopy(output, filename.text);
      if (mounted && location != null) {
        setState(
          () => saved =
              'Saved and verified ${filename.text}\n$location\n${output.bytes.length} bytes · UTF-8 text\nYour original PDF is unchanged.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Scaffold(
      appBar: AppBar(title: const Text('Read PDF text')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Read the existing text layer, review or edit the result, then save a UTF-8 text copy. Page layout and reading order may differ. Scans without a text layer need offline text recognition where available.',
              ),
              const SizedBox(height: 20),
              if (reading)
                Semantics(
                  liveRegion: true,
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Reading text on this device…'),
                    ],
                  ),
                ),
              if (error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (!reading && findings == null)
                TextButton.icon(
                  onPressed: read,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try reading again'),
                ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final preview = Semantics(
                    label: 'Original PDF page preview',
                    child: PdfPreview(data: widget.source),
                  );
                  final editor = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: text,
                        enabled: !reading && !saving && findings != null,
                        minLines: 10,
                        maxLines: 20,
                        maxLength: 4 * 1024 * 1024,
                        decoration: const InputDecoration(
                          labelText: 'Editable document text',
                          helperText: 'Maximum 4 MiB of UTF-8 text.',
                          helperMaxLines: 3,
                          errorMaxLines: 3,
                          counterText: '',
                        ),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Enter some text before saving.'
                            : null,
                        onChanged: (_) {
                          if (saved != null) setState(() => saved = null);
                        },
                      ),
                      const SizedBox(height: 12),
                      if (findings != null)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Extraction details'),
                          children: [Text(findings!)],
                        ),
                    ],
                  );
                  return constraints.maxWidth >= 900
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: preview),
                            const SizedBox(width: 24),
                            Expanded(child: editor),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            preview,
                            const SizedBox(height: 20),
                            editor,
                          ],
                        );
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: filename,
                enabled: !saving,
                decoration: const InputDecoration(
                  labelText: 'Text filename',
                  errorMaxLines: 3,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a filename ending in .txt.'
                    : null,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: reading || saving || findings == null ? null : save,
                icon: const Icon(Icons.save_alt),
                label: Text(
                  saving
                      ? 'Saving text copy…'
                      : 'Choose location and save text copy',
                ),
              ),
              if (saved != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: SelectableText(saved!),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
