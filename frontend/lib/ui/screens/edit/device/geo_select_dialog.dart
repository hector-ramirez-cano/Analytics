import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_map/free_map.dart';
import 'package:logger/logger.dart';
import 'package:network_analytics/ui/components/universal_detector.dart';
import 'package:network_analytics/ui/screens/edit/commons/edit_commons.dart';

class GeoSelectDialog extends ConsumerStatefulWidget {

  final VoidCallback onClose;
  final Function(LatLng) onSelect;
  final LatLng initialPosition;

  const GeoSelectDialog({
    super.key,
    required this.onClose,
    required this.initialPosition,
    required this.onSelect,
  });

  static const Icon locationIcon = Icon(
    size: 40.0,
    color: Colors.red,
    Icons.location_on_rounded,
  );

  @override
  ConsumerState<GeoSelectDialog> createState() => _GeoSelectDialogState();
}

class _GeoSelectDialogState extends ConsumerState<GeoSelectDialog> {

  late final MapController _mapController;
  late final TextEditingController _latController;
  late final TextEditingController _longController;

  LatLng marker = LatLng(21.010644, -101.513905);

  bool validLatStr(String value) {
    double lat = 0.0;
    try { lat = double.parse(value); } catch (e) { return false; }

    return (lat <= 90.0) && (lat >= -90.0);
  }

  bool validLngStr(String value) {
    double lng = 0.0;
    try { lng = double.parse(value); } catch (e) { return false; }

    return (lng <= 180) && (lng >= -180);
  }

  void onLongPressEvent(TapPosition position, LatLng geoPosition) {
    Logger().d("onLongPressEvent, LatLng=$position");

    widget.onSelect(geoPosition);

    // Update state for marker and text input
    setState(() {
      marker = geoPosition;

      _latController.text = geoPosition.latitude.toString();
      _longController.text = geoPosition.longitude.toString();
    });
  }

  void onTextChange() {
    if (!validLatStr(_latController.text) && !validLngStr(_longController.text) ) { 
      return;
    }

    double lat = double.parse(_latController.text);
    double lng = double.parse(_longController.text);

    _mapController.move(LatLng(lat, lng), 16);
    // Update state for marker and text input
    setState(() {
      marker = LatLng(lat, lng);
    });
  }


  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _latController = TextEditingController(text: widget.initialPosition.latitude.toString());
    _longController = TextEditingController(text: widget.initialPosition.longitude.toString());

    marker = widget.initialPosition;
  }

  @override
  void dispose() {
    _mapController.dispose();
    _latController.dispose();
    _longController.dispose();
    super.dispose();
  }
  
  Widget _makeCloseButton() {
    
    return Positioned(
      top: 16,
      right: 16,
      child: FloatingActionButton.small(
        onPressed: widget.onClose,
        backgroundColor: Colors.white,
        shape: const CircleBorder(),
        child: const Icon(Icons.close, color: Colors.black),
      ),
    );
  }

  Widget _makeGeoLocator() {
    var map = UniversalDetector(
      setCursor: () => SystemMouseCursors.precise,
      child: FmMap(
        mapController: _mapController,
        mapOptions: MapOptions(
          minZoom: 1, maxZoom: 18, initialZoom: 15,
          initialCenter: widget.initialPosition,
          onLongPress: onLongPressEvent
        ),
        markers: [ Marker(point: marker, child: GeoSelectDialog.locationIcon,) ]
      ),
    );

    return Flexible(
      child: Expanded(
        child: Stack( children: [
            map,
            _makeCloseButton()
          ])
      ),
    );
  }

  Widget _makeLatLongInput() {
    var longFilter = [
      FilteringTextInputFormatter.allow(RegExp(r'^$|^[+-]?((\d\d?)|(1[0-7][0-9]))?(\.\d*)?$')),
    ];
    var latFilter = [
      FilteringTextInputFormatter.allow(RegExp(r'^$|^[+-]?(90(\.0+)?|[0-8]?\d(\.\d*)?)$')),
    ];
  
    var latInput = EditTextField(
      enabled: true,
      initialText: "",
      keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
      formatters: latFilter,
      controller: _latController,
      onEditingComplete: onTextChange,
      backgroundColor: Colors.white
    );

    var longInput = EditTextField(
      enabled: true,
      initialText: "",
      keyboardType: TextInputType.numberWithOptions(decimal: true, signed: true),
      formatters: longFilter,
      controller: _longController,
      onEditingComplete: onTextChange,
      backgroundColor: Colors.white
    );

    var button = ElevatedButton.icon(onPressed: onTextChange, label: Text("Buscar")); // TODO: Functionality

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [latInput, longInput, button  ],
    );
  }

  @override
  Widget build(BuildContext context) {
    
    return Container(
      color: const Color.fromRGBO(100, 100, 100, 0.5),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(50, 50, 50, 150),
        child: Center( child: Container(
            color: Colors.white,
            child: Column(
              children: [
                _makeGeoLocator(),
                _makeLatLongInput()
              ],
            ),
          ),
        ),
      ),
    );

  }
}