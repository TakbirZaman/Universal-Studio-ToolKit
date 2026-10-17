import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../src/rust/api.dart' as core;
import '../src/rust/jobs.dart';
import '../src/rust/ocr.dart';
import 'export_service.dart';

String _decodeText(Uint8List bytes) => utf8.decode(bytes);
Uint8List _encodeText(String edited) {
  if (edited.length > 4 * 1024 * 1024) {
    throw const FormatException('Text must be at most 4 MiB in UTF-8.');
  }
  final encoded = Uint8List.fromList(utf8.encode(edited));
  if (encoded.length > 4 * 1024 * 1024) {
    throw const FormatException('Text must be at most 4 MiB in UTF-8.');
  }
  return encoded;
}

/// Plain text only. Searchable PDF export needs separate geometry validation.
class RecognizedTextScreen extends StatefulWidget {
  final Uint8List page;
  const RecognizedTextScreen({super.key, required this.page});
  @override
  State<RecognizedTextScreen> createState() => _RecognizedTextState();
}

class _RecognizedTextState extends State<RecognizedTextScreen> {
  final text = TextEditingController();
  final filename = TextEditingController(text: 'recognized-text.txt');
  Language language = Language.english;
  core.OcrTask? task;
  JobState? state;
  bool busy = false;
  String? error, saved;
  Timer? timer;

  @override
  void dispose() {
    timer?.cancel();
    text.dispose();
    filename.dispose();
    super.dispose();
  }

  Future<void> recognize() async {
    if (busy) return;
    final handle = core.createOcrTask();
    setState(() {
      task = handle;
      state = JobState.queued;
      busy = true;
      error = null;
      saved = null;
    });
    timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      final progress = core.ocrTaskState(task: handle);
      // The engine can finish before UTF-8 transfer/editor preparation. Only
      // report a terminal state after the entire UI operation has settled.
      if (mounted &&
          (progress == JobState.queued ||
              progress == JobState.running ||
              progress == JobState.cancelling)) {
        setState(() => state = progress);
      }
    });
    var transferred = false;
    try {
      final result = await core.recognizeText(
        task: handle,
        data: widget.page,
        language: language,
      );
      final bytes = result.bytes;
      final recognized = await compute(_decodeText, bytes);
      transferred = true;
      if (mounted) setState(() => text.text = recognized);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      timer?.cancel();
      final finalState = core.ocrTaskState(task: handle);
      handle.dispose();
      if (mounted) {
        setState(() {
          task = null;
          state = finalState == JobState.succeeded && !transferred
              ? JobState.failed
              : finalState;
          if (finalState == JobState.cancelled) error = null;
          busy = false;
        });
      }
    }
  }

  Future<void> save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      saved = null;
    });
    try {
      final edited = text.text;
      // A cheap UTF-16 bound avoids duplicating arbitrarily large edits.
      if (edited.length > 4 * 1024 * 1024) {
        throw const FormatException('Text must be at most 4 MiB in UTF-8.');
      }
      final bytes = await compute(_encodeText, edited);
      final output = await core.prepareEditedText(data: bytes);
      final location = await ExportService.saveCopy(output, filename.text);
      if (mounted && location != null) {
        setState(
          () => saved =
              'Saved ${filename.text} at $location. Verified UTF-8 · ${output.bytes.length} bytes.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String get status => switch (state) {
    JobState.queued => 'Waiting for the processing slot…',
    JobState.running => 'Reading printed text on this device…',
    JobState.cancelling => 'Stopping recognition and cleaning temporary files…',
    JobState.cancelled => 'Recognition cancelled. Previous text is unchanged.',
    JobState.succeeded => 'Text is ready to review and edit.',
    JobState.failed =>
      'Couldn’t read this page. Try another language or a clearer image.',
    _ => 'Choose the page language, then read its printed text.',
  };

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Read printed text')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Offline English and Bangla recognition. Check names, numbers and spelling before saving. This exports editable plain text, without the page layout.',
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final image = Semantics(
                  label: 'Selected scan page with current adjustments',
                  image: true,
                  child: Container(
                    height: 300,
                    padding: const EdgeInsets.all(12),
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: Image.memory(widget.page, fit: BoxFit.contain),
                  ),
                );
                final controls = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<Language>(
                      initialValue: language,
                      decoration: const InputDecoration(
                        labelText: 'Page language',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: Language.english,
                          child: Text('English'),
                        ),
                        DropdownMenuItem(
                          value: Language.bangla,
                          child: Text('Bangla'),
                        ),
                        DropdownMenuItem(
                          value: Language.mixed,
                          child: Text('English and Bangla'),
                        ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) => setState(() => language = value!),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: busy ? null : recognize,
                      icon: const Icon(Icons.text_snippet_outlined),
                      label: const Text('Read this page'),
                    ),
                    if (task != null)
                      OutlinedButton(
                        onPressed: state == JobState.cancelling
                            ? null
                            : () {
                                core.cancelOcrTask(task: task!);
                                setState(
                                  () => state = core.ocrTaskState(task: task!),
                                );
                              },
                        child: const Text('Cancel recognition'),
                      ),
                    if (task != null)
                      const Text(
                        'Cancellation waits for preparation checkpoints. A running recognition engine is stopped before this job finishes.',
                      ),
                    const SizedBox(height: 12),
                    Semantics(liveRegion: true, child: Text(status)),
                  ],
                );
                return constraints.maxWidth >= 760
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: image),
                          const SizedBox(width: 24),
                          Expanded(child: controls),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [image, const SizedBox(height: 20), controls],
                      );
              },
            ),
            const SizedBox(height: 24),
            TextField(
              controller: text,
              enabled: !busy,
              minLines: 8,
              maxLines: 20,
              onChanged: (_) => setState(() => saved = null),
              decoration: const InputDecoration(
                labelText: 'Review and edit recognized text',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: filename,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: 'Filename (ends in .txt)',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy || text.text.trim().isEmpty ? null : save,
              icon: const Icon(Icons.save_alt),
              label: const Text('Choose location and save a copy'),
            ),
            const Text(
              'Your original page is unchanged. Existing files are never overwritten.',
            ),
            if (error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (saved != null)
              Semantics(liveRegion: true, child: Text('✓ $saved')),
          ],
        ),
      ),
    ),
  );
}
