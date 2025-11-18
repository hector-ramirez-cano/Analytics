
import 'dart:async';
import 'dart:convert';
import 'package:aegis/extensions/semaphore.dart';
import 'package:logger/web.dart';
import 'package:aegis/extensions/development_filter.dart';
import 'package:aegis/services/app_config.dart';
import 'package:oxidized/oxidized.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

part 'websocket_service.g.dart';

dynamic extractBody(String type, dynamic decoded, Function(String) onError) {

    if (decoded['type'] == 'error') { return onError(decoded['msg'] ?? "Error message with no content"); }
    
    final content = decoded['msg'];

    return content;
}

Future<Result<int, String>> getRowCount(String type, dynamic filters, Ref ref, Function(String) onError) async {

  final wsNotifier = ref.read(websocketServiceProvider.notifier);
  final ws = ref.read(websocketServiceProvider);

  // await the ws connection before trying to send anything
  await ws.connected.future;

  WebsocketService.wsLogger.d('Asking backend for row count via Websocket for range = ${filters.range}');

  // ask politely - Would you kindly...
  final request = [
    {'type': 'set-filters', 'msg': filters.toDict()},
    {'type': 'request-size', 'msg': {}}
  ];

  final sizeReadySemaphore = Semaphore();
  late final Map sizeMsg;
  final key = "$type\\_${filters.hashCode}";
  wsNotifier.attachListener(type, key, (json) {
    final contents = json["msg"];

    if (contents == null || contents is! Map) { return; }
    if (contents['type'] != 'request-size') { return; }

    sizeMsg = json;
    sizeReadySemaphore.signal();
  });
  wsNotifier.post(type, request);

  // get the data
  await sizeReadySemaphore.future;
  final response = sizeMsg;
  wsNotifier.removeListener(key);

  WebsocketService.wsLogger.d('_getRowCount recieved a message = $response');
  final content = extractBody(type, response, onError);

  if (content['type'] != 'request-size') {
    return Result.err('Expected row_count as response message');
  }

  return Result.ok(content['count'] as int);
}



class WsState {
  final WebSocketChannel channel;
  final Stream stream;
  final Completer<void> connected;

  WsState({
    required this.channel,
    required this.stream,
    required this.connected,
  });
}

class WsListener{
  Function(Map<String, dynamic>) callback;
  String filterString;

  WsListener({
    required this.callback,
    required this.filterString,
  });
}


@riverpod
class WebsocketService extends _$WebsocketService {
  static final wsLogger = Logger(filter: ConfigFilter.fromConfig("debug/enable_ws_logging", false));
  final Map<String, WsListener> listeners = {};

  StreamSubscription? _streamSubscription;
  late WsState _state;

  Timer? _retryTimer;
  
  @override
  WsState build() {
    try {
      listeners.clear();
      final endpoint = Uri.parse(AppConfig.getOrDefault('api/ws_router_endpoint'));
      final channel = WebSocketChannel.connect(endpoint);
      final stream = channel.stream.asBroadcastStream();
      final connected = Completer<void>();

      wsLogger.i('Attempting to start websocket on endpoint=$endpoint');
      // TODO: Handle onError
      channel.ready.then((_) {
        wsLogger.d('Websocket channel ready');
        connected.complete();

        _attachStreamListener();
      },
        onError: (err, st) {
          wsLogger.e('Websocket failed to connect with error = $err');
          reconnect();
        }
      );

      ref.onDispose(() {
        channel.sink.close();
        _streamSubscription?.cancel();
        listeners.clear();
      });

      _state = WsState(channel: channel, stream: stream, connected: connected);
    

      return _state;
    } catch (e) {
      wsLogger.e(e.toString());
      rethrow;
    }
  }

  void post(String type, dynamic body) {
    final monosodiumglutamate = jsonEncode({
      "type": type,
      "msg": body
    });

    _state.channel.sink.add(monosodiumglutamate);
  }

  void _attachStreamListener() {
    _streamSubscription = _state.stream.listen((message) {
      final content = jsonDecode(message);

      // Logger().d("WebSocket received msg, type = ${content["type"]}");
      if (content ["type"] == "error") {
        Logger().w("[WARN ] Websocket received an error message = $content");
      }

      for (var listener in listeners.values) {
        if (listener.filterString != content["type"] && content["type"] != "error") { continue; }

        listener.callback(content);
      }
    },
    onError: _handleError,
    onDone: _handleDone
    );
  }

  void attachListener(String typeFilter, String key, Function(Map<String, dynamic>) listener, ) => listeners[key] = (WsListener(callback: listener, filterString: typeFilter));
  
  void removeListener(String key) => listeners.remove(key);

  void _handleError(dynamic error) {
    wsLogger.e('WebSocket error: $error');

    reconnect();
  }

  void _handleDone() {
    wsLogger.w('WebSocket connection closed, attempting reconnection');
    
    reconnect();
  }

  void reconnect() {

    // if a timer is already active, we don't do anything else
    if (_retryTimer?.isActive == true) { return; }

    _retryTimer = Timer(const Duration(seconds: 10), () => ref.invalidateSelf(asReload: true));
  }
}