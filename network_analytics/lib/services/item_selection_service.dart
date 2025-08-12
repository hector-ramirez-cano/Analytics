import 'package:flutter_riverpod/flutter_riverpod.dart';

class ItemSelectionService extends StateNotifier<int?> {
  ItemSelectionService() : super(null);

  void setSelected(int? id) => state = id;
}
