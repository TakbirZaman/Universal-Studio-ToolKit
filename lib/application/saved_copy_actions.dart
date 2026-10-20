import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as paths;

enum SavedPlatform { android, windows, linux, unsupported }

enum SavedAction { open, share, reveal }

const outputMimeTypes = {
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'pdf': 'application/pdf',
  'zip': 'application/zip',
  'json': 'application/json',
  'txt': 'text/plain',
};

void validateSavedTarget(
  String location,
  String format,
  SavedPlatform platform,
) {
  if (!outputMimeTypes.containsKey(format) ||
      location.isEmpty ||
      location.length > 32768 ||
      RegExp(r'[\x00-\x1f]').hasMatch(location)) {
    throw const FormatException('This saved copy cannot be opened here.');
  }
  if (platform == SavedPlatform.android) {
    final uri = Uri.tryParse(location);
    if (uri == null ||
        uri.scheme != 'content' ||
        uri.authority.isEmpty ||
        uri.hasFragment) {
      throw const FormatException(
        'Use the document location returned by Save a copy.',
      );
    }
    return;
  }
  final context = paths.Context(
    style: platform == SavedPlatform.windows
        ? paths.Style.windows
        : paths.Style.posix,
  );
  final extension = context.extension(location).toLowerCase();
  if (!context.isAbsolute(location) ||
      !(extension == '.$format' || format == 'jpeg' && extension == '.jpg')) {
    throw const FormatException(
      'Use an absolute saved document location with the correct extension.',
    );
  }
}

class SavedCopyReceipt {
  final String location, format;
  final Uint8List bytes;
  const SavedCopyReceipt(this.location, this.format, this.bytes);
}

abstract class SavedCopyAccess {
  Future<Set<SavedAction>> capabilities(String location, String format);
  Future<void> request(
    SavedAction action,
    String location,
    String format,
    Uint8List expectedBytes,
  );
}

class PlatformSavedCopyAccess implements SavedCopyAccess {
  final SavedPlatform platform;
  final MethodChannel channel;
  PlatformSavedCopyAccess({
    SavedPlatform? platform,
    this.channel = const MethodChannel('dev.universalstudio/saved'),
  }) : platform =
           platform ??
           (Platform.isAndroid
               ? SavedPlatform.android
               : Platform.isWindows
               ? SavedPlatform.windows
               : Platform.isLinux
               ? SavedPlatform.linux
               : SavedPlatform.unsupported);

  Future<String?> linuxTool(String name) async {
    for (final root in ['/usr/bin', '/bin']) {
      final file = File('$root/$name');
      if (await file.exists()) return file.path;
    }
    return null;
  }

  Future<bool> linuxAssociation(String tool, String mime) async {
    final process = await Process.start(tool, [
      'query',
      'default',
      mime,
    ], runInShell: false);
    await process.stdin.close();
    unawaited(process.stderr.drain<void>().catchError((Object _) {}));
    final output = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .take(1)
        .join();
    try {
      final values = await Future.wait<Object>([
        process.exitCode,
        output,
      ]).timeout(const Duration(seconds: 3));
      return values[0] == 0 && (values[1] as String).trim().isNotEmpty;
    } catch (_) {
      process.kill();
      return false;
    }
  }

  @override
  Future<Set<SavedAction>> capabilities(String location, String format) async {
    try {
      validateSavedTarget(location, format, platform);
      if (platform == SavedPlatform.android ||
          platform == SavedPlatform.windows) {
        final result = await channel.invokeMapMethod<String, dynamic>(
          'capabilities',
          {'location': location, 'mime': outputMimeTypes[format]},
        );
        return {
          for (final action in SavedAction.values)
            if (result?[action.name] == true) action,
        };
      }
      if (platform == SavedPlatform.linux) {
        if ((Platform.environment['DISPLAY'] ?? '').isEmpty &&
            (Platform.environment['WAYLAND_DISPLAY'] ?? '').isEmpty) {
          return {};
        }
        if (await FileSystemEntity.type(location, followLinks: false) !=
                FileSystemEntityType.file ||
            await linuxTool('xdg-open') == null) {
          return {};
        }
        final query = await linuxTool('xdg-mime');
        if (query == null) return {};
        final result = <SavedAction>{};
        for (final entry in {
          SavedAction.open: outputMimeTypes[format]!,
          SavedAction.reveal: 'inode/directory',
        }.entries) {
          if (await linuxAssociation(query, entry.value)) {
            result.add(entry.key);
          }
        }
        return result;
      }
    } on Object {
      return {};
    }
    return {};
  }

