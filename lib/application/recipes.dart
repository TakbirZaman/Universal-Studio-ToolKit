import 'dart:convert';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../src/rust/api.dart' as core;
import 'preferences.dart';
import 'export_service.dart';
import 'recipe_batch.dart';

class RecipesScreen extends ConsumerStatefulWidget {
  const RecipesScreen({super.key});
  @override
  ConsumerState<RecipesScreen> createState() => _RecipesState();
}

class _RecipesState extends ConsumerState<RecipesScreen> {
  final form = GlobalKey<FormState>();
  final fields = {
    for (final e in {
      'name': 'Application photo',
      'width': '300',
      'height': '300',
      'limit': '100',
      'filename': 'photo.jpg',
      'x': '0',
      'y': '0',
      'cropWidth': '300',
      'cropHeight': '300',
    }.entries)
      e.key: TextEditingController(text: e.value),
  };
  bool busy = false,
      crop = false,
      original = false,
      cover = false,
      strict = true;
  int quality = 60;
  String format = 'jpeg', unit = 'ki_b';
  String? message, sourceName;
  Uint8List? source;
  core.StudioOutput? output;
  RecipeBatch? batch;
  List<String> saved = [];
  String value(String key) => fields[key]!.text.trim();
  int number(String key) => int.parse(value(key));
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    batch?.cancel();
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void changed() {
    setState(() {
      output = null;
      message = null;
    });
  }

  Future<void> action(Future<void> Function() work) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> load() async {
    final dir = ref.read(dataDirectoryProvider);
    if (dir == null) return;
    try {
      final recipes = await core.listRecipes(directory: dir);
      if (mounted) setState(() => saved = recipes);
    } catch (e) {
      if (mounted) setState(() => message = e.toString());
    }
  }

  String document() => jsonEncode({
    'schema_version': crop ? 2 : 1,
    'name': value('name'),
    'revision_date': DateTime.now().toUtc().toIso8601String().split('T').first,
    'steps': [
      if (crop)
        {
          'type': 'crop',
          'x': number('x'),
          'y': number('y'),
          'width': number('cropWidth'),
          'height': number('cropHeight'),
        },
      if (!original)
        {
          'type': 'resize',
          'width': number('width'),
          'height': number('height'),
          'fit': cover ? 'cover' : 'contain',
        },
      if (value('limit').isNotEmpty)
        {
          'type': 'compress',
          'limit': {'value': number('limit'), 'unit': unit, 'strict': strict},
          'min_quality': quality,
        },
      {'type': 'remove_metadata'},
      {'type': 'rename', 'filename': value('filename')},
      {'type': 'export', 'format': format},
    ],
  });
  core.StudioOutput jsonOutput(String text) => core.StudioOutput(
    bytes: Uint8List.fromList(utf8.encode(text)),
    format: 'json',
    validation: '',
  );
  Future<void> validate(String json) => core.validatePreparedOutput(
    output: jsonOutput(json),
    filename: 'recipe.json',
  );
  void populate(String json) {
    final r = jsonDecode(json) as Map;
    setState(() {
      fields['name']!.text = r['name'];
      crop = false;
      original = true;
      fields['limit']!.clear();
      quality = 60;
      cover = false;
      for (final step in r['steps']) {
        switch (step['type']) {
          case 'crop':
            crop = true;
            for (final key in ['x', 'y']) {
              fields[key]!.text = '${step[key]}';
            }
            fields['cropWidth']!.text = '${step['width']}';
            fields['cropHeight']!.text = '${step['height']}';
          case 'resize':
            original = false;
            fields['width']!.text = '${step['width']}';
            fields['height']!.text = '${step['height']}';
            cover = step['fit'] == 'cover';
          case 'compress':
            fields['limit']!.text = '${step['limit']['value']}';
            unit = step['limit']['unit'];
            strict = step['limit']['strict'];
            quality = step['min_quality'];
          case 'export':
            format = step['format'];
        }
      }
      fields['filename']!.text = format == 'png' ? 'photo.png' : 'photo.jpg';
      for (final s in r['steps']) {
        if (s['type'] == 'rename') fields['filename']!.text = s['filename'];
      }
      output = null;
      message = 'Recipe loaded. Review settings before processing.';
    });
  }

