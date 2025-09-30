import 'package:flutter/material.dart';
import 'package:trina_grid/trina_grid.dart';
import 'package:shimmer/shimmer.dart';

final shimmer = Shimmer.fromColors(
  baseColor: Colors.grey[300]!,
  highlightColor: Colors.grey[100]!,
  child: Container(
    width: double.infinity,
    height: 16,
    color: Colors.grey[300],
  ),
);

Widget columnRenderer(TrinaColumnRendererContext context) {
  final available = context.cell.value != null;

  if (available) {
    return Text(context.cell.value.toString(), style: TextStyle(color: Colors.black),);
  }
  
  return shimmer;
}

