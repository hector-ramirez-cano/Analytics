import 'package:flutter/material.dart';

class CheckboxSelectDialog extends StatelessWidget {
  final Set<dynamic> options;
  final Function(dynamic) isSelected;
  final Function(dynamic, bool?) onChanged;
  final Function(dynamic) title;

  const CheckboxSelectDialog({
    super.key,
    required this.options,
    required this.isSelected,
    required this.onChanged,
    required this.title
  });
  

  @override
  Widget build(BuildContext context) {
    var checkboxes = options.map((option) {
          return CheckboxListTile(
            value: isSelected(option),
            onChanged: (state) => onChanged(option, state),
            title: Text(title(option)),
          );
        }).toList();

    return Container(
      color: Color.fromRGBO(100, 100, 100, 0.5),
        child: Padding(
          padding: EdgeInsetsGeometry.directional(start: 50, end: 50, top: 50, bottom: 150),
          child: SingleChildScrollView( 
            child: Container(
              color: Colors.white,
              child: Column(children: checkboxes),
            )
          )
        ),
    );
  }

}