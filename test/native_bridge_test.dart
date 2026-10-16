import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:universal_studio_toolkit/src/rust/frb_generated.dart';
import 'package:universal_studio_toolkit/src/rust/api.dart';

void main() {
  test(
    'real Rust bridge processes, validates and safely saves output',
    () async {
      await RustLib.init(
        externalLibrary: ExternalLibrary.open(
          Platform.environment['UST_CORE_LIBRARY'] ??
              '${Directory.current.path}/rust/target/debug/libstudio_core.so',
        ),
      );
      final source = await File(
        'rust/tests/fixtures/orientation-6.jpg',
      ).readAsBytes();
      final output = await resizePhoto(
        data: source,
        width: 300,
        height: 300,
        png: false,
        cover: false,
        limitKib: 100,
        minimumQuality: 60,
        flatten: false,
        rotation: 0,
      );
      expect(output.width, 300);
      expect(output.height, 300);
      expect(output.bytes.length, lessThan(102400));
      final syntheticScan = await scanPdf(inputs: [source, source, source]);
      final pdf = syntheticScan.bytes;
      final optimized = await optimizePdf(data: pdf);
      expect(optimized.pages, 3);
      expect(optimized.bytes.length, lessThanOrEqualTo(pdf.length));
      final page = await renderPdfPage(data: pdf, pageIndex: 0, maxPixels: 800);
      final optimizedPage = await renderPdfPage(
        data: optimized.bytes, pageIndex: 0, maxPixels: 800,
      );
      expect(optimizedPage.bytes, page.bytes);
      expect(page.format, 'png');
      expect(page.height, lessThanOrEqualTo(800));

      final dir = await Directory.systemTemp.createTemp('ust-bridge-');
      try {
        await saveOutput(
          directory: dir.path,
          filename: 'ছবি.jpg',
          output: output,
        );
        expect(await File('${dir.path}/ছবি.jpg').readAsBytes(), output.bytes);
        await expectLater(
          saveOutput(directory: dir.path, filename: 'ছবি.jpg', output: output),
          throwsA(anything),
        );
      } finally {
        await dir.delete(recursive: true);
        RustLib.dispose();
      }
    },
  );
}
