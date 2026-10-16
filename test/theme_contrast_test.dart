import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_studio_toolkit/design/theme.dart';
import 'package:universal_studio_toolkit/main.dart';

double contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance(), b = background.computeLuminance();
  return a > b ? (a + 0.05) / (b + 0.05) : (b + 0.05) / (a + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    test('representative $brightness text and studio icons meet contrast targets', () {
      final theme = StudioTokens.theme(brightness), c = theme.colorScheme;
      for (final pair in [
        (c.onSurface, theme.scaffoldBackgroundColor),
        (c.onSurface, c.surfaceContainerLowest),
        (c.onPrimary, c.primary),
        (c.onError, c.error),
        (c.onSurfaceVariant, c.surfaceContainerHighest),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
      for (final tool in Tool.values) {
        expect(contrast(tool.accent(brightness), c.surfaceContainerLowest), greaterThanOrEqualTo(3));
      }
    });
  }
}
