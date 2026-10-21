import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_studio_toolkit/application/prepared_documents.dart';

void main() {
  test('session documents own copies and cannot be modified by consumers', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(preparedDocumentsProvider.notifier);
    final source = Uint8List.fromList([1, 2, 3]);
    store.add('photo.jpg', 'jpeg', source);
    source[0] = 9;
    final document = container.read(preparedDocumentsProvider).single;
    expect(document.bytes, [1, 2, 3]);
    document.bytes[1] = 9;
    expect(document.bytes, [1, 2, 3]);
    expect(
      () => container.read(preparedDocumentsProvider).clear(),
      throwsUnsupportedError,
    );
    store.remove(document.id);
    expect(container.read(preparedDocumentsProvider), isEmpty);
  });

  test(
    'enforces format, filename and item limits without losing existing work',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final store = container.read(preparedDocumentsProvider.notifier);
      for (final name in [
        '../photo.jpg',
        r'C:\photo.jpg',
        '',
        'bad\u0000.jpg',
      ]) {
        expect(
          () => store.add(name, 'jpeg', Uint8List(1)),
          throwsFormatException,
        );
      }
      expect(
        () => store.add('data.zip', 'zip', Uint8List(1)),
        throwsFormatException,
      );
      expect(
        () => store.add('photo.jpg', 'jpeg', Uint8List(0)),
        throwsFormatException,
      );
      for (var i = 0; i < PreparedDocuments.maximumItems; i++) {
        store.add('photo$i.jpg', 'jpeg', Uint8List(1));
      }
      expect(
        () => store.add('more.jpg', 'jpeg', Uint8List(1)),
        throwsFormatException,
      );
      expect(container.read(preparedDocumentsProvider), hasLength(16));
      store.clear();
      expect(container.read(preparedDocumentsProvider), isEmpty);
    },
  );

  test('session bytes are bounded and a new session starts empty', () {
    final container = ProviderContainer();
    final store = container.read(preparedDocumentsProvider.notifier);
    store.add('large.pdf', 'pdf', Uint8List(PreparedDocuments.maximumBytes));
    expect(
      () => store.add('more.pdf', 'pdf', Uint8List(1)),
      throwsFormatException,
    );
    store.clear();
    store.add('small.pdf', 'pdf', Uint8List(1));
    container.dispose();
    final nextSession = ProviderContainer();
    addTearDown(nextSession.dispose);
    expect(nextSession.read(preparedDocumentsProvider), isEmpty);
  });
}
