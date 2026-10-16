import 'application/camera_capture.dart';
import 'package:flutter/services.dart';
import 'application/scan_drafts.dart';
import 'application/scan_draft_picker.dart';
import 'application/transparency_preview.dart';
import 'dart:io';
import 'application/recipes.dart';
import 'package:path_provider/path_provider.dart';
import 'application/pdf_preview.dart';
import 'application/preferences.dart';
import 'application/export_service.dart';
import 'package:path/path.dart' as paths;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'application/studio_service.dart';
import 'design/theme.dart';
import 'src/rust/frb_generated.dart';
import 'src/rust/api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    var path = Platform.environment['UST_CORE_LIBRARY'];
    if (path == null && (Platform.isLinux || Platform.isWindows)) {
      final candidate = Platform.isWindows
          ? paths.join(
              paths.dirname(Platform.resolvedExecutable),
              'studio_core.dll',
            )
          : paths.join(
              paths.dirname(Platform.resolvedExecutable),
              'lib',
              'libstudio_core.so',
            );
      if (File(candidate).existsSync()) path = candidate;
    }
    await RustLib.init(
      externalLibrary: path == null ? null : ExternalLibrary.open(path),
    );
    String? storage;
    String? storageNotice;
    String initialTheme = 'system';
    try {
      final support = await getApplicationSupportDirectory();
      storage = support.path;
      if (Platform.environment['UST_PORTABLE'] == '1' &&
          (Platform.isWindows || Platform.isLinux)) {
        final portable = Directory(
          paths.join(paths.dirname(Platform.resolvedExecutable), 'studio-data'),
        );
        try {
          await portable.create(recursive: true);
          final check = File(paths.join(portable.path, '.writable-check'));
          await check.writeAsString('');
          await check.delete();
          storage = portable.path;
          storageNotice =
              'Portable mode: settings are saved in studio-data beside the application.';
        } catch (_) {
          storageNotice =
              'Portable storage is not writable. Settings are saved in your local application-support folder instead.';
        }
      }
      initialTheme = (await loadPreferences(directory: storage!)).theme;
    } catch (_) {
      storage = null;
      storageNotice =
          'Settings could not be saved on this device. Changes apply only to this session.';
    }
    runApp(
      ProviderScope(
        overrides: [
          dataDirectoryProvider.overrideWithValue(storage),
          storageNoticeProvider.overrideWithValue(storageNotice),
        ],
        child: StudioApp(initialTheme: initialTheme),
      ),
    );
  } catch (_) {
    runApp(
      MaterialApp(
        theme: StudioTokens.theme(Brightness.light),
        home: const Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'The processing engine could not start. Reinstall the complete application bundle. Your files have not been changed.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StudioApp extends StatefulWidget {
  final String initialTheme;
  const StudioApp({super.key, this.initialTheme = "system"});
  @override
  State<StudioApp> createState() => _StudioAppState();
}

class _StudioAppState extends State<StudioApp> {
  ThemeMode mode = ThemeMode.system;
  @override
  void initState() {
    super.initState();
    mode = switch (widget.initialTheme) {
      "dark" => ThemeMode.dark,
      "light" => ThemeMode.light,
      _ => ThemeMode.system,
    };
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Universal Studio Toolkit',
    theme: StudioTokens.theme(Brightness.light),
    darkTheme: StudioTokens.theme(Brightness.dark),
    themeMode: mode,
    home: StudioHome(
      onSettings: (context) => showDialog<void>(
        context: context,
        builder: (_) => PreferencesDialog(
          onTheme: (value) => setState(
            () => mode = switch (value) {
              "dark" => ThemeMode.dark,
              "light" => ThemeMode.light,
              _ => ThemeMode.system,
            },
          ),
        ),
      ),
      onTheme: () {
        setState(
          () =>
              mode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
        );
      },
    ),
  );
}

enum Tool { photo, signature, merge, scan, pack, print }

extension ToolLabel on Tool {
  String get label => switch (this) {
    Tool.photo => 'Resize Photo',
    Tool.signature => 'Clean Signature',
    Tool.merge => 'Combine PDFs',
    Tool.scan => 'Scan Documents',
    Tool.pack => 'Prepare Application',
    Tool.print => 'Photo Print Sheet',
  };
  String get description => switch (this) {
    Tool.photo => 'A smaller file. The exact dimensions you need.',
    Tool.signature => 'Remove a plain background and save a transparent PNG.',
    Tool.merge => 'Combine files, choose page order, and rotate pages.',
    Tool.scan => 'Turn imported page images into one organised PDF.',
    Tool.pack => 'Prepare a photo, signature and certificate together.',
    Tool.print => 'Place repeated photos on an A4 sheet at actual size.',
  };
  IconData get icon => switch (this) {
    Tool.photo => Icons.photo_size_select_large_outlined,
    Tool.signature => Icons.draw_outlined,
    Tool.merge => Icons.picture_as_pdf_outlined,
    Tool.scan => Icons.document_scanner_outlined,
    Tool.pack => Icons.inventory_2_outlined,
    Tool.print => Icons.print_outlined,
  };
  Color get color => switch (this) {
    Tool.merge => StudioTokens.pdf,
    Tool.scan => StudioTokens.scan,
    Tool.pack => StudioTokens.pack,
    _ => StudioTokens.photo,
  };
  String get synonyms => switch (this) {
    Tool.photo => 'smaller compress image picture passport resize crop',
    Tool.merge => 'merge join combine extract delete split reorder compress optimize pdf',
    Tool.scan => 'scan certificate pages document camera',
    Tool.signature => 'signature transparent background png',
    Tool.pack => 'application job documents bundle zip',
    Tool.print => 'print sheet copies paper',
  };
}

class StudioHome extends StatefulWidget {
  final VoidCallback onTheme;
  final void Function(BuildContext)? onSettings;
  const StudioHome({super.key, required this.onTheme, this.onSettings});
  @override
  State<StudioHome> createState() => _StudioHomeState();
}

class _StudioHomeState extends State<StudioHome> {
  Tool? selected;
  String search = '';
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final content = selected == null
        ? home()
        : ToolWorkspace(key: ValueKey(selected), tool: selected!);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Universal Studio'),
        actions: [
          if (widget.onSettings != null)
            IconButton(
              tooltip: 'Appearance and privacy',
              onPressed: () => widget.onSettings!(context),
              icon: const Icon(Icons.settings_outlined),
            ),
          IconButton(
            tooltip: 'Switch light or dark theme',
            onPressed: widget.onTheme,
            icon: const Icon(Icons.contrast),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              extended: true,
              minExtendedWidth: 232,
              selectedIndex: selected == null
                  ? 0
                  : Tool.values.indexOf(selected!) + 1,
              onDestinationSelected: (i) =>
                  setState(() => selected = i == 0 ? null : Tool.values[i - 1]),
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Icon(Icons.auto_awesome_mosaic_outlined, size: 32),
              ),
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  label: Text('Start here'),
                ),
                ...Tool.values.map(
                  (t) => NavigationRailDestination(
                    icon: Icon(t.icon),
                    label: Text(t.label),
                  ),
                ),
              ],
            ),
          Expanded(child: content),
        ],
      ),
      bottomNavigationBar: wide || selected == null
          ? null
          : SafeArea(
              child: TextButton.icon(
                onPressed: () => setState(() => selected = null),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Back to all tools'),
              ),
            ),
    );
  }

  Widget home() {
    final words = search
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where(
          (w) =>
              w.isNotEmpty &&
              !['make', 'my', 'a', 'the', 'to', 'file'].contains(w),
        );
    final tools = Tool.values
        .where(
          (t) => words.every(
            (w) => '${t.label} ${t.synonyms}'.toLowerCase().contains(w),
          ),
        )
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Chip(
                avatar: Icon(Icons.lock_outline, size: 18),
                label: Text('Private by design · Works offline'),
              ),
              const SizedBox(height: 20),
              Text(
                'Your documents.\nReady for what’s next.',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Prepare your photos, signatures, scans, and PDFs in one place—privately, offline, and with confidence.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              if (MediaQuery.sizeOf(context).width < 700)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [Tool.scan, Tool.photo, Tool.merge, Tool.pack]
                      .map(
                        (t) => OutlinedButton.icon(
                          onPressed: () => setState(() => selected = t),
                          icon: Icon(t.icon, size: 20),
                          label: Text(t.label),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 20),
              TextField(
                onChanged: (s) => setState(() => search = s),
                decoration: const InputDecoration(
                  labelText: 'What would you like to do?',
                  hintText: 'Try “make my photo smaller” or “merge”',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 28),
              if (tools.isEmpty)
                const Text(
                  'No matching tools. Try “photo”, “PDF”, “signature” or “application”.',
                ),
              LayoutBuilder(
                builder: (context, c) {
                  final cols = c.maxWidth > 760
                      ? 3
                      : c.maxWidth > 480
                      ? 2
                      : 1;
                  final width = (c.maxWidth - (cols - 1) * 16) / cols;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: tools
                        .map(
                          (t) => SizedBox(
                            width: width,
                            child: Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => setState(() => selected = t),
                                child: Padding(
                                  padding: const EdgeInsets.all(22),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        t.icon,
                                        size: 32,
                                        color:
                                            Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : t.color,
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        t.label,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(t.description),
                                      const SizedBox(height: 22),
                                      const Row(
                                        children: [
                                          Expanded(child: Text('Get started')),
                                          SizedBox(width: 12),
                                          Icon(Icons.arrow_forward, size: 20),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              const SizedBox(height: 28),
              const Text(
                'Your original files stay unchanged. No account, uploads or advertising. OCR is not included in this build.',
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class SelectedSource {
  final String name;
  final Uint8List bytes;
  String scanMode = 'original';
  int scanRotation = 0;
  double brightness = 0, contrast = 0;
  StudioOutput? scanAdjusted;
  SelectedSource(this.name, this.bytes);
}

class ToolWorkspace extends ConsumerStatefulWidget {
  final Tool tool;
  const ToolWorkspace({super.key, required this.tool});
  @override
  ConsumerState<ToolWorkspace> createState() => _ToolWorkspaceState();
}

class _ToolWorkspaceState extends ConsumerState<ToolWorkspace> {
  final width = TextEditingController(text: '300'),
      height = TextEditingController(text: '300'),
      limit = TextEditingController(text: '100'),
      pages = TextEditingController(),
      filename = TextEditingController(),
      copies = TextEditingController(text: '12');
  final form = GlobalKey<FormState>();
  List<SelectedSource> sources = [];
  StudioOutput? output;
  String? error, saved;
  bool busy = false,
      png = false,
      cover = false,
      flatten = false,
      showOriginal = false,
      optimizePdfStructures = false;
  int rotation = 0, quality = 60, threshold = 230;
  int previewIndex = 0, draftDays = 7;
  String? draftMessage;
  bool get imageTool =>
      widget.tool == Tool.photo || widget.tool == Tool.signature;
  @override
  void initState() {
    super.initState();
    if (widget.tool == Tool.signature) {
      png = true;
      height.text = '100';
    }
    if (widget.tool == Tool.print) {
      width.text = '30';
      height.text = '30';
    }
    filename.text = suggestedName;
  }

  String get suggestedName => switch (widget.tool) {
    Tool.photo => png ? 'photo.png' : 'photo.jpg',
    Tool.signature => 'signature.png',
    Tool.merge => optimizePdfStructures ? 'optimized.pdf' : 'combined.pdf',
    Tool.scan => 'scans.pdf',
    Tool.pack => 'application-pack.zip',
    Tool.print => 'print-sheet.pdf',
  };
  @override
  void dispose() {
    for (final c in [width, height, limit, pages, filename, copies]) {
      c.dispose();
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

  Future<void> select({int? slot}) async {
    try {
      final pdf =
          widget.tool == Tool.merge || (widget.tool == Tool.pack && slot == 2);
      final type = XTypeGroup(
        label: pdf ? 'PDF documents' : 'JPEG and PNG images',
        extensions: pdf ? ['pdf'] : ['jpg', 'jpeg', 'png'],
      );
      final files = (widget.tool == Tool.merge || widget.tool == Tool.scan)
          ? await openFiles(acceptedTypeGroups: [type])
          : [?await _one(type)];
      if (files.isEmpty) return;
      final incoming = <SelectedSource>[];
      int total =
          (widget.tool == Tool.merge ||
              widget.tool == Tool.scan ||
              widget.tool == Tool.pack)
          ? sources.fold(0, (n, s) => n + s.bytes.length)
          : 0;
      for (final f in files) {
        final size = await f.length();
        if (size > 64 * 1024 * 1024 || total + size > 64 * 1024 * 1024) {
          throw Exception('Select files totalling less than 64 MiB.');
        }
        final bytes = await f.readAsBytes();
        incoming.add(SelectedSource(f.name, bytes));
        total += bytes.length;
      }
      if (!mounted) return;
      setState(() {
        if (widget.tool == Tool.pack) {
          if (slot != sources.length) {
            throw Exception('Select the application documents in order.');
          }
          sources.add(incoming.first);
        } else if (widget.tool == Tool.merge || widget.tool == Tool.scan) {
          sources.addAll(incoming);
        } else {
          sources = incoming;
        }
        output = null;
        error = null;
        saved = null;
        previewIndex = 0;
      });
    } catch (e) {
      if (mounted) setState(() => error = clean(e));
    }
  }

  late final Future<bool> cameraAvailable = CameraCapture().available();

  Future<void> capturePage() async {
    if (sources.length >= 200) {
      setState(() => error = 'A scan session supports at most 200 pages.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final bytes = await CameraCapture().capture();
      if (bytes == null || !mounted) { return; }
      if (sources.fold<int>(0, (n, s) => n + s.bytes.length) + bytes.length > 64 * 1024 * 1024) {
        throw const FormatException('This session would exceed 64 MiB. Save this scan before capturing more pages.');
      }
      setState(() {
        sources.add(SelectedSource('Captured page ${sources.length + 1}.jpg', bytes));
        previewIndex = sources.length - 1;
        output = null;
        saved = null;
      });
    } on PlatformException catch (e) {
      if (mounted) { setState(() => error = e.message ?? 'Could not capture a page. Try importing an image.'); }
    } catch (e) {
      if (mounted) { setState(() => error = clean(e)); }
    } finally {
      if (mounted) { setState(() => busy = false); }
    }
  }

  Future<XFile?> _one(XTypeGroup type) => openFile(acceptedTypeGroups: [type]);
  String clean(Object e) => e.toString().replaceFirst('Exception: ', '');
  String? positive(String? s) {
    final n = int.tryParse(s ?? '');
    return n == null || n <= 0 ? 'Enter a positive whole number.' : null;
  }

  Future<void> process() async {
    if (!form.currentState!.validate()) return;
    if (sources.isEmpty) {
      setState(() => error = 'Choose a file to get started.');
      return;
    }
    if (widget.tool == Tool.pack && sources.length != 3) {
      setState(() => error = 'Choose a photo, signature and certificate.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
      saved = null;
      output = null;
    });
    try {
      final service = ref.read(studioServiceProvider);
      if (widget.tool == Tool.scan) {
        for (final source in sources) {
          source.scanAdjusted = await adjustScanPage(
            data: source.bytes,
            mode: source.scanMode,
            rotation: source.scanRotation,
            brightness: source.brightness.round(),
            contrast: source.contrast,
            threshold: 128,
          );
        }
      }
      final inputs = sources
          .map(
            (s) => widget.tool == Tool.scan
                ? (s.scanAdjusted?.bytes ?? s.bytes)
                : s.bytes,
          )
          .toList();
      final value = switch (widget.tool) {
        Tool.photo || Tool.signature => await service.photo(
          inputs.first,
          width: int.parse(width.text),
          height: int.parse(height.text),
          png: png,
          cover: cover,
          limit: limit.text.isEmpty ? null : int.parse(limit.text),
          quality: quality,
          flatten: flatten,
          rotation: rotation,
          threshold: widget.tool == Tool.signature ? threshold : null,
        ),
        Tool.merge => await service.merge(
          inputs,
          pages.text.trim().isEmpty
              ? null
              : pages.text.split(',').map((s) => int.parse(s.trim())).toList(),
          rotation * 90,
          optimize: optimizePdfStructures,
        ),
        Tool.scan => await service.scan(inputs),
        Tool.pack => await service.pack(inputs, int.parse(limit.text)),
        Tool.print => await service.printSheet(
          inputs.first,
          double.parse(width.text),
          double.parse(height.text),
          int.parse(copies.text),
        ),
      };
      if (mounted) setState(() => output = value);
    } catch (e) {
      if (mounted) setState(() => error = clean(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (output == null) return;
    try {
      if (!form.currentState!.validate()) return;
      final location = await ExportService.saveCopy(output!, filename.text);
      if (mounted && location != null) setState(() => saved = location);
    } catch (e) {
      if (mounted) setState(() => error = clean(e));
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.tool.label,
            style: Theme.of(
              context,
            ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(widget.tool.description),
          if (widget.tool == Tool.photo)
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RecipesScreen(),
                      ),
                    ),
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('Saved photo recipes'),
            ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, c) {
              final controls = controlPanel();
              final preview = previewPanel();
              return c.maxWidth >= 850
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 340, child: controls),
                        const SizedBox(width: 24),
                        Expanded(child: preview),
                      ],
                    )
                  : Column(
                      children: [controls, const SizedBox(height: 20), preview],
                    );
            },
          ),
        ],
      ),
    ),
  );
  Widget controlPanel() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '1  Select',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (widget.tool == Tool.pack) ...[
            const Text(
              'Example requirements, not official rules: photo 300 × 300; signature 300 × 100; certificate 1–200 pages.',
            ),
            const SizedBox(height: 12),
            ...List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: busy || sources.length != i
                      ? null
                      : () => select(slot: i),
                  icon: Icon(
                    sources.length > i ? Icons.check_circle_outline : Icons.add,
                  ),
                  label: Text(
                    [
                      'Choose photo',
                      'Choose signature',
                      'Choose certificate PDF',
                    ][i],
                  ),
                ),
              ),
            ),
          ] else
            OutlinedButton.icon(
              onPressed: busy ? null : select,
              icon: const Icon(Icons.add),
              label: Text(
                widget.tool == Tool.merge
                    ? 'Add PDF files'
                    : widget.tool == Tool.scan
                    ? 'Add page images'
                    : 'Choose image',
              ),
            ),
          if (widget.tool == Tool.scan && Platform.isAndroid)
            FutureBuilder<bool>(
              future: cameraAvailable,
              builder: (context, snapshot) => snapshot.data == true
                ? FilledButton.icon(onPressed: busy ? null : capturePage, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Capture a page'))
                : const Text('Import page images if a camera app is unavailable.'),
            ),
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...sources.asMap().entries.map(
              (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  e.value.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${(e.value.bytes.length / 1024).toStringAsFixed(1)} KiB',
                ),
                onTap: () => setState(() => previewIndex = e.key),
                trailing: widget.tool == Tool.pack
                    ? null
                    : Wrap(
                        children: [
                          if (e.key > 0)
                            IconButton(
                              tooltip: 'Move page up',
                              onPressed: busy
                                  ? null
                                  : () {
                                      setState(() {
                                        final item = sources.removeAt(e.key);
                                        sources.insert(e.key - 1, item);
                                        output = null;
                                      });
                                    },
                              icon: const Icon(Icons.arrow_upward),
                            ),
                          IconButton(
                            tooltip: 'Remove file',
                            onPressed: busy
                                ? null
                                : () {
                                    setState(() {
                                      sources.removeAt(e.key);
                                      previewIndex = 0;
                                      output = null;
                                    });
                                  },
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () {
                      setState(() {
                        sources = [];
                        output = null;
                        saved = null;
                      });
                    },
              child: const Text('Clear selection'),
            ),
          ],
          const Divider(height: 32),
          const Text(
            '2  Adjust',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (imageTool || widget.tool == Tool.print) ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: width,
                    enabled: !busy,
                    validator: positive,
                    onChanged: (_) => changed(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: widget.tool == Tool.print
                          ? 'Width (mm)'
                          : 'Width (pixels)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: height,
                    enabled: !busy,
                    validator: positive,
                    onChanged: (_) => changed(),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: widget.tool == Tool.print
                          ? 'Height (mm)'
                          : 'Height (pixels)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (imageTool || widget.tool == Tool.pack) ...[
            TextFormField(
              controller: limit,
              enabled: !busy,
              validator: (s) =>
                  s!.isEmpty && widget.tool != Tool.pack ? null : positive(s),
              onChanged: (_) => changed(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Maximum file size (KiB)',
                helperText: 'Strictly below this limit. 1 KiB = 1024 bytes.',
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (imageTool) ...[
            if (widget.tool == Tool.photo)
              DropdownButtonFormField<bool>(
                initialValue: png,
                decoration: const InputDecoration(labelText: 'Save format'),
                items: const [
                  DropdownMenuItem(value: false, child: Text('JPEG')),
                  DropdownMenuItem(value: true, child: Text('PNG')),
                ],
                onChanged: busy
                    ? null
                    : (v) {
                        setState(() {
                          png = v!;
                          output = null;
                          filename.text = suggestedName;
                        });
                      },
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fill and crop edges'),
              subtitle: const Text('Off: fit whole image with padding.'),
              value: cover,
              onChanged: busy
                  ? null
                  : (v) {
                      setState(() => cover = v);
                      changed();
                    },
            ),
            if (widget.tool == Tool.signature) ...[
              Text('Background removal: $threshold'),
              Slider(
                value: threshold.toDouble(),
                min: 100,
                max: 254,
                divisions: 154,
                label: '$threshold',
                onChanged: busy
                    ? null
                    : (v) {
                        setState(() => threshold = v.round());
                        changed();
                      },
              ),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('More options'),
              children: [
                if (!png) ...[
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
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Allow a white background for transparency',
                    ),
                    value: flatten,
                    onChanged: busy
                        ? null
                        : (v) {
                            setState(() => flatten = v!);
                            changed();
                          },
                  ),
                ],
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          setState(() => rotation = (rotation + 1) % 4);
                          changed();
                        },
                  icon: const Icon(Icons.rotate_right),
                  label: Text('Rotate: ${rotation * 90}°'),
                ),
              ],
            ),
          ],
          if (widget.tool == Tool.merge) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Try lossless optimization'),
              subtitle: const Text('Keep text and image quality. Never rasterizes. Some PDFs cannot become smaller.'),
              value: optimizePdfStructures,
              onChanged: busy ? null : (value) {
                setState(() {
                  final previousName = suggestedName;
                  optimizePdfStructures = value ?? false;
                  if (filename.text == previousName) filename.text = suggestedName;
                });
                changed();
              },
            ),
            TextFormField(
              controller: pages,
              enabled: !busy,
              onChanged: (_) => changed(),
              validator: (s) =>
                  s!.isEmpty ||
                      s.split(',').every((n) => int.tryParse(n.trim()) != null)
                  ? null
                  : 'Enter page numbers separated by commas.',
              decoration: const InputDecoration(
                labelText: 'Pages to keep, in order',
                hintText: 'Example: 3,1,2',
                helperText: 'Leave empty to keep every page.',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () {
                      setState(() => rotation = (rotation + 1) % 4);
                      changed();
                    },
              icon: const Icon(Icons.rotate_right),
              label: Text('Rotate all pages: ${rotation * 90}°'),
            ),
            const SizedBox(height: 8),
            const Text(
              'PDFs with forms, annotations, bookmarks, attachments or signatures are not supported yet.',
            ),
          ],
          if (widget.tool == Tool.scan) ...[
            const Text(
              'Import page images, choose a page below its filename, adjust, then prepare the PDF. On Android, you can also capture pages with the device camera app. Save a draft before capturing to protect against Android closing the app. Perspective correction is still pending.',
            ),
            ExpansionTile(title: const Text('Save or restore a scan draft'), children: [
              const Text('Save original page copies and adjustments on this device. Nothing is uploaded. Expired drafts are removed when the draft list is opened.'),
              DropdownButtonFormField<int>(initialValue:draftDays, decoration:const InputDecoration(labelText:'Keep draft for'), items:[for(final days in [1,7,30,90])DropdownMenuItem(value:days,child:Text('$days days'))],onChanged:busy?null:(value)=>setState(()=>draftDays=value!)),
              Wrap(spacing:12,children:[
                OutlinedButton(onPressed:busy||sources.isEmpty?null:saveDraft,child:const Text('Save draft on this device')),
                OutlinedButton(onPressed:busy?null:restoreDraft,child:const Text('Restore saved draft')),
              ]),
              if(draftMessage!=null)Semantics(liveRegion:true,child:Text(draftMessage!)),
            ]),
            if (sources.isNotEmpty) scanControls(),
          ],
          if (widget.tool == Tool.print) ...[
            TextFormField(
              controller: copies,
              enabled: !busy,
              validator: positive,
              onChanged: (_) => changed(),
              decoration: const InputDecoration(labelText: 'Number of copies'),
            ),
            const SizedBox(height: 8),
            const Text(
              'A4 paper · 12 mm margins · 4 mm spacing. Crop your photo to the same aspect ratio first. Print at Actual size / 100%, not Fit to page.',
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: busy ? null : process,
            icon: busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high_outlined),
            label: Text(busy ? 'Preparing locally…' : 'Prepare preview'),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Please wait. This version finishes the current operation before you can edit again.',
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  'Couldn’t prepare your document. $error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  Widget previewPanel() => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '3  Preview',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              if (imageTool && output != null)
                TextButton(
                  onPressed: () => setState(() => showOriginal = !showOriginal),
                  child: Text(showOriginal ? 'Show result' : 'Show original'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            constraints: const BoxConstraints(minHeight: 300),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: previewContent(),
          ),
          if (output != null) ...[
            const SizedBox(height: 20),
            Semantics(
              liveRegion: true,
              child: Text(
                '✓ ${(output!.bytes.length / 1024).toStringAsFixed(2)} KiB · ${output!.format.toUpperCase()}${output!.width != null ? ' · ${output!.width} × ${output!.height} pixels' : ''}${output!.pages != null ? ' · ${output!.pages} pages' : ''}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Text(output!.validation),
            const Divider(height: 32),
            const Text(
              '4  Save a copy',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: filename,
              validator: (s) =>
                  s == null || s.trim().isEmpty ? 'Enter a filename.' : null,
              decoration: const InputDecoration(labelText: 'Filename'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : save,
              icon: const Icon(Icons.save_alt),
              label: const Text('Choose location and save a copy'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your original file is unchanged. Existing files are never overwritten.',
            ),
            if (saved != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Semantics(
                  liveRegion: true,
                  child: SelectableText('✓ Saved and verified\n$saved'),
                ),
              ),
          ],
        ],
      ),
    ),
  );
  Future<void> saveDraft() async {
    final directory=ref.read(dataDirectoryProvider);
    if(directory==null){setState(()=>draftMessage='Local draft storage is unavailable.');return;}
    final snapshot=sources.map((s)=>DraftPage(s.name,s.bytes,mode:s.scanMode,rotation:s.scanRotation,brightness:s.brightness,contrast:s.contrast)).toList();
    setState(()=>busy=true);
    try {
      await ScanDrafts(directory).save(snapshot,draftDays);
      if(mounted) { setState(()=>draftMessage='Draft saved on this device for $draftDays days. Your original files are unchanged.'); }
    } catch(_){if(mounted) { setState(()=>draftMessage='Could not save the draft. Check free space and storage access.'); }}
    finally{if(mounted) { setState(()=>busy=false); }}
  }
  Future<void> restoreDraft() async {
    final directory=ref.read(dataDirectoryProvider);
    if(directory==null){setState(()=>draftMessage='Local draft storage is unavailable.');return;}
    final store=ScanDrafts(directory);
    final id=await showDialog<String>(context:context,builder:(context)=>ScanDraftPicker(store:store));
    if(id==null||!mounted) { return; }
    if(sources.isNotEmpty){
      final replace=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('Replace the current scan session?'),content:const Text('Save a draft first if you want to keep your current page order and adjustments. Original files will stay unchanged.'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Keep current scan')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Restore draft'))]));
      if(replace!=true||!mounted) { return; }
    }
    setState(()=>busy=true);
    try {
      final restored=await store.restore(id);
      final incoming=restored.map((p)=>SelectedSource(p.name,p.bytes)..scanMode=p.mode..scanRotation=p.rotation..brightness=p.brightness..contrast=p.contrast).toList();
      if(mounted) { setState((){sources=incoming;previewIndex=0;output=null;error=null;saved=null;draftMessage='Restored ${incoming.length} pages. The saved draft is still available.';}); }
    } catch(_){if(mounted) { setState(()=>draftMessage='Could not restore this draft. It may be expired, damaged or unavailable. Your current scan is unchanged.'); }}
    finally{if(mounted) { setState(()=>busy=false); }}
  }

  Widget scanControls() {
    final source = sources[previewIndex.clamp(0, sources.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text('Editing page ${previewIndex + 1}: ${source.name}'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('${source.name}-$previewIndex-${source.scanMode}'),
          initialValue: source.scanMode,
          decoration: const InputDecoration(labelText: 'Page appearance'),
          items: const [
            DropdownMenuItem(value: 'original', child: Text('Original')),
            DropdownMenuItem(value: 'colour', child: Text('Colour enhanced')),
            DropdownMenuItem(value: 'grayscale', child: Text('Grayscale')),
            DropdownMenuItem(
              value: 'black_white',
              child: Text('Black and white'),
            ),
          ],
          onChanged: busy
              ? null
              : (v) {
                  setState(() => source.scanMode = v!);
                  changed();
                },
        ),
        Text('Brightness: ${source.brightness.round()}'),
        Slider(
          value: source.brightness,
          min: -100,
          max: 100,
          divisions: 200,
          onChanged: busy
              ? null
              : (v) {
                  setState(() => source.brightness = v);
                  changed();
                },
        ),
        Text('Contrast: ${source.contrast.round()}'),
        Slider(
          value: source.contrast,
          min: -100,
          max: 100,
          divisions: 200,
          onChanged: busy
              ? null
              : (v) {
                  setState(() => source.contrast = v);
                  changed();
                },
        ),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () {
                  setState(
                    () => source.scanRotation = (source.scanRotation + 1) % 4,
                  );
                  changed();
                },
          icon: const Icon(Icons.rotate_right),
          label: Text('Rotate: ${source.scanRotation * 90}°'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    final adjusted = await adjustScanPage(
                      data: source.bytes,
                      mode: source.scanMode,
                      rotation: source.scanRotation,
                      brightness: source.brightness.round(),
                      contrast: source.contrast,
                      threshold: 128,
                    );
                    if (mounted) {
                      setState(() {
                        source.scanAdjusted = adjusted;
                        output = null;
                        error = null;
                      });
                    }
                  } catch (e) {
                    if (mounted) setState(() => error = clean(e));
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: const Text('Apply page adjustments'),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () {
                  setState(() {
                    source.scanAdjusted = null;
                    source.scanMode = 'original';
                    source.scanRotation = 0;
                    source.brightness = 0;
                    source.contrast = 0;
                    output = null;
                  });
                },
          child: const Text('Reset this page to original'),
        ),
        if (source.scanAdjusted != null) Text(source.scanAdjusted!.validation),
      ],
    );
  }

  Widget previewContent() {
    if (output?.format == 'pdf') {
      return PdfPreview(data: output!.bytes, pageCount: output!.pages);
    }
    if (widget.tool == Tool.merge && sources.isNotEmpty) {
      return PdfPreview(
        data: sources[previewIndex.clamp(0, sources.length - 1)].bytes,
      );
    }
    if (imageTool && output != null && !showOriginal) {
      if (output!.format == 'png') {
        return TransparencyPreview(bytes: Uint8List.fromList(output!.bytes));
      }
      return Image.memory(
        Uint8List.fromList(output!.bytes),
        height: 360,
        fit: BoxFit.contain,
        semanticLabel: 'Prepared output preview',
      );
    }
    if (sources.isNotEmpty &&
        widget.tool != Tool.merge &&
        widget.tool != Tool.pack) {
      return Image.memory(
        (widget.tool == Tool.scan
                ? sources[previewIndex.clamp(0, sources.length - 1)]
                      .scanAdjusted
                      ?.bytes
                : null) ??
            sources[previewIndex.clamp(0, sources.length - 1)].bytes,
        height: 360,
        fit: BoxFit.contain,
        semanticLabel: 'Selected source image',
        errorBuilder: (_, e, s) => const Text(
          'Image preview unavailable. The processing engine will validate this file.',
        ),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          output == null ? widget.tool.icon : Icons.task_alt,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          output == null ? 'Your document will appear here' : 'Output prepared',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(
          output == null
              ? 'Select a file, adjust what you need, then prepare a preview.'
              : output!.format == 'pdf'
              ? 'The PDF preview is shown above.'
              : 'Archive entries and manifest verified.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
