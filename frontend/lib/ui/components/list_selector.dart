import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aegis/services/dialog_change_notifier.dart';
import 'package:string_similarity/string_similarity.dart';

enum ListSelectorType {
  checkbox,
  radio,
}
Icon? noIcon(dynamic _) => null;
Widget? noSubtitle(dynamic _) => null;
Widget? _emptyDisplayTrailing(dynamic option) { return null; }

class ListSelector<T> extends ConsumerStatefulWidget {

  final Set<T> options;
  final ListSelectorType selectorType;
  final bool Function(dynamic) isSelectedFn;
  final void Function(dynamic, bool?) onChanged;
  final String Function(dynamic) toText;
  final VoidCallback? onClose;
  final void Function(bool)? onTristateToggle;
  final Icon? Function(dynamic) leadingIconBuilder;
  final Widget? Function(dynamic) subtitleBuilder;
  final bool Function(dynamic) isAvailable;
  final Widget? Function(dynamic) onDisplayTrailing;


  static TextStyle unavailableValueStyle = TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic, decoration: TextDecoration.lineThrough);

  const ListSelector({
    super.key,
    required this.options,
    required this.selectorType,
    required this.isSelectedFn,
    required this.onChanged,
    required this.onClose,
    required this.toText,
    required this.isAvailable,
    this.onTristateToggle,
    this.subtitleBuilder = noSubtitle,
    this.leadingIconBuilder = noIcon,
    this.onDisplayTrailing = _emptyDisplayTrailing,
  });

  @override
  ConsumerState<ListSelector> createState() => _ListSelectorState<T>();
}

class _ListSelectorState<T> extends ConsumerState<ListSelector> {
  static final _blankSpaceRegex = RegExp(r'\s');
  final ScrollController _scrollController = ScrollController();

  String filterText = "";

  List<T> fuzzySearch(String query, List<T> items) {
    final finalQuery = query.toLowerCase().replaceAll(_blankSpaceRegex, "");

    final List<MapEntry<T, double>> ratings = items.map((item) {
      final score = finalQuery.similarityTo(widget.toText(item).toLowerCase());
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
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            labelText: "Buscar",
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8.0)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: (text) {
            setState(() {
              filterText = text;
              _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeIn);
            });
          },
        ),
      ),
    );
  }

  Widget _makeCloseButton() {
    if (widget.onClose == null) {
      return SizedBox.shrink();
    }
    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: widget.onClose,
    );
  }

  Widget _makeChecklist(List<T> list) {
    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        itemCount: list.length,
        itemBuilder: (context, index) {
          final option = list[index];
          return CheckboxListTile(
            value: widget.isSelectedFn(option),
            onChanged: (state) => widget.onChanged(option, state),
            title: ListTile(
              key: ValueKey(option),
              leading: widget.leadingIconBuilder(option),
              trailing: widget.onDisplayTrailing(option),
              title: Text(
                widget.toText(option),
                style: widget.isAvailable(option)
                    ? null
                    : ListSelector.unavailableValueStyle,
              ),
            ),
          );
        },
      ),
    );

  }

  Widget _makeRadioList(List<T> list) {
    var radioButtons = list.map((option) {
      return ListTile(
        subtitle: widget.subtitleBuilder(option as dynamic),
        key: ValueKey(option),
        leading: widget.leadingIconBuilder(option as dynamic),
        title: Text(widget.toText(option)),
        onTap: () => widget.onChanged(option, null),
        trailing: Radio(value: option,),
      );
    }).toList();

    var selected = list.where((item) => widget.isSelectedFn(item)).toList();

    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        itemCount: radioButtons.length,
        itemBuilder: (context, index) {
          return RadioGroup(
            onChanged: (option) => widget.onChanged(option, null),
            groupValue: selected.firstOrNull,
            child: radioButtons[index],
          );
        },
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

  Widget _makeToggleSelector() {
    if (widget.onTristateToggle == null) { return SizedBox.shrink();}

    bool some = widget.options.any((option) => widget.isSelectedFn(option));
    bool all = widget.options.every((option) => widget.isSelectedFn(option));

    // if all, true
    // if some, null
    // if none, false

    bool? value;

    if (all) { value = true; }
    else if (some) { value = null;  }
    else { value = false; }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 24.0),
          child: Checkbox(tristate: true, value: value, onChanged: (_) => widget.onTristateToggle!(!all)),
        ),
        Divider(height: 2,)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(dialogRebuildProvider);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              _makeSearchBar(),
              _makeCloseButton(),
            ],
          ),
      
          _makeToggleSelector(),
          SizedBox(height: 32,),
          // Scrollable list
          _makeScrollList()
        ],
      ),
    );
  }
}

