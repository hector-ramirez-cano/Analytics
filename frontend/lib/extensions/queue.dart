
import 'dart:collection';

extension TakeAndRemoveExtension on Queue {

  List<T> takeAndRemove<T>(int count) {
    final available = length < count ? length : count;
    return List.generate(available, (_) => removeFirst());
  }
}