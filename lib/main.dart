import 'application/custom_pack.dart';
import 'application/prepared_documents.dart';
import 'application/scan_corner_editor.dart';
import 'src/rust/vision.dart';
import 'application/print_layout_controls.dart';
import 'application/camera_capture.dart';
import 'application/recognized_text.dart';

import 'package:flutter/services.dart';

import 'application/scan_drafts.dart';
import 'application/scan_draft_picker.dart';
import 'application/safe_image_preview.dart';
import 'src/rust/scanner.dart';

import 'dart:io';

import 'application/recipes.dart';
import 'application/saved_copy_actions.dart';

import 'package:path_provider/path_provider.dart';

import 'application/pdf_preview.dart';
import 'application/pdf_text.dart';
import 'application/pdf_overlay_controls.dart';
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
          storageNotice = 'Portable mode: settings are saved in studio-data beside the application.';
        } catch (_) {
          storageNotice = 'Portable storage is not writable. Settings are saved in your local application-support folder instead.';
        }
      }
      initialTheme = (await loadPreferences(directory: storage!)).theme;
    } catch (_) {
      storage = null;
      storageNotice = 'Settings could not be saved on this device. Changes apply only to this session.';
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
    Tool.merge => 'Combine, arrange, number, and watermark supported PDFs.',
    Tool.scan => 'Turn imported page images into one organised PDF.',
    Tool.pack => 'Prepare a photo, signature and certificate together.',
    Tool.print => 'Arrange photo copies for actual-size printing.',
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
  Color accent(Brightness brightness) => brightness == Brightness.light
      ? color
      : switch (this) {
          Tool.merge => StudioTokens.darkPdf,
          Tool.scan => StudioTokens.darkScan,
          Tool.pack => StudioTokens.darkPack,
          _ => StudioTokens.darkPhoto,
        };
  String get synonyms => switch (this) {
    Tool.photo => 'smaller compress image picture passport resize crop flexible dimensions recipe batch',
    Tool.merge => 'merge join combine extract delete split reorder compress optimize pdf watermark page numbers number text extract selectable',
    Tool.scan => 'scan certificate pages document camera corners perspective straighten tilted deskew ocr text recognize printed english bangla',
    Tool.signature => 'signature transparent background png',
    Tool.pack => 'application job documents bundle zip',
    Tool.print => 'print sheet printing copies paper a4 letter dpi',
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
                                        color: t.accent(
                                          Theme.of(context).brightness,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Text(
                                        t.label,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
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
                'Your original files stay unchanged. No account, uploads or advertising. Processing stays on this device.',
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
  PageCorners? corners;
  String scanMode = 'original';
  int scanRotation = 0;
  double brightness = 0, contrast = 0;
  ScanOptions get scanOptions => scanSettings(
    mode: scanMode,
    corners: corners,
    rotation: scanRotation,
    brightness: brightness.round(),
    contrast: contrast,
  );
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
      copies = TextEditingController(text: '12'),
      widthMm = TextEditingController(text: '35'),
      heightMm = TextEditingController(text: '45'),
      dpi = TextEditingController(text: '300'),
      paperWidth = TextEditingController(text: '210'),
      paperHeight = TextEditingController(text: '297'),
      printMargin = TextEditingController(text: '12'),
      printSpacing = TextEditingController(text: '4'),
      watermarkText = TextEditingController(text: 'DRAFT'),
      watermarkFont = TextEditingController(text: '32');
  final printAdvanced = ExpansibleController();
  final pdfAdvanced = ExpansibleController();
  bool pageNumbers = false, watermarkEnabled = false;
  String printPaper = 'a4';
  bool cuttingGuides = false, printResample = false;
  final form = GlobalKey<FormState>();
  List<SelectedSource> sources = [];
  StudioOutput? output;
  String? error, saved, saveError;
  bool busy = false,
      png = false,
      cover = false,
      flatten = false,
      showOriginal = false,
      optimizePdfStructures = false,
      physicalSize = false;
  int rotation = 0, quality = 60, threshold = 230;
  int previewIndex = 0, draftDays = 7;
  String? draftMessage;
  Future<bool>? textRecognitionAvailable, geometryAvailable;
  bool get imageTool =>
      widget.tool == Tool.photo || widget.tool == Tool.signature;
  @override
  void initState() {
    super.initState();
    if (widget.tool == Tool.signature) {
      png = true;
      height.text = '100';
      widthMm.text = '50';
      heightMm.text = '15';
    }
    if (widget.tool == Tool.print) {
      width.text = '30';
      height.text = '30';
    }
    filename.text = suggestedName;
    if (widget.tool == Tool.scan) {
      textRecognitionAvailable = ocrAvailable().catchError((_) => false);
      geometryAvailable = scanGeometryAvailable().catchError((_) => false);
    }
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
    for (final c in [
      width,
      height,
      limit,
      pages,
      filename,
      copies,
      widthMm,
      heightMm,
      dpi,
      paperWidth,
      paperHeight,
      printMargin,
      printSpacing,
      watermarkText,
      watermarkFont,
    ]) {
      c.dispose();
    }
    printAdvanced.dispose();
    pdfAdvanced.dispose();
    super.dispose();
  }

  void changed() {
    setState(() {
      output = null;
      saved = null;
      saveError = null;
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
      if (widget.tool == Tool.scan && sources.length + files.length > 200) {
        throw const FormatException(
          'A scan session supports at most 200 pages.',
        );
      }
      final incoming = <SelectedSource>[];
      int total =
          (widget.tool == Tool.merge ||
              widget.tool == Tool.scan ||
              widget.tool == Tool.pack)
          ? sources.fold(0, (n, s) => n + s.bytes.length)
          : 0;
      if (widget.tool == Tool.pack && slot != null && slot < sources.length) {
        total -= sources[slot].bytes.length;
      }
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
          if (slot == null || slot < 0 || slot > sources.length || slot >= 3) {
            throw const FormatException(
              'Choose a document slot to add or replace.',
            );
          }
          if (slot == sources.length) {
            sources.add(incoming.first);
          } else {
            sources[slot] = incoming.first;
          }
        } else if (widget.tool == Tool.merge || widget.tool == Tool.scan) {
          sources.addAll(incoming);
        } else {
          sources = incoming;
        }
        output = null;
        error = null;
        saved = null;
        saveError = null;
        previewIndex = widget.tool == Tool.pack ? slot! : 0;
      });
    } catch (e) {
      if (mounted) setState(() => error = clean(e));
    }
  }

  Future<void> selectPrepared(int slot) async {
    final documents = ref.read(preparedDocumentsProvider);
    final pdf = slot == 2;
    final candidates = documents
        .where(
          (item) => pdf
              ? item.format == 'pdf'
              : ['jpeg', 'png'].contains(item.format),
        )
        .toList();
    final selected = await showDialog<PreparedDocument>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use a session document'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'These copies stay in memory until removed or the app closes.',
                ),
                if (candidates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Prepare an image or PDF in another studio, then choose Keep for application pack.',
                    ),
                  ),
                for (final item in candidates)
                  ListTile(
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.format.toUpperCase()} · ${item.byteCount} bytes',
                    ),
                    onTap: () => Navigator.pop(context, item),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    final total = sources.asMap().entries.fold<int>(
      0,
      (n, entry) => n + (entry.key == slot ? 0 : entry.value.bytes.length),
    );
    if (total + selected.byteCount > PreparedDocuments.maximumBytes) {
      setState(() => error = 'Select files totalling less than 64 MiB.');
      return;
    }
    setState(() {
      final source = SelectedSource(selected.name, selected.bytes);
      if (slot == sources.length) {
        sources.add(source);
      } else {
        sources[slot] = source;
      }
      output = null;
      saved = null;
      saveError = null;
      error = null;
      previewIndex = slot;
    });
  }

  late final Future<bool> cameraAvailable = CameraCapture().available();

  Future<void> capturePage() async {
    if (sources.length >= 200) {
      setState(() => error = 'A scan session supports at most 200 pages.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final bytes = await CameraCapture().capture();
      if (bytes == null || !mounted) {
        return;
      }
      if (sources.fold<int>(0, (n, s) => n + s.bytes.length) + bytes.length >
          64 * 1024 * 1024) {
        throw const FormatException(
          'This session would exceed 64 MiB. Save this scan before capturing more pages.',
        );
      }
      setState(() {
        sources.add(
          SelectedSource('Captured page ${sources.length + 1}.jpg', bytes),
        );
        previewIndex = sources.length - 1;
        output = null;
        saved = null;
        saveError = null;
      });
    } on PlatformException catch (e) {
      if (mounted) {
        setState(
          () => error =
              e.message ?? 'Could not capture a page. Try importing an image.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = clean(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<XFile?> _one(XTypeGroup type) => openFile(acceptedTypeGroups: [type]);
  String clean(Object e) => e.toString().replaceFirst('Exception: ', '');
  String? positive(String? s) {
    final n = int.tryParse(s ?? '');
    return n == null || n <= 0 ? 'Enter a positive whole number.' : null;
  }

  String? positiveDecimal(String? value) {
    final number = double.tryParse(value ?? '');
    return number == null || !number.isFinite || number <= 0
        ? 'Enter a positive number using a decimal point if needed.'
        : null;
  }

  Future<StudioOutput> preparePhoto(StudioService service, Uint8List input) {
    if (physicalSize) {
      return service.physicalPhoto(
        input,
        widthMm: double.parse(widthMm.text),
        heightMm: double.parse(heightMm.text),
        dpi: int.parse(dpi.text),
        png: png,
        cover: cover,
        limit: limit.text.isEmpty ? null : int.parse(limit.text),
        quality: quality,
        flatten: flatten,
        rotation: rotation,
        threshold: widget.tool == Tool.signature ? threshold : null,
      );
    }
    return service.photo(
      input,
      width: int.parse(width.text),
      height: int.parse(height.text),
      png: png,
      cover: cover,
      limit: limit.text.isEmpty ? null : int.parse(limit.text),
      quality: quality,
      flatten: flatten,
      rotation: rotation,
      threshold: widget.tool == Tool.signature ? threshold : null,
    );
  }

  Future<void> process() async {
    if (!form.currentState!.validate()) {
      if (widget.tool == Tool.print) {
        printAdvanced.expand();
        setState(() => error = 'Check the highlighted print settings.');
      }
      if (widget.tool == Tool.merge) {
        pdfAdvanced.expand();
        setState(() => error = 'Check the highlighted PDF settings.');
      }
      return;
    }
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
      saveError = null;
      output = null;
    });
    try {
      final service = ref.read(studioServiceProvider);
      final inputs = sources.map((source) => source.bytes).toList();
      final value = switch (widget.tool) {
        Tool.photo ||
        Tool.signature => await preparePhoto(service, inputs.first),
        Tool.merge => await service.merge(
          inputs,
          pages.text.trim().isEmpty
              ? null
              : pages.text.split(',').map((s) => int.parse(s.trim())).toList(),
          rotation * 90,
          optimize: optimizePdfStructures,
          pageNumbers: pageNumbers,
          watermark: watermarkEnabled ? watermarkText.text : null,
          watermarkFontPoints: watermarkEnabled
              ? double.parse(watermarkFont.text)
              : 32,
        ),
        Tool.scan => await service.scan(
          sources
              .map(
                (source) =>
                    ScanPage(data: source.bytes, options: source.scanOptions),
              )
              .toList(),
        ),
        Tool.pack => await service.pack(inputs, int.parse(limit.text)),
        Tool.print => await service.printSheet(
          inputs.first,
          double.parse(width.text),
          double.parse(height.text),
          int.parse(copies.text),
          paperWidth: double.parse(paperWidth.text),
          paperHeight: double.parse(paperHeight.text),
          margin: double.parse(printMargin.text),
          spacing: double.parse(printSpacing.text),
          guides: cuttingGuides,
          rasterDpi: printResample ? int.parse(dpi.text) : null,
        ),
      };
      if (mounted) setState(() => output = value);
    } catch (e) {
      if (mounted) setState(() => error = clean(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> readSelectedPage() async {
    if (busy || sources.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final source = sources[previewIndex.clamp(0, sources.length - 1)];
      final adjusted = await adjustScanPage(
        data: source.bytes,
        mode: source.scanMode,
        rotation: source.scanRotation,
        brightness: source.brightness.round(),
        contrast: source.contrast,
        threshold: 128,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => RecognizedTextScreen(page: adjusted.bytes),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = clean(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (output == null || busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      saveError = null;
    });
    try {
      final location = await ExportService.saveCopy(output!, filename.text);
      if (mounted && location != null) setState(() => saved = location);
    } catch (e) {
      if (mounted) setState(() => saveError = clean(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.keyO, control: true): () {
        if (!busy && (widget.tool != Tool.pack || sources.length < 3)) {
          select(slot: widget.tool == Tool.pack ? sources.length : null);
        }
      },
      const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
        if (!busy) process();
      },
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
        if (!busy && output != null) save();
      },
    },
    child: Focus(autofocus: true, child: workspaceContent()),
  );

  Widget workspaceContent() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.tool.label,
            style: Theme.of(context).textTheme.headlineLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(widget.tool.description),
          if (Platform.isWindows || Platform.isLinux)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Keyboard: Ctrl+O choose files · Ctrl+Enter preview · Ctrl+S save a copy.',
              ),
            ),
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
              label: const Text('Photo recipes'),
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
          if (widget.tool == Tool.photo && sources.isNotEmpty)
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => RecipesScreen(
                          initialSource: sources.first.bytes,
                          initialSourceName: sources.first.name,
                          openCrop: true,
                        ),
                      ),
                    ),
              icon: const Icon(Icons.crop),
              label: const Text('Crop and resize'),
            ),
          if (widget.tool == Tool.pack) ...[
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => const CustomPackScreen(),
                      ),
                    ),
              icon: const Icon(Icons.tune),
              label: const Text('Create a custom application pack'),
            ),
            const Text(
              'Example requirements, not official rules: photo 300 × 300; signature 300 × 100; certificate 1–200 pages.',
            ),
            const SizedBox(height: 12),
            ...List.generate(
              3,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton.icon(
                  onPressed: busy || sources.length < i
                      ? null
                      : () => select(slot: i),
                  icon: Icon(
                    sources.length > i ? Icons.check_circle_outline : Icons.add,
                  ),
                  label: Text(
                    sources.length > i
                        ? [
                            'Replace photo',
                            'Replace signature',
                            'Replace certificate PDF',
                          ][i]
                        : [
                            'Choose photo',
                            'Choose signature',
                            'Choose certificate PDF',
                          ][i],
                  ),
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < 3; i++)
                  TextButton.icon(
                    onPressed: busy || sources.length < i
                        ? null
                        : () => selectPrepared(i),
                    icon: const Icon(Icons.folder_copy_outlined),
                    label: Text(
                      'Use prepared ${['photo', 'signature', 'PDF'][i]}',
                    ),
                  ),
              ],
            ),
            if (ref.watch(preparedDocumentsProvider).isNotEmpty)
              ExpansionTile(
                title: Text(
                  'Session documents (${ref.watch(preparedDocumentsProvider).length})',
                ),
                children: [
                  for (final item in ref.watch(preparedDocumentsProvider))
                    ListTile(
                      title: Text(item.name),
                      subtitle: Text('${item.byteCount} bytes'),
                      trailing: IconButton(
                        tooltip: 'Remove ${item.name} from session',
                        onPressed: busy
                            ? null
                            : () => ref
                                  .read(preparedDocumentsProvider.notifier)
                                  .remove(item.id),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => ref
                              .read(preparedDocumentsProvider.notifier)
                              .clear(),
                    child: const Text('Clear all session documents'),
                  ),
                ],
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
                  ? FilledButton.icon(
                      onPressed: busy ? null : capturePage,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Capture a page'),
                    )
                  : const Text(
                      'Import page images if a camera app is unavailable.',
                    ),
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
                  '${widget.tool == Tool.pack ? '${['Photo', 'Signature', 'Certificate'][e.key]} · ' : ''}${(e.value.bytes.length / 1024).toStringAsFixed(1)} KiB',
                ),
                selected: previewIndex == e.key,
                leading: Text(
                  '${e.key + 1}',
                  semanticsLabel:
                      '${widget.tool == Tool.scan ? 'Page' : 'File'} ${e.key + 1}',
                ),
                onTap: busy ? null : () => setState(() => previewIndex = e.key),
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
                                        final selected =
                                            sources[previewIndex.clamp(
                                              0,
                                              sources.length - 1,
                                            )];
                                        final item = sources.removeAt(e.key);
                                        sources.insert(e.key - 1, item);
                                        previewIndex = sources.indexOf(
                                          selected,
                                        );
                                        output = null;
                                        saved = null;
                                        saveError = null;
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
                                      final selected =
                                          sources[previewIndex.clamp(
                                            0,
                                            sources.length - 1,
                                          )];
                                      sources.removeAt(e.key);
                                      final retained = sources.indexOf(
                                        selected,
                                      );
                                      previewIndex = retained >= 0
                                          ? retained
                                          : (e.key - 1).clamp(
                                              0,
                                              sources.isNotEmpty
                                                  ? sources.length - 1
                                                  : 0,
                                            );
                                      output = null;
                                      saved = null;
                                      saveError = null;
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
                        saveError = null;
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
          if (imageTool)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Set a print size in millimetres'),
              subtitle: const Text(
                'Off: set pixel dimensions. Originals stay unchanged.',
              ),
              value: physicalSize,
              onChanged: busy
                  ? null
                  : (value) {
                      setState(() => physicalSize = value);
                      changed();
                    },
            ),
          if (imageTool || widget.tool == Tool.print) ...[
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: imageTool && physicalSize ? widthMm : width,
                    enabled: !busy,
                    validator: physicalSize || widget.tool == Tool.print
                        ? positiveDecimal
                        : positive,
                    onChanged: (_) => changed(),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: physicalSize || widget.tool == Tool.print,
                    ),
                    decoration: InputDecoration(
                      labelText: widget.tool == Tool.print || physicalSize
                          ? 'Width (mm)'
                          : 'Width (pixels)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: imageTool && physicalSize ? heightMm : height,
                    enabled: !busy,
                    validator: physicalSize || widget.tool == Tool.print
                        ? positiveDecimal
                        : positive,
                    onChanged: (_) => changed(),
                    keyboardType: TextInputType.numberWithOptions(
                      decimal: physicalSize || widget.tool == Tool.print,
                    ),
                    decoration: InputDecoration(
                      labelText: widget.tool == Tool.print || physicalSize
                          ? 'Height (mm)'
                          : 'Height (pixels)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (imageTool && physicalSize) ...[
            TextFormField(
              controller: dpi,
              enabled: !busy,
              keyboardType: TextInputType.number,
              validator: (value) {
                final number = int.tryParse(value ?? '');
                return number == null || number < 1 || number > 2400
                    ? 'Use 1–2400 DPI.'
                    : null;
              },
              onChanged: (_) => changed(),
              decoration: const InputDecoration(
                labelText: 'Print resolution (DPI)',
                helperText: 'Dots per inch. Saved dimensions are rounded to whole pixels.',
                helperMaxLines: 3,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'The file keeps your chosen print resolution while personal metadata is removed. The preview reports the saved physical size. Check the required dimensions before saving.',
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
              subtitle: const Text(
                'Keep text and image quality. Never rasterizes. Some PDFs cannot become smaller.',
              ),
              value: optimizePdfStructures,
              onChanged: busy
                  ? null
                  : (value) {
                      setState(() {
                        final previousName = suggestedName;
                        optimizePdfStructures = value ?? false;
                        if (filename.text == previousName) {
                          filename.text = suggestedName;
                        }
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
            OutlinedButton.icon(
              onPressed: busy || sources.isEmpty
                  ? null
                  : () {
                      final data = output?.format == 'pdf'
                          ? output!.bytes
                          : sources[previewIndex.clamp(0, sources.length - 1)]
                                .bytes;
                      Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => PdfTextScreen(source: data),
                        ),
                      );
                    },
              icon: const Icon(Icons.text_snippet_outlined),
              label: const Text('Read selectable text'),
            ),
            const Text(
              'Reads the prepared PDF when available; otherwise reads the selected source PDF. Scans may have no selectable text.',
            ),
            const SizedBox(height: 8),
            PdfOverlayControls(
              enabled: !busy,
              pageNumbers: pageNumbers,
              watermarkEnabled: watermarkEnabled,
              watermark: watermarkText,
              fontSize: watermarkFont,
              advanced: pdfAdvanced,
              onPageNumbers: (value) {
                setState(() => pageNumbers = value);
                changed();
              },
              onWatermark: (value) {
                setState(() => watermarkEnabled = value);
                changed();
              },
              onChanged: changed,
            ),
            const Text(
              'PDFs with forms, annotations, bookmarks, attachments or signatures are not supported yet.',
            ),
          ],
          if (widget.tool == Tool.scan) ...[
            const Text(
              'Import page images, select a page by its filename, adjust it, then prepare the PDF. On Android, you can also capture pages with the device camera app. Save a draft before capturing to protect against Android closing the app. Perspective correction is still pending.',
            ),
            ExpansionTile(
              title: const Text('Save or restore a scan draft'),
              children: [
                const Text(
                  'Save original page copies and adjustments on this device. Nothing is uploaded. Expired drafts are removed when the draft list is opened.',
                ),
                DropdownButtonFormField<int>(
                  initialValue: draftDays,
                  decoration: const InputDecoration(
                    labelText: 'Keep draft for',
                  ),
                  items: [
                    for (final days in [1, 7, 30, 90])
                      DropdownMenuItem(value: days, child: Text('$days days')),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => setState(() => draftDays = value!),
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: busy || sources.isEmpty ? null : saveDraft,
                      child: const Text('Save draft on this device'),
                    ),
                    OutlinedButton(
                      onPressed: busy ? null : restoreDraft,
                      child: const Text('Restore saved draft'),
                    ),
                  ],
                ),
                if (draftMessage != null)
                  Semantics(liveRegion: true, child: Text(draftMessage!)),
              ],
            ),
            if (sources.isNotEmpty) scanControls(),
            FutureBuilder<bool>(
              future: textRecognitionAvailable,
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return OutlinedButton.icon(
                    onPressed: busy || sources.isEmpty
                        ? null
                        : readSelectedPage,
                    icon: const Icon(Icons.text_snippet_outlined),
                    label: const Text('Read printed text from selected page'),
                  );
                }
                return const Text(
                  'Offline text recognition needs a supported local engine and verified English/Bangla files. It is unavailable on this installation.',
                );
              },
            ),
          ],
          if (widget.tool == Tool.print) ...[
            TextFormField(
              controller: copies,
              enabled: !busy,
              keyboardType: TextInputType.number,
              validator: (value) {
                final number = int.tryParse(value ?? '');
                return number == null || number < 1 || number > 200
                    ? 'Use 1–200 copies.'
                    : null;
              },
              onChanged: (_) => changed(),
              decoration: const InputDecoration(labelText: 'Number of copies'),
            ),
            PrintLayoutControls(
              preset: printPaper,
              paperWidth: paperWidth,
              paperHeight: paperHeight,
              margin: printMargin,
              spacing: printSpacing,
              dpi: dpi,
              enabled: !busy,
              guides: cuttingGuides,
              resample: printResample,
              advanced: printAdvanced,
              onChanged: changed,
              onPreset: (value) {
                setState(() {
                  printPaper = value;
                  final size = switch (value) {
                    'a4' => (210.0, 297.0),
                    'a5' => (148.0, 210.0),
                    'letter' => (215.9, 279.4),
                    'photo' => (101.6, 152.4),
                    _ => (
                      double.tryParse(paperWidth.text) ?? 210.0,
                      double.tryParse(paperHeight.text) ?? 297.0,
                    ),
                  };
                  paperWidth.text = size.$1.toString();
                  paperHeight.text = size.$2.toString();
                });
                changed();
              },
              onGuides: (value) {
                setState(() => cuttingGuides = value);
                changed();
              },
              onResample: (value) {
                setState(() => printResample = value);
                changed();
              },
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
  String printSizeSummary(StudioOutput value) {
    final density = value.printDensity!;
    final resolution = density.xDpi == density.yDpi
        ? '${density.xDpi.toStringAsFixed(2)} DPI'
        : '${density.xDpi.toStringAsFixed(2)} × ${density.yDpi.toStringAsFixed(2)} DPI';
    return 'Saved print size: ${(value.width! / density.xDpi * 25.4).toStringAsFixed(2)} × ${(value.height! / density.yDpi * 25.4).toStringAsFixed(2)} mm at $resolution.';
  }

  Widget previewPanel() => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                '3  Preview',
                style: Theme.of(context).textTheme.titleMedium,
              ),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    semanticLabel: 'Verified output',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${(output!.bytes.length / 1024).toStringAsFixed(2)} KiB · ${output!.format.toUpperCase()}${output!.width != null ? ' · ${output!.width} × ${output!.height} pixels' : ''}${output!.pages != null ? ' · ${output!.pages} pages' : ''}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (imageTool)
              const Text('Dimensions, file size and format checked.')
            else
              Text(output!.validation),
            if (output!.printDensity != null) ...[
              const SizedBox(height: 8),
              Text(printSizeSummary(output!)),
              const Text(
                'Print at Actual size / 100%. Other print settings can change the final size.',
              ),
            ],
            if (imageTool)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Output details'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(output!.validation),
                  ),
                ],
              ),
            if (['jpeg', 'png', 'pdf'].contains(output!.format)) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () {
                        try {
                          ref
                              .read(preparedDocumentsProvider.notifier)
                              .add(
                                filename.text,
                                output!.format,
                                output!.bytes,
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Kept for application packs in this session. Remove it in Prepare Application or close the app.',
                              ),
                            ),
                          );
                        } catch (e) {
                          setState(() => saveError = clean(e));
                        }
                      },
                icon: const Icon(Icons.folder_copy_outlined),
                label: const Text('Keep for application pack'),
              ),
            ],
            const Divider(height: 32),
            const Text(
              '4  Save a copy',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: filename,
              onChanged: (_) => setState(() {
                saveError = null;
                saved = null;
              }),
              validator: (s) =>
                  s == null || s.trim().isEmpty ? 'Enter a filename.' : null,
              decoration: const InputDecoration(labelText: 'Filename'),
            ),
            if (saveError != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  saveError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText('✓ Saved and verified\n$saved'),
                      const SizedBox(height: 12),
                      SavedCopyActions(
                        location: saved!,
                        format: output!.format,
                        bytes: output!.bytes,
                        onAnother: () => setState(() {
                          sources = [];
                          output = null;
                          saved = null;
                          saveError = null;
                          error = null;
                          previewIndex = 0;
                          rotation = 0;
                          cover = false;
                          flatten = false;
                          pages.clear();
                          pageNumbers = false;
                          watermarkEnabled = false;
                          showOriginal = false;
                          filename.text = suggestedName;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    ),
  );
  Future<void> saveDraft() async {
    final directory = ref.read(dataDirectoryProvider);
    if (directory == null) {
      setState(() => draftMessage = 'Local draft storage is unavailable.');
      return;
    }
    final snapshot = sources
        .map(
          (s) => DraftPage(
            s.name,
            s.bytes,
            mode: s.scanMode,
            rotation: s.scanRotation,
            brightness: s.brightness,
            contrast: s.contrast,
            corners: s.corners,
          ),
        )
        .toList();
    setState(() => busy = true);
    try {
      await ScanDrafts(directory).save(snapshot, draftDays);
      if (mounted) {
        setState(
          () => draftMessage =
              'Draft saved on this device for $draftDays days. Your original files are unchanged.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => draftMessage =
              'Could not save the draft. Check free space and storage access.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> restoreDraft() async {
    final directory = ref.read(dataDirectoryProvider);
    if (directory == null) {
      setState(() => draftMessage = 'Local draft storage is unavailable.');
      return;
    }
    final store = ScanDrafts(directory);
    final id = await showDialog<String>(
      context: context,
      builder: (context) => ScanDraftPicker(store: store),
    );
    if (id == null || !mounted) {
      return;
    }
    if (sources.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace the current scan session?'),
          content: const Text(
            'Save a draft first if you want to keep your current page order and adjustments. Original files will stay unchanged.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep current scan'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Restore draft'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) {
        return;
      }
    }
    setState(() => busy = true);
    try {
      final restored = await store.restore(id);
      final incoming = restored
          .map(
            (p) => SelectedSource(p.name, p.bytes)
              ..scanMode = p.mode
              ..scanRotation = p.rotation
              ..brightness = p.brightness
              ..contrast = p.contrast
              ..corners = p.corners,
          )
          .toList();
      if (mounted) {
        setState(() {
          sources = incoming;
          previewIndex = 0;
          output = null;
          error = null;
          saved = null;
          saveError = null;
          draftMessage =
              'Restored ${incoming.length} pages. The saved draft is still available.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => draftMessage = 'Could not restore this draft. It may be expired, damaged or unavailable. Your current scan is unchanged.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> editCorners(SelectedSource source) async {
    final result = await Navigator.of(context).push<CornerEditResult>(
      MaterialPageRoute(
        builder: (_) =>
            ScanCornerEditor(source: source.bytes, initial: source.corners),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => source.corners = result.corners);
    changed();
  }

  Widget scanControls() {
    final source = sources[previewIndex.clamp(0, sources.length - 1)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text('Editing page ${previewIndex + 1}: ${source.name}'),
        FutureBuilder<bool>(
          future: geometryAvailable,
          builder: (context, snapshot) {
            if (snapshot.data != true) {
              if (source.corners != null &&
                  snapshot.connectionState == ConnectionState.done) {
                return const Text(
                  'This draft has page corners, but the local correction engine is unavailable in this build. Remove the correction below or open it in a build with the engine.',
                );
              }
              return const SizedBox.shrink();
            }
            return OutlinedButton.icon(
              onPressed: busy ? null : () => editCorners(source),
              icon: const Icon(Icons.crop_free),
              label: Text(
                source.corners == null
                    ? 'Set page corners'
                    : 'Edit page corners',
              ),
            );
          },
        ),
        if (source.corners != null)
          TextButton.icon(
            onPressed: busy
                ? null
                : () {
                    setState(() => source.corners = null);
                    changed();
                  },
            icon: const Icon(Icons.crop_original),
            label: const Text('Remove page corner correction'),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('${source.name}-$previewIndex-${source.scanMode}'),
          isExpanded: true,
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
        const Text(
          'The preview updates with your page adjustments. Your original image stays unchanged.',
        ),
        TextButton(
          onPressed: busy
              ? null
              : () {
                  setState(() {
                    source.corners = null;
                    source.scanMode = 'original';
                    source.scanRotation = 0;
                    source.brightness = 0;
                    source.contrast = 0;
                    output = null;
                  });
                },
          child: const Text('Reset this page to original'),
        ),
      ],
    );
  }

  Widget previewContent() {
    if (widget.tool == Tool.pack && sources.isNotEmpty && output == null) {
      final index = previewIndex.clamp(0, sources.length - 1);
      final source = sources[index];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Selected ${['photo', 'signature', 'certificate'][index]} — original',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (index == 2)
            PdfPreview(data: source.bytes)
          else
            SafeImagePreview(
              bytes: source.bytes,
              semanticLabel:
                  'Selected ${index == 0 ? 'photo' : 'signature'} source image',
            ),
        ],
      );
    }
    if (output?.format == 'pdf') {
      return PdfPreview(data: output!.bytes, pageCount: output!.pages);
    }
    if (widget.tool == Tool.merge && sources.isNotEmpty) {
      return PdfPreview(
        data: sources[previewIndex.clamp(0, sources.length - 1)].bytes,
      );
    }
    if (imageTool && output != null && !showOriginal) {
      return SafeImagePreview(
        bytes: output!.bytes,
        transparency: output!.format == 'png',
        semanticLabel: 'Prepared output preview',
      );
    }
    if (sources.isNotEmpty &&
        widget.tool != Tool.merge &&
        widget.tool != Tool.pack) {
      final source = sources[previewIndex.clamp(0, sources.length - 1)];
      return SafeImagePreview(
        bytes: source.bytes,
        scanOptions: widget.tool == Tool.scan ? source.scanOptions : null,
        semanticLabel: 'Selected source image',
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
