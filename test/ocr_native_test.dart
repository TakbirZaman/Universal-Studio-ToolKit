import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:universal_studio_toolkit/application/recognized_text.dart';
import 'package:universal_studio_toolkit/src/rust/frb_generated.dart';
import 'package:universal_studio_toolkit/src/rust/api.dart' as core;
import 'package:universal_studio_toolkit/src/rust/jobs.dart';
import 'package:universal_studio_toolkit/src/rust/ocr.dart';

void main() {
  setUpAll(() async {
    await RustLib.init(
      externalLibrary: ExternalLibrary.open(
        Platform.environment['UST_CORE_LIBRARY'] ??
            '${Directory.current.path}/rust/target/debug/libstudio_core.so',
      ),
    );
  });
  test(
    'opaque handle cancellation and edited Bangla cross the actual typed bridge',
    () async {
      final task = core.createOcrTask();
      try {
        expect(core.ocrTaskState(task: task), JobState.queued);
        expect(core.cancelOcrTask(task: task), isTrue);
        expect(core.ocrTaskState(task: task), JobState.cancelling);
        await expectLater(
          core.recognizeText(
            task: task,
            data: Uint8List(0),
            language: Language.english,
          ),
          throwsA(anything),
        );
        expect(core.ocrTaskState(task: task), JobState.cancelled);
        expect(core.cancelOcrTask(task: task), isFalse);
      } finally {
        task.dispose();
      }
      final edited = Uint8List.fromList(utf8.encode('আমার edited বাংলা'));
      final output = await core.prepareEditedText(data: edited);
      expect(output.bytes, edited);
      expect(output.format, 'txt');
      await core.validatePreparedOutput(output: output, filename: 'বাংলা.txt');
      final destination = await Directory.systemTemp.createTemp(
        'ust-ocr-bridge-',
      );
      try {
        await core.saveOutput(
          directory: destination.path,
          filename: 'বাংলা.txt',
          output: output,
        );
        expect(
          await File('${destination.path}/বাংলা.txt').readAsBytes(),
          edited,
        );
        await expectLater(
          core.saveOutput(
            directory: destination.path,
            filename: 'বাংলা.txt',
            output: output,
          ),
          throwsA(anything),
        );
      } finally {
        await destination.delete(recursive: true);
      }

      await expectLater(
        core.validatePreparedOutput(output: output, filename: '../escape.txt'),
        throwsA(anything),
      );
    },
  );

  final directory = Platform.environment['UST_OCR_SMOKE_DIR'];
  final canRecognize = Platform.isLinux && directory != null;
  test(
    'real engine returns English, Bangla and mixed text through FRB',
    () async {
      expect(await core.ocrAvailable(), isTrue);
      final expected =
          jsonDecode(await File('$directory/expected.json').readAsString())
              as Map<String, dynamic>;
      for (final entry in [
        (Language.english, 'eng'),
        (Language.bangla, 'ben'),
        (Language.mixed, 'ben'),
      ]) {
        final task = core.createOcrTask();
        try {
          final source = await File('$directory/${entry.$2}.png').readAsBytes();
          final before = Uint8List.fromList(source);
          final result = await core.recognizeText(
            task: task,
            data: source,
            language: entry.$1,
          );
          expect(utf8.decode(result.bytes).trim(), expected[entry.$2]);
          expect(core.ocrTaskState(task: task), JobState.succeeded);
          expect(core.cancelOcrTask(task: task), isFalse);
          expect(source, before);
        } finally {
          task.dispose();
        }
      }
    },
    skip: canRecognize
        ? false
        : 'Requires explicitly supplied Linux engine, verified models and synthetic pages.',
  );

  testWidgets('recognition screen displays real text and permits correction', (
    tester,
  ) async {
    final page = await tester.runAsync(
      () => File('$directory/eng.png').readAsBytes(),
    );
    await tester.pumpWidget(
      MaterialApp(home: RecognizedTextScreen(page: page!)),
    );
    await tester.tap(find.text('Read this page'));
    await tester.pump();
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      if (find
          .text('Text is ready to review and edit.')
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(find.text('Text is ready to review and edit.'), findsOneWidget);
    expect(find.text('Cancel recognition'), findsNothing);
    final editor = find.byType(TextField).first;
    expect(
      tester.widget<TextField>(editor).controller!.text.trim(),
      'UNIVERSAL STUDIO 123',
    );
    await tester.enterText(editor, 'Corrected বাংলা 123');
    expect(
      tester.widget<TextField>(editor).controller!.text,
      'Corrected বাংলা 123',
    );
    expect(find.text('Choose location and save a copy'), findsOneWidget);
    final nameField = find.byType(TextField).last;
    await tester.enterText(nameField, '../escape.txt');
    final save = find.text('Choose location and save a copy');
    await tester.ensureVisible(save);
    await tester.tap(save);
    for (var attempt = 0; attempt < 50; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      if (find.textContaining('Use a plain filename').evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.textContaining('Use a plain filename'), findsOneWidget);
    expect(
      tester.widget<TextField>(editor).controller!.text,
      'Corrected বাংলা 123',
    );
    await tester.pumpWidget(const SizedBox());
  }, skip: !canRecognize);
}
