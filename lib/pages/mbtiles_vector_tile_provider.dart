import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:mbtiles/mbtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import 'adaptive_tile_gate.dart';

/// Vector tile provider that reads MBTiles (`.pbf`) tiles from disk via SQLite.
///
/// The SQLite database lives in a long-lived worker isolate so tile lookups
/// never block the UI isolate. Requests go through an [AdaptiveTileGate],
/// which loads more tiles at once only while frames stay smooth.
///
/// Pinch protection:
/// - Every pinch gesture bumps a [tileGeneration] counter. Tile results from
///   stale generations are discarded so obsolete intermediate-zoom reads never
///   flood the UI or worker isolate.
/// - While pinching, duplicate requests for the same tile within 100 ms are
///   deduplicated, and reads are limited to 1 concurrent tile via the gate.
class MbtilesVectorTileProvider implements VectorTileProvider {
  /// When true, every tile read, generation bump, and discard is logged to the
  /// console for pinch-and-zoom lag diagnosis. Toggled from the Admin page.
  static ValueNotifier<bool> debugTelemetry = ValueNotifier<bool>(false);

  static const _initRequest = 0;
  static const _initResult = 1;
  static const _tileRequest = 2;
  static const _tileResult = 3;
  static const _disposeRequest = 4;

  /// Debounce window (ms) during active pinch. Repeated requests for the same
  /// tile within this window return the in-flight completer instead of
  /// spawning a new SQLite read.
  static const Duration _pinchDebounce = Duration(milliseconds: 100);

  final int maxZoom;
  /// Limits how many tiles load at once, based on how smooth the frames are.
  final AdaptiveTileGate gate = AdaptiveTileGate();
  final Isolate _isolate;
  final ReceivePort _receivePort;
  final SendPort _workerPort;
  final Map<int, Completer<Uint8List?>> _pending = {};
  final Completer<void> _initialized = Completer<void>();
  int _nextRequestId = 0;
  bool _disposed = false;
  bool _gestureActive = false;

  /// Monotonically increasing counter. Every pinch start bumps it, so tile
  /// results from older generations are discarded.
  int _tileGeneration = 0;

  /// Number of tile results discarded because their generation was stale.
  int _discardedTiles = 0;

  /// Last time a pinch gesture position changed (used for debounce).
  DateTime? _lastGestureTime;

  /// Request timestamps per tile key for pinch debounce.
  final Map<String, DateTime> _tileRequestTimes = {};

  /// Pending requests keyed by "z/x/y" so rapid pinch requests for the same
  /// tile return the in-flight completer instead of spawning duplicate reads.
  final Map<String, Completer<Uint8List?>> _pendingByTile = {};

  MbtilesVectorTileProvider._({
    required Isolate isolate,
    required ReceivePort receivePort,
    required SendPort workerPort,
    this.maxZoom = 14,
  })  : _isolate = isolate,
        _receivePort = receivePort,
        _workerPort = workerPort;

  /// Bump the generation counter. All in-flight tile reads from older
  /// generations are discarded on result.
  void bumpGeneration() => _tileGeneration++;

  /// Current generation. Used by Admin telemetry to show how many pinch
  /// cycles have invalidated tile reads.
  int get tileGeneration => _tileGeneration;

  /// Number of tile results discarded because their generation was stale.
  int get discardedTileCount => _discardedTiles;

  /// Last gesture timestamp (null if never pinched).
  DateTime? get lastGestureTime => _lastGestureTime;

  /// Number of tile requests currently pending in the worker isolate.
  int get pendingCount => _pending.length;

