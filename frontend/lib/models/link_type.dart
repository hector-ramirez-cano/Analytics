import 'package:logger/web.dart';

final Pattern leading = RegExp("LinkType.");

enum LinkType {
  copper,
  optical,
  wireless;

  @override
  String toString() {
    return super.toString().replaceFirst(leading, "");
  }

  static LinkType? fromString(String value) {

    switch(value) {
      case "copper":
        return copper;

      case "optical":
        return optical;

      case "wireless":
        return wireless;

      default:
        Logger().w("Parsing LinkType from '$value' will yield a null value.");
        return null;
    }
  }
}