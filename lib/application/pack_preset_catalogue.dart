import 'dart:convert';

import 'package:flutter/material.dart';

import '../src/rust/api.dart' as core;

class PackPresetCatalogue extends StatefulWidget {
  final String directory;
  const PackPresetCatalogue({super.key, required this.directory});
  @override
  State<PackPresetCatalogue> createState() => _CatalogueState();
}

class _CatalogueState extends State<PackPresetCatalogue> {
  List<String> presets = [];
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await core.listPackPresets(directory: widget.directory);
      if (mounted) setState(() => presets = result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove(String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete saved preset?'),
        content: Text(
          'Remove “$name” from this device? Your current editor, source documents and exported files stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep preset'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete preset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await core.deletePackPreset(directory: widget.directory, name: name);
      if (mounted) await load();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Saved application presets')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Saved settings include names and requirements-source text. Source documents are excluded. Loading clears the editor’s selected sources; exported files stay unchanged.',
          ),
          const SizedBox(height: 16),
          if (busy) const LinearProgressIndicator(),
          if (error != null)
            Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (!busy && error != null)
            TextButton(
              onPressed: load,
              child: const Text('Try loading presets again'),
            ),
          if (!busy && error == null && presets.isEmpty)
            const Text('No saved presets on this device.'),
          for (final text in presets)
            Builder(
              builder: (context) {
                final preset = jsonDecode(text) as Map<String, dynamic>;
                final name = preset['name'] as String;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Revision ${preset['revision_date']} · ${(preset['slots'] as List).length} document slots',
                        ),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: busy
                                  ? null
                                  : () => Navigator.pop(context, text),
                              child: Text('Use $name'),
                            ),
                            TextButton(
                              onPressed: busy ? null : () => remove(name),
                              child: Text('Delete $name'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}
