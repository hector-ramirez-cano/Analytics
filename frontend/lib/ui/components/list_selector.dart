import 'package:aegis/main.dart' show messengerKey;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aegis/services/dialog_change_notifier.dart';
import 'package:string_similarity/string_similarity.dart';

enum ListSelectorType {
  checkbox,
  radio,

  none,
}
Icon? noIcon(dynamic _) => null;
Widget? noSubtitle(dynamic _) => null;
Widget? _emptyDisplayTrailing(dynamic option) { return null; }
String? _emptyGetTrailing(dynamic option) { return ""; }

class ListSelector<T> extends StatefulWidget {

  final Set<T> options;
  final bool shrinkWrap;
  final ListSelectorType selectorType;
  final bool Function(dynamic) isSelectedFn;
  final void Function(dynamic, bool?) onChanged;
  final String Function(dynamic) toText;
  final VoidCallback? onClose;
  final VoidCallback? onClear;
  final void Function(bool)? onTristateToggle;
  final Icon? Function(dynamic) leadingIconBuilder;
  final Widget? Function(dynamic) subtitleBuilder;
  final bool Function(dynamic) isAvailable;
  final Widget? Function(dynamic) onDisplayTrailing;
  final String? Function(dynamic) onGetTrailing;


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
    this.onClear,
    this.shrinkWrap = false,
    this.subtitleBuilder = noSubtitle,
    this.leadingIconBuilder = noIcon,
    this.onDisplayTrailing = _emptyDisplayTrailing,
    this.onGetTrailing = _emptyGetTrailing
  });

  @override
  State<ListSelector> createState() => _ListSelectorState<T>();
}

class _ListSelectorState<T> extends State<ListSelector> {
  static final _blankSpaceRegex = RegExp(r'\s');
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _filterController;

  @override
  initState() {
    super.initState();
    _filterController = TextEditingController();
  }

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
          controller: _filterController,
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
              _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeIn);
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

  Widget _makeClearButton() {
    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: () {
        setState(() {
          _filterController.text = "";
          _filterController.clear();
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeIn);
        });

        if (widget.onClear != null) {
          widget.onClear!();
        }
      }
    );
  }

  Widget _makeChecklist(List<T> list) {
    return Expanded(
      child: ListView.builder(
        shrinkWrap: widget.shrinkWrap,
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

  Widget _makeList(BuildContext context, List<T> list) {
    return Expanded(
      child: ListView.builder(
        shrinkWrap: widget.shrinkWrap,
        controller: _scrollController,
        itemCount: list.length,
        itemBuilder: (context, index) {
          final option = list[index];
          return ListTile(
            onTap: () {
                Clipboard.setData(ClipboardData(text: "$option ${widget.onGetTrailing(option)}"));
                messengerKey.currentState?.showSnackBar(
                  SnackBar(
                    key: ValueKey("Snackbar_edit_clipboard"),
                    content: Text("Copiado al portapapeles"),
                    dismissDirection: DismissDirection.down,
                    clipBehavior: Clip.antiAlias,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.fixed,
                    backgroundColor: const Color.fromARGB(255, 19, 103, 114),
                  ),
                );
                  
              },
              key: ValueKey(option),
              leading: widget.leadingIconBuilder(option),
              trailing: widget.onDisplayTrailing(option),
              title: Text(
                widget.toText(option),
                style: widget.isAvailable(option)
                    ? null
                    : ListSelector.unavailableValueStyle,
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
        shrinkWrap: widget.shrinkWrap,
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

  Widget _makeScrollList(BuildContext context) {
    return Consumer(builder:(context, ref, child) {
      ref.watch(dialogRebuildProvider);

      List<T> list = widget.options.toList() as List<T>;
      if (_filterController.text.isNotEmpty) {
        List<T> options = widget.options.toList() as List<T>;
        list = fuzzySearch(_filterController.text, options);
      }

      switch (widget.selectorType) {
        case ListSelectorType.checkbox:
          return _makeChecklist(list);

        case ListSelectorType.radio:
          return _makeRadioList(list);

        case ListSelectorType.none:
          return _makeList(context, list);
      } 
    },);
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
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              _makeSearchBar(),
              if (widget.onClear != null)
                _makeClearButton(),

              if (widget.onClose != null)
                _makeCloseButton(),
            ],
          ),
      
          _makeToggleSelector(),
          SizedBox(height: 32,),
          // Scrollable list
          _makeScrollList(context)
        ],
      ),
    );
  }
}

