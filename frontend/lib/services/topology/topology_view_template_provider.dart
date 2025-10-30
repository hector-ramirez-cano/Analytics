
import 'package:network_analytics/extensions/semaphore.dart';
import 'package:network_analytics/models/topology_view/topology_view_template.dart';
import 'package:network_analytics/services/websocket_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'topology_view_template_provider.g.dart';

@riverpod
class TopologyViewTemplates extends _$TopologyViewTemplates {
  final Semaphore _firstRun = Semaphore();
  
  Map<int, TopologyViewTemplate> _templates = {};

  void onTopology(Map<String, dynamic> response) {
    if (response["type"] != "topology-view") return;
    if (response["msg"]["type"] != "get") return;

    List definitions = response["msg"]["msg"];

    List<TopologyViewTemplate> templates 
      = definitions.map((definition) => TopologyViewTemplate.fromJson(definition)).where((template) => template!= null).map((template) => template!).toList();

    Map<int, TopologyViewTemplate> oldTemplateMap = _templates;
    Map<int, TopologyViewTemplate> templateMap = Map.fromEntries(templates.map((t) => MapEntry(t.viewId, t)));

    // TODO: Modify the values that are in cache, so they don't show up in insertions, causing an inconsistency
    // keep a merged version of templateMap and oldTemplateMap, in case items have been removed from the database
    // keep them in cache up until the program is closed
    _templates = Map.unmodifiable({...oldTemplateMap, ...templateMap});
    if (_firstRun.isComplete) {
      state = AsyncValue.data(_templates);
    }
    _firstRun.signal();
  }

  @override
  Future<Map<int, TopologyViewTemplate>> build() async {
    final wsState = ref.watch(websocketServiceProvider) ;
    final notifier = ref.watch(websocketServiceProvider.notifier);

    _firstRun.reset();
    await wsState.connected.future;

    notifier.attachListener("topology-view", "topology-view", onTopology);

    notifier.post("topology-view", '"type": "get", "msg": {}');

    await _firstRun.future;
    return _templates;
  }
}