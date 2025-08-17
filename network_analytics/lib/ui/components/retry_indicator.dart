import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:logger/web.dart';

typedef OnRetryCallback = Future<void> Function();

class RetryIndicator extends StatefulWidget {
  final OnRetryCallback onRetry;
  final Object? error;
  final bool isLoading;

  const RetryIndicator({
    super.key,
    required this.onRetry,
    required this.isLoading,
    this.error,
  });

  @override
  State<RetryIndicator> createState() => _RetryIndicatorState();
}

// TODO: REFACTOR
class _RetryIndicatorState extends State<RetryIndicator> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    if (widget.error == null || widget.isLoading ) {
      return const CircularProgressIndicator();
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 8),
          Text(
            'Ocurrió un error',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () async => {
              await widget.onRetry()
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
          TextButton.icon(
            icon: Icon(_showDetails ? Icons.expand_less : Icons.expand_more),
            label: Text(_showDetails ? 'Ocultar detalles' : 'Mostrar detalles'),
            onPressed: () {
              setState(() {
                _showDetails = !_showDetails;
              });
            },
          ),
          if (_showDetails)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                widget.error.toString(),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      );
    }
  }
}
