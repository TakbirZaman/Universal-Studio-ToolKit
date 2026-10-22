import 'package:flutter_test/flutter_test.dart';
import 'package:universal_studio_toolkit/application/pdf_split_plan.dart';

void main() {
  test('expands ordered groups without sorting or silently removing pages', () {
    expect(parseSplitPages('4-5, 1, 2-3', 5), [4, 5, 1, 2, 3]);
    expect(parseSplitPages('200', 200), [200]);
    expect(() => parseSplitPages('1', 1).add(2), throwsUnsupportedError);
  });
  test('rejects malformed, repeated, out-of-bounds and excessive input', () {
    for (final text in ['', '1,', '0', '-1', '6', '3-2', '1-3,2', '1-999999999', '1.0', 'a', '1,,2', '9' * 2049]) {
      expect(() => parseSplitPages(text, 5), throwsFormatException, reason: text);
    }
    expect(() => parseSplitPages('1', 201), throwsFormatException);
  });
}
