
// TODO: Unit tests
class RingBuffer<T> {
  late List<T?> _buffer;
  int _head = 0;
  int _length = 0;

  final int capacity;

  RingBuffer(this.capacity) {
    assert(capacity > 0, 'Capacity must be > 0');
    _buffer = List<T?>.filled(capacity, null, growable: false);
  }

  int get length => _length;
  bool get isEmpty => _length == 0;
  bool get isFull => _length == capacity;

  T get first => _buffer[0]!;
  T get last => _buffer[length-1]!;
  T? get firstOrNull => _buffer[0];
  T? get lastOrNull => isEmpty ? null : _buffer[length-1];

  /// Add element at the end; if full, overwrite oldest
  void push(T value) {
    final tailIndex = (_head + _length) % capacity;
    _buffer[tailIndex] = value;
    if (isFull) {
      // Move head forward instead of shifting elements
      _head = (_head + 1) % capacity;
    } else {
      _length++;
    }
  }

  T removeFirst() {
    if (isEmpty) throw Exception('RingBuffer is empty');
    final value = _buffer[_head] as T;
    _buffer[_head] = null;
    _head = (_head + 1) % capacity;
    _length--;
    return value;
  }

  T operator [](int index) {
    if (index < 0 || index >= _length) throw RangeError.index(index, this, 'index');
    return _buffer[(_head + index) % capacity]!;
  }

  Iterable<T> get items sync* {
    for (int i = 0; i < _length; i++) {
      yield _buffer[(_head + i) % capacity]!;
    }
  }

  void clear() {
    _head = 0;
    _length = 0;
    for (int i = 0; i < capacity; i++) {
      _buffer[i] = null;
    }
  }

  @override
  String toString() {
    return _buffer.where((str) => str != null).join("\n");
  }
}
