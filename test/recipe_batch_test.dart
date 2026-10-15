import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:universal_studio_toolkit/application/recipe_batch.dart';
import 'package:universal_studio_toolkit/src/rust/api.dart';

StudioOutput output(int n) => StudioOutput(
  bytes: Uint8List.fromList([n]),
  format: 'png',
  validation: 'Test scheduler payload',
);
RecipeBatchItem item(int n) =>
    RecipeBatchItem('$n.png', 'result-$n.png', Uint8List.fromList([n]));

void main() {
  test(
    'failed item does not erase successful results; retry skips successes',
    () async {
      final batch = RecipeBatch('{}', [item(1), item(2), item(3)]);
      final calls = <int>[];
      await batch.run(
        notify: () {},
        process: (bytes, _) async {
          calls.add(bytes.first);
          if (bytes.first == 2) throw StateError('Unreadable image');
          return output(bytes.first);
        },
      );
      final retained = batch.items.first.output;
      expect(batch.items.map((i) => i.state), [
        BatchItemState.succeeded,
        BatchItemState.failed,
        BatchItemState.succeeded,
      ]);
      await batch.run(
        notify: () {},
        process: (bytes, _) async {
          calls.add(bytes.first);
          return output(bytes.first);
        },
      );
      expect(calls, [1, 2, 3, 2]);
      expect(identical(batch.items.first.output, retained), isTrue);
      expect(
        batch.items.every((i) => i.state == BatchItemState.succeeded),
        isTrue,
      );
      expect(batch.items[1].error, isNull);
    },
  );
  test(
    'cancellation waits for active image and stops remaining images',
    () async {
      final batch = RecipeBatch('{}', [item(1), item(2)]);
      final gate = Completer<StudioOutput>();
      final work = batch.run(notify: () {}, process: (_, _) => gate.future);
      expect(batch.items.first.state, BatchItemState.running);
      batch.cancel();
      expect(batch.running, isTrue);
      gate.complete(output(1));
      await work;
      expect(batch.items.first.state, BatchItemState.succeeded);
      expect(batch.items.last.state, BatchItemState.cancelled);
      expect(batch.running, isFalse);
    },
  );
}