  static Future<MbtilesVectorTileProvider> create({
    required String mbtilesPath,
    int maxZoom = 14,
  }) async {
    final receivePort = ReceivePort();
    final ready = Completer<SendPort>();
    late MbtilesVectorTileProvider provider;
    Isolate? isolate;

    receivePort.listen((message) {
      if (message is SendPort) {
        if (!ready.isCompleted) ready.complete(message);
        return;
      }
      if (message is! List || message.isEmpty) return;

      switch (message[0]) {
        case _initResult:
          final error = message[1] as String?;
          if (provider._initialized.isCompleted) break;
          if (error == null) {
            provider._initialized.complete();
          } else {
            provider._initialized.completeError(Exception(error));
          }
          break;
        case _tileResult:
          provider._handleTileResult(message);
          break;
      }
    });

    try {
      isolate = await Isolate.spawn(_tileWorkerMain, receivePort.sendPort);
      final workerPort =
          await ready.future.timeout(const Duration(seconds: 10));
      provider = MbtilesVectorTileProvider._(
        isolate: isolate,
        receivePort: receivePort,
        workerPort: workerPort,
        maxZoom: maxZoom,
      );
      workerPort.send([_initRequest, mbtilesPath]);
      await provider._initialized.future.timeout(const Duration(seconds: 10));
      provider.gate.start();
      return provider;
    } catch (_) {
      receivePort.close();
      isolate?.kill(priority: Isolate.immediate);
      rethrow;
    }
  }

  /// Called by the UI layer when a pinch/pan gesture starts or ends.
  /// While a gesture is active, new tile reads are debounced so obsolete
  /// intermediate-zoom tiles don't flood the worker isolate.
  void setGestureActive(bool active) {
    _gestureActive = active;
    if (active) {
      bumpGeneration();
      _lastGestureTime = DateTime.now();
      if (debugTelemetry.value) {
        debugPrint('[MbTiles] Gesture active → generation bumped to $_tileGeneration');
      }
    } else {
      _pumpPending();
      if (debugTelemetry.value) {
        debugPrint('[MbTiles] Gesture inactive → pending tiles: $_pending.length');
      }
    }
  }

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    if (_disposed) {
      throw StateError('MBTiles provider has been disposed');
    }
    await gate.acquire();
    try {
      return await _readTile(tile);
    } finally {
      gate.release();
    }
  }

  Future<Uint8List> _readTile(TileIdentity tile) async {
    if (_disposed) {
      throw StateError('MBTiles provider has been disposed');
    }

    final generation = _tileGeneration;
    final tileKey = '${tile.z}/${tile.x}/${tile.y}';

    // Debounce during pinch: if the same tile was requested within the last
    // 100 ms and is still pending, return the in-flight completer instead of
    // spawning another SQLite read.
    if (_gestureActive) {
      final now = DateTime.now();
      final last = _tileRequestTimes[tileKey];
      if (last != null && now.difference(last) < _pinchDebounce) {
        final existing = _pendingByTile[tileKey];
        if (existing != null && !existing.isCompleted) {
          return existing.future as Future<Uint8List>;
        }
      }
      _tileRequestTimes[tileKey] = now;
    }

    final completer = Completer<Uint8List?>();
    final requestId = _nextRequestId++;
    _pending[requestId] = completer;
    _pendingByTile[tileKey] = completer;
    _workerPort.send([_tileRequest, requestId, tile.z, tile.x, tile.y, generation]);

    if (debugTelemetry.value) {
      debugPrint('[MbTiles] Read tile z=${tile.z} x=${tile.x} y=${tile.y} gen=$generation');
    }

    final bytes = await completer.future.timeout(
      _gestureActive ? const Duration(seconds: 2) : const Duration(seconds: 15),
      onTimeout: () {
        _pending.remove(requestId);
        _pendingByTile.remove(tileKey);
        throw Exception(
          'Timed out reading tile z=${tile.z}, x=${tile.x}, y=${tile.y}',
        );
      },
    );

    // Discard results from obsolete generations so pinch churn doesn't render
    // stale tiles over the current view.
    if (generation != _tileGeneration) {
      _discardedTiles++;
      throw StateError('Tile obsolete: generation $generation != $_tileGeneration');
    }

    if (bytes == null) {
      final tmsY = ((1 << tile.z) - 1) - tile.y;
      throw ProviderException(
        message: 'Tile not found: z=${tile.z}, x=${tile.x}, y=$tmsY',
        retryable: Retryable.none,
        statusCode: 404,
      );
    }
    return bytes;
  }

  void _handleTileResult(List<Object?> message) {
    final requestId = message[1] as int;
    final completer = _pending.remove(requestId);
    if (completer == null || completer.isCompleted) return;

    // The request is settled, so it no longer takes part in pinch dedupe.
    _pendingByTile.removeWhere((_, pending) => identical(pending, completer));

    final gen = message[4] as int?;
    // Discard results from obsolete generations.
    if (gen != null && gen != _tileGeneration) {
      _discardedTiles++;
      if (debugTelemetry.value) {
        debugPrint('[MbTiles] Discard tile requestId=$requestId gen=$gen '
            '(current $_tileGeneration) — discarded $_discardedTiles total');
      }
      // Fail fast instead of leaving the caller waiting for its timeout: the
      // tile will be requested again at the current zoom.
      completer.completeError(
        StateError('Tile obsolete: generation $gen != $_tileGeneration'),
      );
      return;
    }

    final error = message[3] as String?;
    if (error != null) {
      completer.completeError(Exception(error));
      return;
    }
    // Zero-copy hand-off from the worker isolate.
    final data = message[2] as TransferableTypedData?;
    completer.complete(data?.materialize().asUint8List());
  }

  /// Release tile requests still queued when a pinch gesture ends. They belong
  /// to the previous generation anyway, so fail them fast and let the map ask
  /// again at the zoom it settled on.
  void _pumpPending() {
    final pending = _pending.values.toList();
    _pending.clear();
    _pendingByTile.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Tile request superseded by pinch'));
      }
    }
  }

  @override
  int get maximumZoom => maxZoom;

  @override
  int get minimumZoom => 0;

  @override
  TileProviderType get type => TileProviderType.vector;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _gestureActive = false;
    gate.dispose();
    _workerPort.send([_disposeRequest]);
    _receivePort.close();
    _isolate.kill(priority: Isolate.immediate);
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('MBTiles provider has been disposed'),
        );
      }
    }
    _pending.clear();
    _pendingByTile.clear();
    _tileRequestTimes.clear();
  }
}

