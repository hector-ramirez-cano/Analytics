import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/web.dart';
import 'package:network_analytics/models/alerts/alert_rule.dart';
import 'package:network_analytics/models/analytics_item.dart';
import 'package:network_analytics/models/device.dart';
import 'package:network_analytics/models/group.dart';
import 'package:network_analytics/models/link.dart';
import 'package:network_analytics/models/topology.dart';
import 'package:network_analytics/services/alerts/alert_rules_service.dart';
import 'package:network_analytics/services/item_edit_selection_notifier.dart';
import 'package:network_analytics/services/topology/topology_provider.dart';
import 'package:network_analytics/ui/components/retry_indicator.dart';
import 'package:network_analytics/ui/screens/edit/alert/alert_edit_view.dart';
import 'package:network_analytics/ui/screens/edit/device/device_edit_view.dart';
import 'package:network_analytics/ui/screens/edit/empty_edit_view.dart';
import 'package:network_analytics/ui/screens/edit/group/group_edit_view.dart';
import 'package:network_analytics/ui/screens/edit/link/link_edit_view.dart';
import 'package:network_analytics/ui/screens/edit/new/new_edit_view.dart';

class ItemEditView extends StatelessWidget {
  const ItemEditView({
    super.key,
  });

  Widget _makeAnimatedSettings(Topology topology, AlertRuleSet ruleSet , WidgetRef ref) {
    final item = ref.watch(itemEditSelectionProvider);
    final selected = item.selectedStack.lastOrNull;
    final creatingItem = ref.watch(itemEditSelectionProvider).creatingItem;
    return AnimatedSwitcher(duration: const Duration (milliseconds: 300), child: _makeSettingsView(topology, ruleSet, creatingItem, selected),);
  }

  Widget _makeSettingsView(Topology topology, AlertRuleSet ruleSet, bool creatingItem, AnalyticsItem? selected) {
    var type = selected.runtimeType;

    if (creatingItem && selected == null) {
      return NewEditView(topology: topology,);
    }

    if (selected == null) {
      return EmptyEditView(topology: topology,);
    }

    // TODO: show change resume before applying to DB
    switch (type) {
      case const (Device):
        return DeviceEditView(topology: topology, showDeleteButton: !creatingItem,);

      case const (Link):
        return LinkEditView(topology: topology, showDeleteButton: !creatingItem,);
        
      case const (Group):
        return GroupEditView(topology: topology, showDeleteButton: !creatingItem,);

      case const (AlertRule):
        return AlertEditView(topology: topology, ruleSet: ruleSet, showDeleteButton: !creatingItem);

      // Keep it, in case new type are added
      // ignore: unreachable_switch_default
      default:
        Logger().w("Creating item edit page for item type not defined or missing!");
        return Text("Nobody here but us, chickens!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer (builder: 
      (context, ref, child) {
        final topologyAsync = ref.watch(topologyServiceProvider);
        final ruleSetAsync  = ref.watch(alertRulesServiceProvider);

        onRetry () async {
          final _ = ref.refresh(topologyServiceProvider.future);
          final _ = ref.refresh(alertRulesServiceProvider.future);
        }

        return topologyAsync.when(
          loading: () => RetryIndicator(onRetry: onRetry, isLoading: true),
          error: (error, st) => RetryIndicator(onRetry: onRetry, isLoading: false, error: error.toString(),),
          data: (topology) {
            return ruleSetAsync.when(
              loading: () => RetryIndicator(onRetry: onRetry, isLoading: true),
              error: (error, st) => RetryIndicator(onRetry: onRetry, isLoading: false, error: error.toString(),),
              data: (ruleSet) => _makeAnimatedSettings(topology, ruleSet, ref),
            );
            
          },
        );
      },
    );
  }
  
}