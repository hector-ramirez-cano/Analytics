import 'package:flutter/material.dart';
import 'package:flutter_layout_grid/flutter_layout_grid.dart';

class DashboardWidget extends StatelessWidget {
  final Widget child;
  final int rowStart;
  final int rowSpan;
  final int columnStart;
  final int columnSpan;

  const DashboardWidget(
    this.rowStart,
    this.rowSpan,
    this.columnStart,
    this.columnSpan,
  {
    super.key,
    required this.child,
  });
  
  @override
  Widget build(BuildContext context) {
    return child;
  }

}


class Dashboard extends StatelessWidget {
  const Dashboard({super.key, required this.name, required this.children});

  final String name;
  final List<DashboardWidget> children;

  @override
  Widget build(BuildContext context) {
    final columnCount = children.map((widget) => widget.columnStart + widget.columnSpan).reduce((a, b) => a > b ? a : b);
    final rowCount    = children.map((widget) => widget.rowStart    + widget.rowSpan   ).reduce((a, b) => a > b ? a : b);

    return LayoutGrid(
      columnSizes: [...List.generate(columnCount, (_) => 1.fr), 20.px],
      rowSizes: [...List.generate(rowCount, (_) => 1.fr), 20.px],
      rowGap: 20,
      columnGap: 20,
      children: children.map(
        (item) => item.withGridPlacement(
          rowStart: item.rowStart,
          rowSpan: item.rowSpan,
          columnStart: item.columnStart,
          columnSpan: item.columnSpan
        )).toList(),
    );
  }
}

