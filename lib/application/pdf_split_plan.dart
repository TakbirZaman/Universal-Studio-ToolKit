/// Ordered, one-based pages for one independently exported PDF.
List<int> parseSplitPages(String text, int pageCount) {
  if (pageCount < 1 || pageCount > 200 || text.length > 2048) {
    throw const FormatException('Choose a PDF with 1–200 pages.');
  }
  final pages = <int>[];
  for (final token in text.split(',')) {
    final match = RegExp(r'^\s*(\d+)(?:\s*-\s*(\d+))?\s*$').firstMatch(token);
    if (match == null) {
      throw const FormatException('Use page numbers or ranges, such as 1-3,5.');
    }
    final first = int.tryParse(match.group(1)!);
    final last = int.tryParse(match.group(2) ?? match.group(1)!);
    if (first == null || last == null || first < 1 || last < first || last > pageCount) {
      throw FormatException('Pages must be within 1–$pageCount; ranges must ascend.');
    }
    for (var page = first; page <= last; page++) {
      if (pages.contains(page)) {
        throw const FormatException('A part cannot contain the same page twice.');
      }
      pages.add(page);
    }
  }
  return List.unmodifiable(pages);
}
