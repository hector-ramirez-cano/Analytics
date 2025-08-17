import 'package:flutter/material.dart';
import 'package:network_analytics/models/device_group.dart';

class CollapsibleSection extends StatefulWidget {
  final String title;
  final List<String> items;
  const CollapsibleSection({
    super.key,
    required this.title,
    required this.items,
  });

  static Widget createCollapsibleSections(List<DeviceGroup> groups) {
    List<CollapsibleSection> sections = [];

    for (var group in groups) {
      sections.add(fromDeviceGroup(group));
    }

    return Column(children: sections);
  }

  static CollapsibleSection fromDeviceGroup(DeviceGroup group) {
    List<String> items = [];

    for (var device in group.devices) {
      items.add(device.name);
    }

    return CollapsibleSection(title: group.name, items: items);
  }

  
  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection>
    with TickerProviderStateMixin {
  // Show content by default
  bool _expanded = true;
  bool _showContent = true; // whether the content stays in the tree

  void _toggleExpanded() {
    setState(() {
      if (_expanded) {
        // start collapse: animate chevron & opacity, remove after fade-out
        _expanded = false;
      } else {
        // start expand: place content in tree immediately, then fade in
        _showContent = true;
        _expanded = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _makeGroupTitle(),
        _makeGroupChildren(),
      ],
    );
  }

  AnimatedSize _makeGroupChildren() {
    return AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: _showContent
            ? AnimatedOpacity(
                opacity: _expanded ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                onEnd: () {
                  // After fade-out completed, remove from tree to collapse height
                  if (!_expanded && _showContent) {
                    setState(() => _showContent = false);
                  }
                },
                child: _buildContent(),
              )
            : const SizedBox.shrink(),
      );
  }

  MouseRegion _makeGroupTitle() {
    var animatedRotation = AnimatedRotation(
        turns: _expanded ? 0.5 : 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: const Icon(Icons.expand_more),
      );

    var deviceGroupHeader = Expanded(
        child: Text(widget.title,
            style: Theme.of(context).textTheme.headlineMedium,
        )
      );

    var deviceGroupContainer = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [deviceGroupHeader, animatedRotation],
      ),
    );

    return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: _toggleExpanded,
          behavior: HitTestBehavior.opaque,
          child: deviceGroupContainer,
        )
      );
  }

  Widget _buildContent() {
    List<Widget> contentChildren = widget.items
      .map((item) => Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 4, 0),
            child: Text(item),
          ))
      .toList();

    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contentChildren,
      ),
    );
  }
}
