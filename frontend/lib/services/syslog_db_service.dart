import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/extensions/development_filter.dart';
import 'package:network_analytics/models/syslog/syslog_filters.dart';
import 'package:network_analytics/models/syslog/syslog_message.dart';
import 'package:network_analytics/models/syslog/syslog_table_cache.dart';
import 'package:network_analytics/services/app_config.dart';
import 'package:oxidized/oxidized.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

part 'syslog_db_service.g.dart';

String dateString(DateTime time) {
  return '${time.year}-${time.month}-${time.day}:${time.hour}:${time.minute}.${time.second}';
}

final _syslogWsProvider = Provider<(WebSocketChannel, Stream, Completer)>((ref) {
  try {
    final endpoint = Uri.parse(AppConfig.getOrDefault('ws/syslog_ws_endpoint'));
    final channel = WebSocketChannel.connect(endpoint);
    final stream = channel.stream.asBroadcastStream();
    final connected = Completer<void>();

    
    SyslogDbService.logger.i('Attempting to start websocket on endpoint=$endpoint');
    // TODO: Handle onError
    channel.ready.then((_) {
      SyslogDbService.logger.d('Websocket channel ready');
      connected.complete();
    },
      onError: (err, st) => {
        SyslogDbService.logger.e('Websocket failed to connect with error = $err')
      }
    );

    ref.onDispose(() {
      channel.sink.close();
    });
  return (channel, stream, connected);
  } catch (e) {
    SyslogDbService.logger.e(e.toString());
    rethrow;
  }
});

@riverpod
class SyslogDbService extends _$SyslogDbService {
  static Logger logger = Logger(filter: ConfigFilter.fromConfig('debug/enable_syslog_service_logging', false));
  late WebSocketChannel _channel;
  late Stream _stream;
  late Completer _wsCompleter;
  late StreamSubscription _streamSubscription;
  final List<SyslogMessage> _pending = [];
  Timer? _batchTimer;


  @override
  Future<SyslogTableCache> build(SyslogFilters filters) async {
    SyslogDbService.logger.d('Recreating SyslogTableCache notifier!');
    final ws = ref.read(_syslogWsProvider);
    _channel = ws.$1;
    _stream = ws.$2;
    _wsCompleter = ws.$3;
    
    final messageCount = await _getRowCount(_channel, _stream, filters);

    if (messageCount.isErr()) {
      throw(messageCount.err().expect("[ERROR]Error result doesn't contain an error message"), StackTrace.current);
    }

    ref.onDispose(() {
      SyslogDbService.logger.d('Dettached Stream Subscription');
      _batchTimer?.cancel();
      _streamSubscription.cancel();
    });

    int requestedCount = _attachListener(_stream, filters);
    
    return SyslogTableCache.empty(filters)
      .copyWith(
        state: SyslogTableCacheState.createdUpdating,
        requestedCount: requestedCount,
        messageCount: messageCount.unwrap()
      );

  }

  Future<Result<int, String>> _getRowCount(WebSocketChannel channel, Stream stream, SyslogFilters filters) async {

    // await the ws connection before trying to send anything
    await _wsCompleter.future;

    SyslogDbService.logger.d('Asking backend for row count via Websocket for range = ${filters.range}');

    // ask politely - Would you kindly...
    final request = jsonEncode([{'type': 'request-size', ...filters.toDict()}]);
    channel.sink.add(request);
    
    // get the data 
    final first = await stream.first;
    final decoded = jsonDecode(first);
    SyslogDbService.logger.d('_getRowCount recieved a message = $decoded');
    if (decoded['type'] == 'error') {
      
      return (Result.err(decoded['msg']));
    }
    if (decoded['type'] != 'request-size') {
      return Result.err('Expected row_count as first message');
    }

    return Result.ok(decoded['count'] as int);
  }

  int _attachListener(Stream stream, SyslogFilters filter,) {
    SyslogDbService.logger.d('Attached Stream Subscription');
    _streamSubscription = stream.listen((message) {
      // SyslogBuffer.logger.d('Stream Subscription recieved a message = $message');
      final decoded = jsonDecode(message);

      if (decoded is Map && decoded.containsKey('type')) {
        final type = decoded['type'];
        if (type == 'error') {
          return _handleError(decoded['msg']);
        }
        if (type == 'request-size') {
          // ignore
          return;
        }
      }

      final row = SyslogMessage.fromJson(decoded);
      _pending.add(row);
      _batchTimer?.cancel();
      _batchTimer = Timer(Duration(milliseconds: 100), _flushBatch);
    }, onError: _handleError, onDone: _handleDone);

    // ask for initial batch
    final int requestCount = 30;
    final request = jsonEncode([
      {'type': 'set-filters', ...filters.toDict()},
      {'type': 'request-data', 'count': requestCount}
    ]);
    _channel.sink.add(request);

    return requestCount;
  }

  void _flushBatch() {
    final Map<int, SyslogMessage> updatedMessages = {...state.value?.messages ?? {}};
    final List<int> hydrated = [];
    for (int i = 0 ; i < _pending.length; i++) {
      final message = _pending[i];
      hydrated.add(message.id);
      updatedMessages[message.id] = message;

      state.value!.addMapping(state.value!.consumeNextRowIndex(), message.id);
    }
    // logger.d("Flusing pending websocket syslog messages = ${state.value?.messages}");
    _pending.clear();

    state = AsyncValue.data(state.value!.copyWith( messages: updatedMessages, hydrated: hydrated, state: SyslogTableCacheState.hydrated));
    

  }

  void requestMoreRows(int count) {
    final request = jsonEncode({'type': 'request-data', 'count': count});
    _channel.sink.add(request);

    state = AsyncValue.data(state.value!.copyWith(state: SyslogTableCacheState.updating, requestedCount: count));
  }

  void _handleError(dynamic error) {
    logger.e('WebSocket error: $error');
    state = AsyncValue.error(error, StackTrace.current);
  }

  void _handleDone() {
    logger.w('WebSocket connection closed');
    // Optionally update state or trigger reconnection
  }

}
