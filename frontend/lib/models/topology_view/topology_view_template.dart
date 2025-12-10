
import 'dart:ui';

import 'package:logger/web.dart';
import 'package:aegis/models/topology_view/topology_view_member.dart';


class TopologyViewTemplate {
  final int viewId;
  final String name;
  final Map<int, TopologyViewMember> members;

  TopologyViewTemplate({
    required this.viewId,
    required this.name,
    required this.members,
  });

  static TopologyViewTemplate? fromJson(Map<String, dynamic> response) {
    final viewId = response["id"];
    final name = response["name"] ?? "Vista sin nombre";
    final List<dynamic> members = response["members"] ?? [];

    // absolutely required, if not present, or the wrong type, we can't recover
    if (viewId == null) {
      Logger().e("While parsing TopologyViewTemplate fromJson, encountered missing values: viewId=$viewId");
      return null;
    }

    if (viewId is! int) {
      Logger().e("While parsing TopologyViewTemplate fromJson, encountered viewId is not expected type. Expected int, actual=$viewId");
      return null;
    }

    // if (isPhysicalView is! bool) {
    //   Logger().e("While parsing TopologyViewTemplate fromJson, encountered isPhysicalView is not expected type. Expected bool, actual=$isPhysicalView");
    //   return null;
    // }

    // if name is not present, we can use an dummy value
    if (response["name"] is! String) {
      Logger().w("While parsing TopologyViewTemplate fromJson, encountered no name is present, using a dummy value...");
    }

    if (response["members"] is! List) {
      Logger().w("While parsing TopologyViewTemplate fromJson, encountered no valid members array, using empty value...");
    }

    final memberMap = Map<int, TopologyViewMember>.fromEntries(members.map((m) 
      => MapEntry(m["id"], TopologyViewMember(itemId: m["id"], position: Offset(m["x"].toDouble(), m["y"].toDouble())))));

    return TopologyViewTemplate(
      viewId: viewId,
      name: name,
      members: memberMap
    );
  }

  bool contains(int id) => members.containsKey(id);

  bool containsLink(int id1, int id2) => members.containsKey(id1) && members.containsKey(id2);
}