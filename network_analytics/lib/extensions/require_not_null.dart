extension RequireNotNullExtension<T> on T? {
  T require([String? label]) {
    if (this == null) {
      throw Exception('Missing required value${label != null ? ' for $label' : ''}');
    }
    return this as T;
  }
}
