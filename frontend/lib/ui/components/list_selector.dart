import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:network_analytics/services/dialog_change_notifier.dart';
import 'package:string_similarity/string_similarity.dart';

enum ListSelectorType {
  checkbox,
  radio,
}

class ListSelector<T> extends ConsumerStatefulWidget {
  final Set<T> options;
  final ListSelectorType selectorType;
  final bool Function(T) isSelectedFn;
  final void Function(T, bool?) onChanged;
  final String Function(T) toText;
  final VoidCallback onClose;

  const ListSelector({
    super.key,
    required this.options,
    required this.selectorType,
    required this.isSelectedFn,
    required this.onChanged,
    required this.onClose,
    required this.toText,
  });

  @override
  ConsumerState<ListSelector> createState() => _ListSelectorState<T>();
}

class _ListSelectorState<T> extends ConsumerState<ListSelector> {
  String filterText = "";

  List<T> fuzzySearch(String query, List<T> items) {
    final List<MapEntry<T, double>> ratings = items.map((item) {
      final score = query.similarityTo(widget.toText(item));
      return MapEntry(item, score);
    }).toList();

    // Sort by score descending
    ratings.sort((a, b) => b.value.compareTo(a.value));

    // Return just the items, ordered
    return ratings.map((entry) => entry.key).toList();
  }

  Widget _makeSearchBar() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          decoration: const InputDecoration(
            hintText: "Buscar...",
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: (text) {
            setState(() {
              filterText = text;
            });
          },
        ),
      ),
    );
  }

  Widget _makeCloseButton() {
    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: widget.onClose,
    );
  }

  Widget _makeChecklist(List<T> list) {
    var checkboxes = list.map((option) {
      return CheckboxListTile(
        value: widget.isSelectedFn(option),
        onChanged: (state) => widget.onChanged(option, state),
        title: Text(widget.toText(option)),
      );
    }).toList();
    
    return Expanded(
      child: SingleChildScrollView(
        child: Column(
          children: checkboxes,
        ),
      ),
    );
  }

  Widget _makeRadioList(List<T> list) {
    var radioButtons = list.map((option) {
      return ListTile(
        key: ValueKey(option),
        title: Text(widget.toText(option)),
        trailing: Radio(value: option,),
      );
    }).toList();

    var selected = list.where((item) => widget.isSelectedFn(item)).toList();

    return RadioGroup(
      onChanged: (option) => widget.onChanged(option, null),
      groupValue: selected.firstOrNull,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: radioButtons
        ,
      ),
    );
  }

  Widget _makeScrollList() {
    List<T> list = widget.options.toList() as List<T>;
    if (filterText.isNotEmpty) {
      List<T> options = widget.options.toList() as List<T>;
      list = fuzzySearch(filterText, options);
    }

    switch (widget.selectorType) {
      case ListSelectorType.checkbox:
        return _makeChecklist(list);

      case ListSelectorType.radio:
        return _makeRadioList(list);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dialogRebuildProvider);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 150),
      child: Center(
        child: Column(
          children: [
            Row(
              children: [
                _makeSearchBar(),
                _makeCloseButton(),
              ],
            ),
            // Scrollable list
            _makeScrollList()
          ],
        ),
      ),
    );
  }
}

