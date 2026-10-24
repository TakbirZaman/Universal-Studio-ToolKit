import 'pdf_preview.dart';
import 'safe_image_preview.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../src/rust/api.dart' as core;
import 'export_service.dart';
import 'prepared_documents.dart';
import 'saved_copy_actions.dart';
import 'preferences.dart';
import 'pack_preset_catalogue.dart';
import 'pack_processor.dart';

class CustomPackScreen extends ConsumerStatefulWidget {
  const CustomPackScreen({super.key});
  @override
  ConsumerState<CustomPackScreen> createState() => _CustomPackState();
}

class _Slot {
  final label = TextEditingController(text: 'Document');
  final filename = TextEditingController(text: 'document.jpg');
  final width = TextEditingController(text: '300');
  final height = TextEditingController(text: '300');
  final limit = TextEditingController(text: '100');
  final minimumPages = TextEditingController(text: '1');
  final maximumPages = TextEditingController(text: '200');
  bool required = true, showPreview = false;
  String format = 'jpeg';
  String? sourceName;
  Uint8List? bytes;
  core.StudioOutput? prepared;
  String? cacheKey, issue;
  Uint8List? cacheSource;
  String get fingerprint => jsonEncode([
    label.text,
    filename.text,
    width.text,
    height.text,
    limit.text,
    minimumPages.text,
    maximumPages.text,
    required,
    format,
  ]);
  void sync() {
    if (cacheKey != fingerprint || !identical(cacheSource, bytes)) {
      prepared = null;
      issue = null;
      cacheKey = null;
      cacheSource = null;
    }
  }

  Map<String, dynamic> toJson() => {
    'label': label.text.trim(),
    'required': required,
    'filename': filename.text.trim(),
    'formats': [format],
    'width': format == 'pdf' ? null : int.parse(width.text),
    'height': format == 'pdf' ? null : int.parse(height.text),
    'max_bytes': limit.text.isEmpty
        ? null
        : {'value': int.parse(limit.text), 'unit': 'ki_b', 'strict': true},
    'min_pages': format == 'pdf' ? int.parse(minimumPages.text) : null,
    'max_pages': format == 'pdf' ? int.parse(maximumPages.text) : null,
  };
  void dispose() {
    prepared = null;
    cacheSource = null;
    for (final field in [
      label,
      filename,
      width,
      height,
      limit,
      minimumPages,
      maximumPages,
    ]) {
      field.dispose();
    }
  }

  static _Slot fromJson(Map<String, dynamic> json) {
    final slot = _Slot();
    slot.label.text = json['label'] as String;
    slot.filename.text = json['filename'] as String;
    slot.required = json['required'] as bool;
    final formats = json['formats'] as List<dynamic>;
    if (formats.length != 1) {
      slot.dispose();
      throw const FormatException(
        'Choose presets with one output format per slot.',
      );
    }
    slot.format = formats.single as String;
    if ((slot.format == 'pdf' &&
            (json['width'] != null ||
                json['height'] != null ||
                json['min_pages'] == null ||
                json['max_pages'] == null)) ||
        (slot.format != 'pdf' &&
            (json['width'] == null ||
                json['height'] == null ||
                json['min_pages'] != null ||
                json['max_pages'] != null))) {
      slot.dispose();
      throw const FormatException(
        'This editor needs image pixel dimensions or a PDF page range. Imported constraints were not changed.',
      );
    }
    slot.width.text = '${json['width'] ?? 300}';
    slot.height.text = '${json['height'] ?? 300}';
    final limit = json['max_bytes'] as Map<String, dynamic>?;
    if (limit != null && (limit['unit'] != 'ki_b' || limit['strict'] != true)) {
      slot.dispose();
      throw const FormatException('This editor uses strict KiB limits.');
    }
    slot.limit.text = limit == null ? '' : '${limit['value']}';
    slot.minimumPages.text = '${json['min_pages'] ?? 1}';
    slot.maximumPages.text = '${json['max_pages'] ?? 200}';
    return slot;
  }
}

