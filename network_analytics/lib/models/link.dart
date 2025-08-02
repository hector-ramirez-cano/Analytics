
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/link_type.dart';

class Link {
  final int id;
  final Device sideA;
  final Device sideB;
  final LinkType linkType;

  Link ({
    required this.id,
    required this.sideA,
    required this.sideB,
    required this.linkType
  });

  factory Link.fromJson(Map<String, dynamic> json, Map<int, dynamic> devices) {
    Device sideA = devices[json['side-a'] as int];
    Device sideB = devices[json['side-b'] as int];
    String linkType = json['link-type'] as String;

    return Link(
      id   : json['id'] as int,
      sideA: sideA,
      sideB: sideB,
      linkType: LinkType.values.byName(linkType)
    );
  }

  static List<Link> listFromJson(List<dynamic> json, Map<int, dynamic> devices) {
    List<Link> links = [];

    for (var link in json) {
      links.add(Link.fromJson(link, devices));
    }
    
    return links;
  }
}