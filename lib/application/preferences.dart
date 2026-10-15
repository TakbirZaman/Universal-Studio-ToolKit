import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../src/rust/api.dart' as core;

final dataDirectoryProvider = Provider<String?>((ref) => null);
final storageNoticeProvider = Provider<String?>((ref) => null);

class PreferencesDialog extends ConsumerStatefulWidget {
  final ValueChanged<String> onTheme;
  const PreferencesDialog({super.key, required this.onTheme});
  @override
  ConsumerState<PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends ConsumerState<PreferencesDialog> {
  core.StudioPreferences? settings;
  String? error;
  bool busy = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final dir = ref.read(dataDirectoryProvider);
    if (dir == null) {
      setState(() {
        busy = false;
        error = 'Persistent settings are unavailable in this session.';
      });
      return;
    }
    try {
      final s = await core.loadPreferences(directory: dir);
      if (mounted) setState(() => settings = s);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    final s = settings;
    if (s == null) return;
    setState(() => busy = true);
    try {
      await core.savePreferences(
        directory: ref.read(dataDirectoryProvider)!,
        preferences: s,
      );
      widget.onTheme(s.theme);
      if (mounted) Navigator.of(context).pop();
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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Appearance and privacy'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ref.watch(storageNoticeProvider) case final String notice)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(notice),
            ),
          if (busy) const LinearProgressIndicator(),
          if (settings != null) ...[
            DropdownButtonFormField<String>(
              initialValue: settings!.theme,
              decoration: const InputDecoration(labelText: 'Theme'),
              items: const [
                DropdownMenuItem(value: 'system', child: Text('Follow system')),
                DropdownMenuItem(value: 'light', child: Text('Light')),
                DropdownMenuItem(value: 'dark', child: Text('Dark')),
              ],
              onChanged: busy
                  ? null
                  : (value) => setState(
                      () => settings = core.StudioPreferences(
                        theme: value!,
                        historyEnabled: settings!.historyEnabled,
                        retentionDays: settings!.retentionDays,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Documents are processed on your device. This build does not upload files or keep document content in recent history.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Recent-history recording is not enabled by the interface yet. Any previously recorded summaries can be cleared below.',
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      try {
                        await core.clearRecentHistory(
                          directory: ref.read(dataDirectoryProvider)!,
                        );
                        if (mounted) {
                          setState(() => error = 'Recent history cleared.');
                        }
                      } catch (e) {
                        if (mounted) setState(() => error = e.toString());
                      }
                    },
              child: const Text('Clear recent history'),
            ),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: busy || settings == null ? null : save,
        child: const Text('Save settings'),
      ),
    ],
  );
}
