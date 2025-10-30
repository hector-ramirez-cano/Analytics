
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aegis/services/canvas/canvas_interaction_service.dart';




final canvasInteractionServiceProvider = Provider<CanvasInteractionService>((ref) {
  return CanvasInteractionService();
});
