import '../src/rust/vision.dart';
import 'scan_corners.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class DraftPage {
  final String name, mode;
  final Uint8List bytes;
  final int rotation;
  final double brightness, contrast;
  final PageCorners? corners;
  DraftPage(
    this.name,
    this.bytes, {
    this.corners,
    this.mode = 'original',
    this.rotation = 0,
    this.brightness = 0,
    this.contrast = 0,
  });
}

class DraftSummary {
  final String id;
  final DateTime created, expires;
  final int pages;
  DraftSummary(this.id, this.created, this.expires, this.pages);
}

class ScanDrafts {
  static const maxBytes = 64 * 1024 * 1024;
  final String directory;
  ScanDrafts(this.directory);
  String get root => '$directory/scan-drafts';
  static void validate(DraftPage p) {
    if (p.corners != null && cornerError(p.corners!) != null) {
      throw const FormatException('Invalid page corners.');
    }
    if (p.name.isEmpty ||
        p.name.length > 512 ||
        !['original', 'colour', 'grayscale', 'black_white'].contains(p.mode) ||
        p.rotation < 0 ||
        p.rotation > 3 ||
        !p.brightness.isFinite ||
        !p.contrast.isFinite ||
        p.brightness.abs() > 100 ||
        p.contrast.abs() > 100) {
      throw const FormatException('Invalid scan draft settings.');
    }
  }

