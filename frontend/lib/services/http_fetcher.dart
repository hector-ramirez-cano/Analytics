

import 'package:http/http.dart' as http show get;
import 'package:logger/web.dart';

///
/// Calls for data on an endpoint, and retries if failed.
/// Upoin successful data retrieval, executes an action
class HttpFetcher <T> {

  ///
  /// Connects to the endpoint and retrieves the data from the given [endpoint].
  /// If the connection fails, it [retries] as many times as specified, leaving a delay in-between retries
  /// equivalent to [retryDelay]. If no connection can be made to the endpoint, it considers
  /// a request as failed once [timeout] has elapsed.
  /// 
  /// Upon a successful data request, it calls the [onData] callback
  Future<T> fetch(int retries, Duration retryDelay, Duration timeout, Uri endpoint, Logger logger, T Function(String) onData) async {
    logger.d("Fetching items..., retries=$retries, retryAfter=${retryDelay.inSeconds}, timeout=${timeout.inSeconds}");
    int attempts = 0;
    while (true) {
      try {
        final response = await http
          .get(endpoint)
          .timeout(timeout);

        if (response.statusCode != 200) {
          throw Exception("Failed to load items with HTTP Code = ${response.statusCode}");
        }

        return onData(response.body);
      } catch (e) {
        logger.e("Failed to connect to endpoint, attempt $attempts, Error=${e.toString()}");
        attempts++;

        if (attempts >= retries) { 
          logger.w("Returning Future with error for Exception handling!");
          return Future.error(e.toString());
        }

        await Future.delayed(retryDelay);
      }
    }

  }
}