  Future<void> store() async {
    if (!form.currentState!.validate()) return;
    await action(() async {
      final dir = ref.read(dataDirectoryProvider);
      if (dir == null) {
        throw StateError(
          'Local recipe storage is unavailable. Export a recipe file instead.',
        );
      }
      final json = document();
      await validate(json);
      final list = await core.listRecipes(directory: dir);
      if (list.any((r) => jsonDecode(r)['name'] == value('name'))) {
        if (!mounted) return;
        final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Replace saved recipe?'),
            content: const Text(
              'To keep both, cancel and duplicate with a different name.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Replace recipe'),
              ),
            ],
          ),
        );
        if (replace != true) return;
      }
      await core.saveRecipe(directory: dir, recipeJson: json);
      await load();
      if (mounted) setState(() => message = 'Recipe saved on this device.');
    });
  }

  Future<void> importRecipe() => action(() async {
    final f = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'Recipe JSON', extensions: ['json']),
      ],
    );
    if (f == null) return;
    if (await f.length() > 65536) {
      throw const FormatException('Recipe exceeds 64 KiB.');
    }
    final bytes = await f.readAsBytes();
    if (bytes.length > 65536) {
      throw const FormatException('Recipe exceeds 64 KiB.');
    }
    final json = utf8.decode(bytes);
    await validate(json);
    if (mounted) populate(json);
  });
  Future<Uint8List> readPhoto(XFile file) async {
    if (await file.length() > 64 * 1024 * 1024) {
      throw const FormatException('Photo exceeds 64 MiB.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > 64 * 1024 * 1024) {
      throw const FormatException('Photo exceeds 64 MiB.');
    }
    return bytes;
  }

  static const imageType = XTypeGroup(
    label: 'JPEG and PNG',
    extensions: ['jpg', 'jpeg', 'png'],
  );
  Future<void> choosePhoto() => action(() async {
    final f = await openFile(acceptedTypeGroups: [imageType]);
    if (f == null) return;
    final bytes = await readPhoto(f);
    if (mounted) {
      setState(() {
        source = bytes;
        sourceName = f.name;
        output = null;
      });
    }
  });
  Future<void> chooseBatch() async {
    if (!form.currentState!.validate()) return;
    await action(() async {
      final json = document();
      await validate(json);
      final files = await openFiles(acceptedTypeGroups: [imageType]);
      if (files.isEmpty) return;
      if (files.length > 100) {
        throw const FormatException('Choose at most 100 photos.');
      }
      files.sort((a, b) => a.name.compareTo(b.name));
      final name = value('filename'), dot = value('filename').lastIndexOf('.');
      final items = <RecipeBatchItem>[];
      var total = 0;
      for (var i = 0; i < files.length; i++) {
        if (total + await files[i].length() > 64 * 1024 * 1024) {
          throw const FormatException('Batch exceeds 64 MiB.');
        }
        final bytes = await readPhoto(files[i]);
        total += bytes.length;
        if (total > 64 * 1024 * 1024) {
          throw const FormatException('Batch exceeds 64 MiB.');
        }
        final out =
            '${name.substring(0, dot)}-${(i + 1).toString().padLeft(3, '0')}${name.substring(dot)}';
        if (utf8.encode(out).length > 180) {
          throw const FormatException('Use a shorter output filename.');
        }
        items.add(RecipeBatchItem(files[i].name, out, bytes));
      }
      if (mounted) {
        setState(() {
          batch = RecipeBatch(json, items);
          message =
              'Batch settings captured. Later edits do not change this batch.';
        });
      }
    });
  }

  Widget field(
    String key,
    String label, {
    bool numeric = false,
    bool zero = false,
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: fields[key],
      enabled: !busy,
      onChanged: (_) => changed(),
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label),
      validator: (s) {
        if (optional && (s ?? '').isEmpty) return null;
        if (numeric) {
          final n = int.tryParse(s ?? '');
          return n != null && n >= (zero ? 0 : 1)
              ? null
              : 'Enter a valid whole number.';
        }
        return (s ?? '').trim().isEmpty ? 'Enter a value.' : null;
      },
    ),
  );
  Widget toggle(String title, bool value, ValueChanged<bool> set) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        value: value,
        onChanged: busy
            ? null
            : (v) {
                setState(() => set(v));
                changed();
              },
      );
  Widget choice(
    String label,
    String selected,
    Map<String, String> choices,
    ValueChanged<String> set,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$selected'),
      initialValue: selected,
      isExpanded: true,
      itemHeight: null,
      decoration: InputDecoration(labelText: label),
      items: choices.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: busy
          ? null
          : (v) {
              setState(() => set(v!));
              changed();
            },
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Photo recipes')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Save photo requirements and reuse them. Your original file is unchanged.',
          ),
          const SizedBox(height: 16),
          if (saved.isNotEmpty)
            DropdownButtonFormField<String>(
              key: ValueKey(saved.join()),
              isExpanded: true,
              itemHeight: null,
              decoration: const InputDecoration(labelText: 'Load saved recipe'),
              items: saved
                  .map(
                    (r) => DropdownMenuItem(
                      value: r,
                      child: Text(jsonDecode(r)['name']),
                    ),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (r) {
                      if (r != null) populate(r);
                    },
            ),
          Wrap(
            spacing: 12,
            children: [
              TextButton(
                onPressed: busy ? null : importRecipe,
                child: const Text('Import recipe'),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        setState(
                          () => fields['name']!.text = '${value('name')} copy',
                        );
                      },
                child: const Text('Duplicate'),
              ),
            ],
          ),
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field('name', 'Recipe name'),
                ExpansionTile(
                  title: const Text('Crop before resizing'),
                  children: [
                    const Text(
                      'Coordinates use the orientation-corrected original photo. Crops outside it are rejected.',
                    ),
                    toggle('Apply crop', crop, (v) => crop = v),
                    if (crop) ...[
                      field(
                        'x',
                        'Left edge (pixels)',
                        numeric: true,
                        zero: true,
                      ),
                      field(
                        'y',
                        'Top edge (pixels)',
                        numeric: true,
                        zero: true,
                      ),
                      field('cropWidth', 'Crop width (pixels)', numeric: true),
                      field(
                        'cropHeight',
                        'Crop height (pixels)',
                        numeric: true,
                      ),
                    ],
                  ],
                ),
                toggle(
                  'Keep original dimensions',
                  original,
                  (v) => original = v,
                ),
                if (!original) ...[
                  field('width', 'Width (pixels)', numeric: true),
                  field('height', 'Height (pixels)', numeric: true),
                  toggle(
                    'Fill and crop edges instead of fitting with padding',
                    cover,
                    (v) => cover = v,
                  ),
                ],
                field(
                  'limit',
                  'Maximum file size (optional)',
                  numeric: true,
                  optional: true,
                ),
                choice('Size unit', unit, {
                  'kb': 'KB — 1,000 bytes',
                  'ki_b': 'KiB — 1,024 bytes',
                }, (v) => unit = v),
                toggle(
                  'Strictly below limit (off: at most)',
                  strict,
                  (v) => strict = v,
                ),
                choice('Output format', format, {
                  'jpeg': 'JPEG',
                  'png': 'PNG',
                }, (v) => format = v),
                field('filename', 'Output filename including extension'),
                Text('Filename preview: ${value('filename')}'),
                ExpansionTile(
                  title: const Text('Quality and privacy'),
                  children: [
                    Text('Minimum JPEG quality: $quality'),
                    Slider(
                      value: quality.toDouble(),
                      min: 1,
                      max: 100,
                      divisions: 99,
                      onChanged: busy
                          ? null
                          : (v) {
                              setState(() => quality = v.round());
                              changed();
                            },
                    ),
                    const Text(
                      'Metadata is removed. PNG stays lossless. Transparent input is never silently flattened to JPEG. Rotation and edits from other tools are not inherited.',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                onPressed: busy ? null : store,
                child: const Text('Save recipe'),
              ),
              OutlinedButton(
                onPressed: busy
                    ? null
                    : () {
                        if (!form.currentState!.validate()) return;
                        action(() async {
                          final json = document();
                          await validate(json);
                          final path = await ExportService.saveCopy(
                            jsonOutput(json),
                            'recipe.json',
                          );
                          if (mounted && path != null) {
                            setState(() => message = 'Saved: $path');
                          }
                        });
                      },
                child: const Text('Export recipe file'),
              ),
            ],
          ),
          const Divider(height: 32),
          OutlinedButton(
            onPressed: busy ? null : choosePhoto,
            child: Text(sourceName ?? 'Choose a photo'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () {
                    if (!form.currentState!.validate()) return;
                    action(() async {
                      if (source == null) {
                        throw StateError('Choose a photo first.');
                      }
                      final result = await core.runRecipe(
                        data: source!,
                        recipeJson: document(),
                      );
                      if (mounted) setState(() => output = result);
                    });
                  },
            child: const Text('Prepare preview'),
          ),
          if (busy) const LinearProgressIndicator(),
          if (message != null)
            Semantics(liveRegion: true, child: Text(message!)),
          if (output != null) ...[
            Image.memory(
              output!.bytes,
              height: 320,
              fit: BoxFit.contain,
              semanticLabel: 'Prepared recipe output',
            ),
            Text(
              '${output!.width} × ${output!.height} • ${output!.format} • ${output!.bytes.length} bytes',
            ),
            Text(output!.validation),
            FilledButton(
              onPressed: busy
                  ? null
                  : () => action(() async {
                      final path = await ExportService.saveCopy(
                        output!,
                        value('filename'),
                      );
                      if (mounted && path != null) {
                        setState(
                          () => message =
                              'Saved: $path. Your original file is unchanged.',
                        );
                      }
                    }),
              child: const Text('Save a copy'),
            ),
          ],
          const Divider(height: 32),
          Text(
            'Process several photos',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Review numbered filenames. Successful results survive failures and cancellation. Save outputs individually.',
          ),
          OutlinedButton(
            onPressed: busy ? null : chooseBatch,
            child: const Text('Choose batch photos'),
          ),
          if (batch != null) ...[
            for (final item in batch!.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${item.sourceName} → ${item.outputName}'),
                subtitle: Text(
                  '${item.state.name}${item.error == null ? '' : ' • ${item.error}'}${item.output == null ? '' : ' • ${item.output!.bytes.length} bytes'}${item.savedLocation == null ? '' : ' • Saved: ${item.savedLocation}'}',
                ),
                trailing: item.output == null
                    ? null
                    : IconButton(
                        tooltip: 'Save ${item.outputName}',
                        icon: const Icon(Icons.save_alt),
                        onPressed: busy
                            ? null
                            : () => action(() async {
                                final path = await ExportService.saveCopy(
                                  item.output!,
                                  item.outputName,
                                );
                                if (mounted && path != null) {
                                  setState(() => item.savedLocation = path);
                                }
                              }),
                      ),
              ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () => action(() async {
                      await batch!.run(
                        notify: () {
                          if (mounted) setState(() {});
                        },
                      );
                    }),
              child: const Text('Process pending / retry failed'),
            ),
            if (batch!.running)
              TextButton(
                onPressed: batch!.cancellationRequested
                    ? null
                    : () {
                        setState(() => batch!.cancel());
                      },
                child: const Text('Cancel after current photo'),
              ),
            if (batch!.cancellationRequested && batch!.running)
              const Text(
                'Cancelling after current photo. Completed results will be kept.',
              ),
          ],
        ],
      ),
    ),
  );
}
