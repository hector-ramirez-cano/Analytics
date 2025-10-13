final Pattern leading = RegExp("LinkType.");

enum LinkType {
  copper,
  optical,
  wireless;

  @override
  String toString() {
    return super.toString().replaceFirst(leading, "");
  }
}