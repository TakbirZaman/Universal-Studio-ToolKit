import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_studio_toolkit/application/transparency_preview.dart';

void main() {
  testWidgets('background switching preserves the output byte buffer', (tester) async {
    // Deliberately invalid decoder input also exercises the safe preview fallback.
    final bytes = Uint8List.fromList([1, 2, 3]);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: TransparencyPreview(bytes: bytes))));
    await tester.pumpAndSettle();
    expect(find.text('Image preview unavailable.'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();
    expect(bytes, [1, 2, 3]);
    expect(find.text('Dark'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
