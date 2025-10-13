abstract class AnalyticsItem <T extends AnalyticsItem<T>> {
  final int id;

  AnalyticsItem({required this.id});

  T mergeWith(T other);

  bool isNewItem();
}

abstract class GroupableItem<T extends GroupableItem<T>> extends AnalyticsItem<T> {
  final String name;

  GroupableItem({
    required this.name,
    required super.id,
  });
}