void _tileWorkerMain(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  MbTiles? mbtiles;

  receivePort.listen((message) {
    if (message is! List || message.isEmpty) return;

    switch (message[0]) {
      case MbtilesVectorTileProvider._initRequest:
        try {
          mbtiles = MbTiles(mbtilesPath: message[1] as String);
          mainSendPort.send([MbtilesVectorTileProvider._initResult, null]);
        } catch (error) {
          mainSendPort.send(
            [MbtilesVectorTileProvider._initResult, error.toString()],
          );
        }
        break;
      case MbtilesVectorTileProvider._tileRequest:
        final requestId = message[1] as int;
        final z = message[2] as int;
        final x = message[3] as int;
        final y = message[4] as int;
        final gen = message[5] as int?;
        try {
          final tmsY = ((1 << z) - 1) - y;
          final bytes = mbtiles?.getTile(z: z, x: x, y: tmsY);
          mainSendPort.send([
            MbtilesVectorTileProvider._tileResult,
            requestId,
            bytes == null ? null : TransferableTypedData.fromList([bytes]),
            null,
            gen,
          ]);
        } catch (error) {
          mainSendPort.send([
            MbtilesVectorTileProvider._tileResult,
            requestId,
            null,
            error.toString(),
            gen,
          ]);
        }
        break;
      case MbtilesVectorTileProvider._disposeRequest:
        mbtiles?.dispose();
        receivePort.close();
        Isolate.current.kill(priority: Isolate.immediate);
        break;
    }
  });
}