class _CustomPackState extends ConsumerState<CustomPackScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(text: 'My application');
  final revision = TextEditingController(
    text: DateTime.now().toIso8601String().substring(0, 10),
  );
  final source = TextEditingController();
  final zipName = TextEditingController(text: 'application-pack.zip');
  List<_Slot> slots = [_Slot()];
  core.StudioOutput? output;
  SavedCopyReceipt? presetReceipt;
  String? error, saved, catalogueNotice;
  bool busy = false;
  bool preparing = false, stopRequested = false;
  String? preparationNotice;
  @override
  void dispose() {
    for (final field in [name, revision, source, zipName]) {
      field.dispose();
    }
    for (final slot in slots) {
      slot.dispose();
    }
    super.dispose();
  }

  void changed() {
    setState(() {
      for (final slot in slots) {
        slot.sync();
      }
      output = null;
      saved = null;
      error = null;
      presetReceipt = null;
      catalogueNotice = null;
      preparationNotice = null;
    });
  }

  String preset() => jsonEncode({
    'schema_version': 1,
    'name': name.text.trim(),
    'revision_date': revision.text,
    'source': source.text.isEmpty ? null : source.text,
    'verified': false,
    'slots': slots.map((slot) => slot.toJson()).toList(),
  });
  Future<void> task(Future<void> Function() run) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await run();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pick(_Slot slot) async {
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: slot.format == 'pdf' ? 'PDF' : 'Image',
          extensions: slot.format == 'pdf' ? ['pdf'] : ['jpg', 'jpeg', 'png'],
        ),
      ],
    );
    if (file == null) return;
    final total = slots
        .where((s) => !identical(s, slot))
        .fold<int>(0, (n, s) => n + (s.bytes?.length ?? 0));
    final length = await file.length();
    if (length == 0) {
      throw const FormatException('Choose a non-empty image or PDF.');
    }
    if (length + total > PreparedDocuments.maximumBytes) {
      throw const FormatException('Pack sources must total at most 64 MiB.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('Choose a non-empty image or PDF.');
    }
    if (bytes.length + total > PreparedDocuments.maximumBytes) {
      throw const FormatException('Pack sources must total at most 64 MiB.');
    }
    if (!mounted) return;
    slot.bytes = bytes;
    slot.sourceName = file.name;
    changed();
  }

  Future<void> importPreset() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Pack preset', extensions: ['json']),
      ],
    );
    if (file == null) return;
    if (await file.length() > 65536) {
      throw const FormatException('Preset exceeds 64 KiB.');
    }
    final text = utf8.decode(await file.readAsBytes());
    await applyPreset(text);
  }

  Future<void> applyPreset(String text) async {
    await core.validatePackPreset(presetJson: text);
    final json = jsonDecode(text) as Map<String, dynamic>;
    final incoming = <_Slot>[];
    try {
      for (final item in json['slots'] as List<dynamic>) {
        incoming.add(_Slot.fromJson(item as Map<String, dynamic>));
      }
    } catch (_) {
      for (final slot in incoming) {
        slot.dispose();
      }
      rethrow;
    }
    if (!mounted) {
      for (final slot in incoming) {
        slot.dispose();
      }
      return;
    }
    setState(() {
      for (final slot in slots) {
        slot.dispose();
      }
      slots = incoming;
      presetReceipt = null;
      name.text = json['name'] as String;
      revision.text = json['revision_date'] as String;
      source.text = json['source'] as String? ?? '';
      output = null;
      saved = null;
      catalogueNotice = null;
    });
  }

  Future<void> savePresetLocally() async {
    if (!form.currentState!.validate()) return;
    final directory = ref.read(dataDirectoryProvider);
    if (directory == null) {
      throw const FormatException(
        'Local preset storage is unavailable in this session. You can still export preset JSON.',
      );
    }
    await core.savePackPreset(directory: directory, presetJson: preset());
    if (mounted) {
      setState(
        () => catalogueNotice =
            'Preset saved on this device. No source documents were stored.',
      );
    }
  }

  Future<void> openCatalogue() async {
    final directory = ref.read(dataDirectoryProvider);
    if (directory == null) {
      throw const FormatException(
        'Local preset storage is unavailable in this session. You can still import preset JSON.',
      );
    }
    final selected = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PackPresetCatalogue(directory: directory),
      ),
    );
    if (selected != null && mounted) await applyPreset(selected);
  }

  Future<void> prepare({_Slot? only}) async {
    if (busy || preparing || !form.currentState!.validate()) return;
    setState(() {
      preparing = true;
      stopRequested = false;
      output = null;
      saved = null;
      preparationNotice = null;
    });
    try {
      await task(() async {
        final settings = preset();
        await core.validatePackPreset(presetJson: settings);
        final processor = ref.read(packProcessorProvider);
        for (var index = 0; index < slots.length; index++) {
          if (!mounted || stopRequested) break;
          final slot = slots[index];
          slot.sync();
          if (slot.prepared != null ||
              (only != null && !identical(only, slot))) {
            continue;
          }
          slot.cacheKey = slot.fingerprint;
          slot.cacheSource = slot.bytes;
          if (slot.bytes == null) {
            setState(
              () => slot.issue = slot.required
                  ? '${slot.label.text}: choose a source for this required slot.'
                  : null,
            );
            continue;
          }
          try {
            final attemptKey = slot.fingerprint;
            final attemptSource = slot.bytes!;
            final result = await processor.prepare(
              attemptSource,
              settings,
              index,
            );
            if (!mounted) return;
            if (slot.fingerprint != attemptKey ||
                !identical(slot.bytes, attemptSource)) {
              slot.sync();
              continue;
            }
            final total = slots.fold<int>(
              0,
              (n, s) => n + (s.prepared?.bytes.length ?? 0),
            );
            if (total + result.bytes.length > PreparedDocuments.maximumBytes) {
              throw const FormatException(
                'Prepared documents exceed 64 MiB. Clear or remove a prepared document before retrying.',
              );
            }
            setState(() {
              slot.prepared = result;
              slot.issue = null;
            });
          } catch (e) {
            if (mounted) setState(() => slot.issue = e.toString());
          }
        }
        if (!mounted) return;
        if (stopRequested) {
          setState(
            () => preparationNotice = 'Stopped after the active operation. Ready documents are retained; prepare again to continue.',
          );
          return;
        }
        if (slots.any(
          (s) => (s.required || s.bytes != null) && s.prepared == null,
        )) {
          return;
        }
        if (preset() != settings) {
          setState(
            () => preparationNotice = 'Settings changed during preparation. Prepare again to validate the current settings.',
          );
          return;
        }
        final result = await processor.build(
          slots.map((s) => s.prepared).toList(),
          settings,
        );
        if (mounted) {
          setState(() {
            if (stopRequested) {
              preparationNotice = 'Stopped after the active operation. Ready documents are retained; prepare again to continue.';
            } else {
              output = result;
            }
          });
        }
      });
    } finally {
      if (mounted) setState(() => preparing = false);
    }
  }

  String? positive(String? value, {bool optional = false}) {
    if (optional && (value == null || value.isEmpty)) return null;
    final n = int.tryParse(value ?? '');
    return n == null || n < 1 ? 'Enter a positive whole number.' : null;
  }

  Widget field(
    TextEditingController controller,
    String label, {
    bool number = false,
    bool optional = false,
    bool invalidatesOutput = true,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: TextFormField(
      controller: controller,
      enabled: !busy,
      keyboardType: number ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) {
        if (invalidatesOutput) {
          changed();
        } else {
          setState(() => saved = null);
        }
      },
      validator: (v) => number
          ? positive(v, optional: optional)
          : (v == null || v.trim().isEmpty ? 'Enter a value.' : null),
    ),
  );
  Widget slotCard(_Slot slot, int index) => Card(
    key: ObjectKey(slot),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Slot ${index + 1}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          field(slot.label, 'Document label'),
          field(slot.filename, 'Output filename (include extension)'),
          DropdownButtonFormField<String>(
            initialValue: slot.format,
            isExpanded: true,
            itemHeight: null,
            decoration: const InputDecoration(labelText: 'Output format'),
            items: const [
              DropdownMenuItem(value: 'jpeg', child: Text('JPEG')),
              DropdownMenuItem(value: 'png', child: Text('PNG')),
              DropdownMenuItem(value: 'pdf', child: Text('PDF')),
            ],
            onChanged: busy
                ? null
                : (value) {
                    setState(() {
                      presetReceipt = null;
                      slot.format = value!;
                      slot.bytes = null;
                      slot.sourceName = null;
                      slot.filename.text =
                          'document${index + 1}.${value == 'jpeg' ? 'jpg' : value}';
                      output = null;
                      saved = null;
                    });
                    changed();
                  },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Required document'),
            value: slot.required,
            onChanged: busy
                ? null
                : (value) {
                    slot.required = value;
                    changed();
                  },
          ),
          if (slot.format != 'pdf') ...[
            field(slot.width, 'Output width (pixels)', number: true),
            field(slot.height, 'Output height (pixels)', number: true),
            const Text(
              'Images fit inside these dimensions with padding. JPEG needs an opaque source and uses white padding. Prepare transparency handling in Photo Studio first. PNG retains transparency.',
            ),
          ] else ...[
            field(slot.minimumPages, 'Minimum pages', number: true),
            field(slot.maximumPages, 'Maximum pages (up to 200)', number: true),
          ],
          field(
            slot.limit,
            'Strict limit (KiB, optional)',
            number: true,
            optional: true,
          ),
          const Text(
            '1 KiB = 1024 bytes. A strict limit requires fewer bytes than the limit.',
          ),
          Text(
            slot.sourceName == null
                ? 'No source selected'
                : '${slot.sourceName} · ${slot.bytes!.length} bytes',
          ),
          if (slot.issue != null)
            Semantics(
              liveRegion: true,
              child: Text(
                slot.issue!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (slot.prepared != null) ...[
            Text('Document ready · ${slot.prepared!.bytes.length} bytes'),
            ExpansionTile(
              title: const Text('Review prepared document'),
              children: [
                slot.prepared!.format == 'pdf'
                    ? PdfPreview(
                        data: slot.prepared!.bytes,
                        pageCount: slot.prepared!.pages,
                      )
                    : SafeImagePreview(
                        bytes: slot.prepared!.bytes,
                        height: 220,
                        semanticLabel: 'Prepared ${slot.label.text}',
                      ),
              ],
            ),
          ],
          OutlinedButton(
            onPressed: busy || slot.bytes == null || slot.prepared != null
                ? null
                : () => prepare(only: slot),
            child: Text(
              slot.issue == null ? 'Prepare document' : 'Retry document',
            ),
          ),
          if (slot.bytes != null)
            ExpansionTile(
              title: const Text('Review selected source'),
              onExpansionChanged: (value) =>
                  setState(() => slot.showPreview = value),
              children: [
                if (slot.showPreview)
                  slot.format == 'pdf'
                      ? PdfPreview(data: slot.bytes!)
                      : SafeImagePreview(
                          bytes: slot.bytes!,
                          height: 220,
                          semanticLabel:
                              'Selected source for ${slot.label.text}',
                        ),
              ],
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: busy ? null : () => task(() => pick(slot)),
                child: const Text('Choose source'),
              ),
              if (slot.bytes != null)
                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          slot.bytes = null;
                          slot.sourceName = null;
                          changed();
                        },
                  child: const Text('Clear source'),
                ),
              if (slots.length > 1)
                TextButton(
                  onPressed: busy
                      ? null
                      : () {
                          setState(() {
                            slots.removeAt(index);
                            presetReceipt = null;
                            output = null;
                            saved = null;
                          });
                          slot.dispose();
                        },
                  child: const Text('Remove slot'),
                ),
              if (index > 0)
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          slots.removeAt(index);
                          slots.insert(index - 1, slot);
                          presetReceipt = null;
                          output = null;
                          saved = null;
                        }),
                  child: const Text('Move up'),
                ),
            ],
          ),
          for (final doc
              in ref
                  .watch(preparedDocumentsProvider)
                  .where(
                    (doc) => slot.format == 'pdf'
                        ? doc.format == 'pdf'
                        : ['jpeg', 'png'].contains(doc.format),
                  ))
            TextButton(
              onPressed: busy
                  ? null
                  : () {
                      final total = slots
                          .where((s) => !identical(s, slot))
                          .fold<int>(0, (n, s) => n + (s.bytes?.length ?? 0));
                      if (total + doc.byteCount >
                          PreparedDocuments.maximumBytes) {
                        setState(
                          () =>
                              error = 'Pack sources must total at most 64 MiB.',
                        );
                        return;
                      }
                      slot.bytes = doc.bytes;
                      slot.sourceName = doc.name;
                      changed();
                    },
              child: Text('Use prepared ${doc.name}'),
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !preparing,
    child: Scaffold(
      appBar: AppBar(title: const Text('Custom application pack')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Your requirements, not official acceptance rules. Originals stay unchanged. Presets store settings only; source documents are never included in preset JSON.',
                    ),
                    if (busy) const LinearProgressIndicator(),
                    field(name, 'Preset name'),
                    field(revision, 'Revision date'),
                    TextFormField(
                      controller: source,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: 'Requirements source (optional)',
                      ),
                      onChanged: (_) => changed(),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: busy ? null : () => task(importPreset),
                          child: const Text('Import preset'),
                        ),
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () => task(savePresetLocally),
                          child: const Text('Save preset on this device'),
                        ),
                        OutlinedButton(
                          onPressed: busy ? null : () => task(openCatalogue),
                          child: const Text('Load saved preset'),
                        ),
                        OutlinedButton(
                          onPressed: busy
                              ? null
                              : () {
                                  if (!form.currentState!.validate()) return;
                                  task(() async {
                                    final result = await core
                                        .validatePackPreset(
                                          presetJson: preset(),
                                        );
                                    final location =
                                        await ExportService.saveCopy(
                                          result,
                                          'application-preset.json',
                                        );
                                    if (mounted && location != null) {
                                      setState(
                                        () => presetReceipt = SavedCopyReceipt(
                                          location,
                                          'json',
                                          result.bytes,
                                        ),
                                      );
                                    }
                                  });
                                },
                          child: const Text('Export preset'),
                        ),
                      ],
                    ),
                    if (presetReceipt != null) ...[
                      SelectableText(
                        'Preset saved and verified\n${presetReceipt!.location}',
                      ),
                      SavedCopyActions.receipt(presetReceipt!),
                    ],
                    const Text(
                      'Device presets are kept until you delete them. Up to 64 presets, each at most 64 KiB. Existing names are never replaced automatically; rename a changed preset or delete its saved copy first.',
                    ),
                    if (catalogueNotice != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(catalogueNotice!),
                      ),
                    for (var i = 0; i < slots.length; i++)
                      slotCard(slots[i], i),
                    OutlinedButton.icon(
                      onPressed: busy || slots.length >= 32
                          ? null
                          : () => setState(() {
                              final slot = _Slot();
                              var number = slots.length + 1;
                              while (slots.any(
                                (s) =>
                                    s.filename.text.toLowerCase() ==
                                    'document$number.jpg',
                              )) {
                                number++;
                              }
                              slot.filename.text = 'document$number.jpg';
                              slots.add(slot);
                              presetReceipt = null;
                              output = null;
                              saved = null;
                            }),
                      icon: const Icon(Icons.add),
                      label: const Text('Add document slot'),
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
                    FilledButton(
                      onPressed: busy ? null : () => prepare(),
                      child: const Text('Prepare and validate pack'),
                    ),
                    Text(
                      '${slots.where((s) => s.prepared != null).length} of ${slots.where((s) => s.required || s.bytes != null).length} documents ready. Successful results are reused; changing a document invalidates only that document.',
                    ),
                    if (preparing)
                      TextButton(
                        onPressed: stopRequested
                            ? null
                            : () => setState(() => stopRequested = true),
                        child: const Text('Stop after current operation'),
                      ),
                    if (preparationNotice != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(preparationNotice!),
                      ),
                    if (output != null) ...[
                      SelectableText(
                        '${output!.bytes.length} bytes\n${output!.validation}',
                      ),
                      field(zipName, 'ZIP filename', invalidatesOutput: false),
                      FilledButton.icon(
                        onPressed: busy
                            ? null
                            : () => task(() async {
                                final location = await ExportService.saveCopy(
                                  output!,
                                  zipName.text,
                                );
                                if (mounted && location != null) {
                                  setState(() => saved = location);
                                }
                              }),
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Save application ZIP'),
                      ),
                      if (saved != null) ...[
                        SelectableText('Saved and verified\n$saved'),
                        SavedCopyActions(
                          location: saved!,
                          format: output!.format,
                          bytes: output!.bytes,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