  @override
  Future<void> request(
    SavedAction action,
    String location,
    String format,
    Uint8List expectedBytes,
  ) async {
    validateSavedTarget(location, format, platform);
    if (expectedBytes.isEmpty || expectedBytes.length > 64 * 1024 * 1024) {
      throw const FormatException(
        'This output is outside the supported saved-copy limit.',
      );
    }
    if (platform == SavedPlatform.linux || platform == SavedPlatform.windows) {
      if (await FileSystemEntity.type(location, followLinks: false) !=
              FileSystemEntityType.file ||
          await File(location).length() != expectedBytes.length) {
        throw const FormatException(
          'The saved copy has changed or is no longer available.',
        );
      }
      var offset = 0;
      await for (final chunk in File(
        location,
      ).openRead(0, expectedBytes.length + 1)) {
        for (final byte in chunk) {
          if (offset >= expectedBytes.length ||
              byte != expectedBytes[offset++]) {
            throw const FormatException(
              'The saved copy has changed. Check it before opening or sharing.',
            );
          }
        }
      }
      if (offset != expectedBytes.length) {
        throw const FormatException(
          'The saved copy could not be verified again.',
        );
      }
    }
    if (!(await capabilities(location, format)).contains(action)) {
      throw const FormatException(
        'No application is available for that action. The saved copy is unchanged.',
      );
    }
    if (platform == SavedPlatform.android ||
        platform == SavedPlatform.windows) {
      await channel.invokeMethod<void>(action.name, {
        'location': location,
        'mime': outputMimeTypes[format],
      });
      return;
    }
    if (platform == SavedPlatform.linux && action != SavedAction.share) {
      final executable = await linuxTool('xdg-open');
      final target = action == SavedAction.reveal
          ? File(location).parent.path
          : location;
      if (executable == null || !await File(location).exists()) {
        throw const FormatException(
          'The saved copy or desktop opener is no longer available.',
        );
      }
      try {
        // A single absolute file argument, never shell text or a user URL.
        // Detached launch hands off to the desktop; it does not claim viewing completed.
        await Process.start(
          executable,
          [target],
          runInShell: false,
          mode: ProcessStartMode.detached,
        );
        return;
      } on ProcessException {
        throw const FormatException(
          'Could not ask the desktop to open the copy. You can open the saved location manually.',
        );
      }
    }
    throw const FormatException('This action is unavailable on this device.');
  }
}

final savedCopyAccessProvider = Provider<SavedCopyAccess>(
  (ref) => PlatformSavedCopyAccess(),
);

class SavedCopyActions extends ConsumerStatefulWidget {
  final String location, format;
  final Uint8List bytes;
  final VoidCallback? onAnother;
  const SavedCopyActions({
    super.key,
    required this.location,
    required this.format,
    required this.bytes,
    this.onAnother,
  });
  SavedCopyActions.receipt(
    SavedCopyReceipt receipt, {
    Key? key,
    VoidCallback? onAnother,
  }) : this(
         key: key,
         location: receipt.location,
         format: receipt.format,
         bytes: receipt.bytes,
         onAnother: onAnother,
       );
  @override
  ConsumerState<SavedCopyActions> createState() => _SavedCopyActionsState();
}

class _SavedCopyActionsState extends ConsumerState<SavedCopyActions> {
  late Future<Set<SavedAction>> available;
  bool busy = false;
  String? message;
  @override
  void initState() {
    super.initState();
    probe();
  }

  void probe() {
    available = ref
        .read(savedCopyAccessProvider)
        .capabilities(widget.location, widget.format);
  }

  @override
  void didUpdateWidget(covariant SavedCopyActions old) {
    super.didUpdateWidget(old);
    if (old.location != widget.location || old.format != widget.format) {
      message = null;
      probe();
    }
  }

  Future<void> request(SavedAction action) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await ref
          .read(savedCopyAccessProvider)
          .request(action, widget.location, widget.format, widget.bytes);
      if (mounted) {
        setState(
          () => message = action == SavedAction.share
              ? 'Choose an app to share your saved copy.'
              : 'Opening requested. Your original file is unchanged.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Could not complete that action. You can use the saved location above.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Set<SavedAction>>(
    future: available,
    builder: (context, snapshot) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in {
              SavedAction.open: ('Open copy', Icons.open_in_new),
              SavedAction.share: ('Share copy', Icons.share_outlined),
              SavedAction.reveal: (
                'Show in folder',
                Icons.folder_open_outlined,
              ),
            }.entries)
              if (snapshot.data?.contains(entry.key) ?? false)
                OutlinedButton.icon(
                  onPressed: busy ? null : () => request(entry.key),
                  icon: Icon(entry.value.$2),
                  label: Text(entry.value.$1),
                ),
            if (widget.onAnother != null)
              TextButton.icon(
                onPressed: busy ? null : widget.onAnother,
                icon: const Icon(Icons.add),
                label: const Text('Process another'),
              ),
          ],
        ),
        if (message != null) Semantics(liveRegion: true, child: Text(message!)),
      ],
    ),
  );
}
