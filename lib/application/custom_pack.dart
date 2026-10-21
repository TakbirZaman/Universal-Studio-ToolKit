import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../src/rust/api.dart' as core;
import 'export_service.dart';
import 'prepared_documents.dart';
import 'saved_copy_actions.dart';

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
  bool required = true;
  String format = 'jpeg';
  String? sourceName;
  Uint8List? bytes;
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
  String? error, saved;
  bool busy = false;
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
      output = null;
      saved = null;
      error = null;
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
    if (await file.length() + total > PreparedDocuments.maximumBytes) {
      throw const FormatException('Pack sources must total at most 64 MiB.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length + total > PreparedDocuments.maximumBytes) {
      throw const FormatException('Pack sources must total at most 64 MiB.');
    }
    if (!mounted) return;
    setState(() {
      slot.bytes = bytes;
      slot.sourceName = file.name;
      output = null;
      saved = null;
    });
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
      name.text = json['name'] as String;
      revision.text = json['revision_date'] as String;
      source.text = json['source'] as String? ?? '';
      output = null;
      saved = null;
    });
  }

  Future<void> prepare() async {
    if (!form.currentState!.validate()) return;
    await task(() async {
      final result = await core.createCustomApplicationPack(
        inputs: slots.map((slot) => slot.bytes ?? Uint8List(0)).toList(),
        presetJson: preset(),
      );
      if (mounted)
        setState(() {
          output = result;
          saved = null;
        });
    });
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
            decoration: const InputDecoration(labelText: 'Output format'),
            items: const [
              DropdownMenuItem(value: 'jpeg', child: Text('JPEG image')),
              DropdownMenuItem(value: 'png', child: Text('PNG image')),
              DropdownMenuItem(value: 'pdf', child: Text('PDF document')),
            ],
            onChanged: busy
                ? null
                : (value) => setState(() {
                    slot.format = value!;
                    slot.bytes = null;
                    slot.sourceName = null;
                    slot.filename.text =
                        'document${index + 1}.${value == 'jpeg' ? 'jpg' : value}';
                    output = null;
                    saved = null;
                  }),
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
              'Images fit inside these dimensions with padding. JPEG uses a white background. PNG retains transparency.',
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
  Widget build(BuildContext context) => Scaffold(
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
                            : () {
                                if (!form.currentState!.validate()) return;
                                task(() async {
                                  final result = await core.validatePackPreset(
                                    presetJson: preset(),
                                  );
                                  await ExportService.saveCopy(
                                    result,
                                    'application-preset.json',
                                  );
                                });
                              },
                        child: const Text('Export preset'),
                      ),
                    ],
                  ),
                  for (var i = 0; i < slots.length; i++) slotCard(slots[i], i),
                  OutlinedButton.icon(
                    onPressed: busy || slots.length >= 32
                        ? null
                        : () => setState(() {
                            final slot = _Slot();
                            slot.filename.text =
                                'document${slots.length + 1}.jpg';
                            slots.add(slot);
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
                    onPressed: busy ? null : prepare,
                    child: const Text('Prepare and validate pack'),
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
                              if (mounted && location != null)
                                setState(() => saved = location);
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
  );
}
