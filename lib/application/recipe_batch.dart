import 'dart:typed_data';
import '../src/rust/api.dart' as core;

enum BatchItemState { queued, running, cancelled, succeeded, failed }

class RecipeBatchItem {
  final String sourceName, outputName;
  final Uint8List source;
  BatchItemState state = BatchItemState.queued;
  core.StudioOutput? output;
  String? error, savedLocation;
  RecipeBatchItem(this.sourceName, this.outputName, this.source);
}

class RecipeBatch {
  final String recipeJson;
  final List<RecipeBatchItem> items;
  bool running = false, cancellationRequested = false;
  RecipeBatch(this.recipeJson, this.items);
  void cancel() {
    if (running) cancellationRequested = true;
  }

  Future<void> run({
    required void Function() notify,
    Future<core.StudioOutput> Function(Uint8List, String)? process,
  }) async {
    if (running) throw StateError('Batch already running.');
    running = true;
    cancellationRequested = false;
    final engine =
        process ??
        ((bytes, json) => core.runRecipe(data: bytes, recipeJson: json));
    try {
      for (final item in items) {
        if (item.state == BatchItemState.succeeded) continue;
        if (cancellationRequested) {
          item.state = BatchItemState.cancelled;
          notify();
          continue;
        }
        item.state = BatchItemState.running;
        item.error = null;
        notify();
        try {
          final output = await engine(item.source, recipeJson);
          final used = items.fold<int>(
            0,
            (n, i) => n + (i.output?.bytes.length ?? 0),
          );
          if (used + output.bytes.length > 64 * 1024 * 1024) {
            throw StateError(
              'Batch output exceeds 64 MiB. Use fewer photos or a stricter size limit.',
            );
          }
          item.output = output;
          item.state = BatchItemState.succeeded;
        } catch (e) {
          item.error = e.toString();
          item.state = BatchItemState.failed;
        }
        notify();
      }
    } finally {
      running = false;
      notify();
    }
  }
}
