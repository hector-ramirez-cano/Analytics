abstract class AnalyticsItem <T extends AnalyticsItem<T>> {
  final int id;

  AnalyticsItem({required this.id});

  T mergeWith(T other);
}