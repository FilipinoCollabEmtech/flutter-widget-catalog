import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:mbtiles/mbtiles.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import 'adaptive_tile_gate.dart';

/// Vector tile provider that reads MBTiles (`.pbf`) tiles from disk via SQLite.
///
/// The SQLite database lives in a long-lived worker isolate so tile lookups
/// never block the UI isolate. Requests go through an [AdaptiveTileGate],
/// which loads more tiles at once only while frames stay smooth.
class MbtilesVectorTileProvider implements VectorTileProvider {
  static const _initRequest = 0;
  static const _initResult = 1;
  static const _tileRequest = 2;
  static const _tileResult = 3;
  static const _disposeRequest = 4;

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

  MbtilesVectorTileProvider._({
    required Isolate isolate,
    required ReceivePort receivePort,
    required SendPort workerPort,
    this.maxZoom = 14,
  })  : _isolate = isolate,
        _receivePort = receivePort,
        _workerPort = workerPort;

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

    final requestId = _nextRequestId++;
    final completer = Completer<Uint8List?>();
    _pending[requestId] = completer;
    _workerPort.send([_tileRequest, requestId, tile.z, tile.x, tile.y]);

    final bytes = await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        _pending.remove(requestId);
        throw Exception(
          'Timed out reading tile z=${tile.z}, x=${tile.x}, y=${tile.y}',
        );
      },
    );

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

    final error = message[3] as String?;
    if (error != null) {
      completer.completeError(Exception(error));
      return;
    }
    // Zero-copy hand-off from the worker isolate.
    final data = message[2] as TransferableTypedData?;
    completer.complete(data?.materialize().asUint8List());
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
        try {
          final tmsY = ((1 << z) - 1) - y;
          final bytes = mbtiles?.getTile(z: z, x: x, y: tmsY);
          mainSendPort.send([
            MbtilesVectorTileProvider._tileResult,
            requestId,
            bytes == null ? null : TransferableTypedData.fromList([bytes]),
            null,
          ]);
        } catch (error) {
          mainSendPort.send([
            MbtilesVectorTileProvider._tileResult,
            requestId,
            null,
            error.toString(),
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