  Future<String> save(List<DraftPage> pages, int days) => Isolate.run(() async {
    if (pages.isEmpty ||
        pages.length > 200 ||
        days < 1 ||
        days > 365 ||
        pages.fold<int>(0, (n, p) => n + p.bytes.length) > maxBytes) {
      throw const FormatException(
        'Use 1–200 pages, at most 64 MiB, and 1–365 retention days.',
      );
    }
    for (final page in pages) {
      validate(page);
    }
    final rootType = await FileSystemEntity.type(root, followLinks: false);
    if (rootType != FileSystemEntityType.notFound &&
        rootType != FileSystemEntityType.directory) {
      throw const FormatException('Draft storage must be a local directory.');
    }
    await Directory(root).create(recursive: true);
    final folder = await Directory(root).createTemp('draft-');
    try {
      final records = <Map<String, dynamic>>[];
      for (var i = 0; i < pages.length; i++) {
        final p = pages[i], name = 'page-${i.toString().padLeft(3, '0')}.bin';
        final file = File('${folder.path}/$name');
        await file.writeAsBytes(p.bytes, flush: true);
        final digest = sha256.convert(p.bytes).toString();
        if (sha256.convert(await file.readAsBytes()).toString() != digest) {
          throw const FileSystemException('Draft write verification failed.');
        }
        records.add({
          'file': name,
          'name': p.name,
          'bytes': p.bytes.length,
          'sha256': digest,
          'mode': p.mode,
          'rotation': p.rotation,
          'brightness': p.brightness,
          'contrast': p.contrast,
          'corners': encodeCorners(p.corners),
        });
      }
      final now = DateTime.now().toUtc();
      final manifest = File('${folder.path}/manifest.tmp');
      await manifest.writeAsString(
        jsonEncode({
          'schema': 2,
          'created': now.toIso8601String(),
          'expires': now.add(Duration(days: days)).toIso8601String(),
          'pages': records,
        }),
        flush: true,
      );
      await manifest.rename('${folder.path}/manifest.json');
      return folder.uri.pathSegments.where((s) => s.isNotEmpty).last;
    } catch (_) {
      await folder.delete(recursive: true);
      rethrow;
    }
  });
  Future<Directory> folder(String id) async {
    if (!RegExp(r'^draft-[A-Za-z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('Invalid draft identifier.');
    }
    if (await FileSystemEntity.type(root, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const FormatException('Draft storage is unavailable.');
    }
    final d = Directory('$root/$id');
    if (await FileSystemEntity.type(d.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const FormatException('Draft is unavailable.');
    }
    return d;
  }

  Future<Map<String, dynamic>> manifest(Directory d) async {
    final f = File('${d.path}/manifest.json');
    if (await FileSystemEntity.type(f.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await f.length() > 1024 * 1024) {
      throw const FormatException('Invalid draft manifest.');
    }
    final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    if (![1, 2].contains(m['schema']) ||
        m['pages'] is! List ||
        (m['pages'] as List).isEmpty ||
        (m['pages'] as List).length > 200) {
      throw const FormatException('Unsupported draft manifest.');
    }
    return m;
  }

  Future<List<DraftSummary>> list({DateTime? now}) => Isolate.run(() async {
    final type = await FileSystemEntity.type(root, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return <DraftSummary>[];
    }
    if (type != FileSystemEntityType.directory) {
      throw const FormatException('Draft storage must be a local directory.');
    }
    final result = <DraftSummary>[];
    await for (final entry in Directory(root).list(followLinks: false)) {
      if (entry is! Directory) {
        continue;
      }
      final id = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      try {
        final d = await folder(id), m = await manifest(d);
        final expires = DateTime.parse(m['expires'] as String);
        if (!expires.isAfter(now ?? DateTime.now().toUtc())) {
          await d.delete(recursive: true);
          continue;
        }
        result.add(
          DraftSummary(
            id,
            DateTime.parse(m['created'] as String),
            expires,
            (m['pages'] as List).length,
          ),
        );
      } on FormatException {
        continue;
      } on FileSystemException {
        continue;
      } on TypeError {
        continue;
      }
    }
    result.sort((a, b) => b.created.compareTo(a.created));
    return result;
  });
  Future<List<DraftPage>> restore(String id) => Isolate.run(() async {
    final d = await folder(id), m = await manifest(d);
    if (!DateTime.parse(
      m['expires'] as String,
    ).isAfter(DateTime.now().toUtc())) {
      throw const FormatException('This draft has expired.');
    }
    final pages = <DraftPage>[];
    var total = 0;
    for (final r in m['pages'] as List) {
      final name = r['file'] as String;
      if (!RegExp(r'^page-[0-9]{3}\.bin$').hasMatch(name)) {
        throw const FormatException('Invalid draft page filename.');
      }
      final f = File('${d.path}/$name');
      if (await FileSystemEntity.type(f.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw const FormatException('Draft page is unavailable.');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in f.openRead(0, maxBytes - total + 1)) {
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      total += bytes.length;
      if (total > maxBytes ||
          bytes.length != r['bytes'] ||
          sha256.convert(bytes).toString() != r['sha256']) {
        throw const FormatException(
          'Draft page failed integrity verification.',
        );
      }
      final p = DraftPage(
        r['name'] as String,
        bytes,
        corners: decodeCorners(r['corners']),
        mode: r['mode'] as String,
        rotation: r['rotation'] as int,
        brightness: (r['brightness'] as num).toDouble(),
        contrast: (r['contrast'] as num).toDouble(),
      );
      validate(p);
      pages.add(p);
    }
    return pages;
  });

  /// Explicit user-confirmed cleanup includes interrupted and corrupt drafts.
  /// Only owned, directly contained draft directories are eligible.
  Future<int> clear() => Isolate.run(() async {
    final type = await FileSystemEntity.type(root, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      return 0;
    }
    if (type != FileSystemEntityType.directory) {
      throw const FormatException('Draft storage must be a local directory.');
    }
    var deleted = 0;
    await for (final entry in Directory(root).list(followLinks: false)) {
      if (entry is! Directory) {
        continue;
      }
      final id = entry.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (!RegExp(r'^draft-[A-Za-z0-9_-]+$').hasMatch(id)) {
        continue;
      }
      await (await folder(id)).delete(recursive: true);
      deleted++;
    }
    return deleted;
  });
  Future<void> delete(String id) => Isolate.run(() async {
    await (await folder(id)).delete(recursive: true);
  });
}
