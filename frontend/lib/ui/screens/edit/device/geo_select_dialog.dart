import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:free_map/free_map.dart';
import 'package:network_analytics/ui/components/universal_detector.dart';

class GeoSelectDialog extends ConsumerStatefulWidget {

  final VoidCallback onClose;

  const GeoSelectDialog({
    super.key,
    required this.onClose,
  });

  @override
  ConsumerState<GeoSelectDialog> createState() => _GeoSelectDialogState();
}

class _GeoSelectDialogState extends ConsumerState<GeoSelectDialog> {

  late final MapController _mapController;
  // LatLng? _currentPos;
  // final _src = const LatLng(37.4165849896396, -122.08051867783071);
  // final _dest = const LatLng(37.420921119071586, -122.08535335958004);


  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
  
  Widget _makeCloseButton() {
    return IconButton(
      icon: const Icon(Icons.close),
      onPressed: widget.onClose,
    );
  }

  Widget _makeGeoLocator() {
    return Flexible(
      child: Expanded(
        child: UniversalDetector(
          setCursor: () => SystemMouseCursors.precise,
          

          child: FmMap(
            mapController: _mapController,
            mapOptions: MapOptions(
              minZoom: 1,
              maxZoom: 18,
              initialZoom: 15,
              initialCenter: LatLng(21.010644, -101.513905),
              onTap: (pos, point) => () => {}, // TODO: Functionality
            ),
            markers: [
              
            ],
            polylineOptions: const FmPolylineOptions(
              strokeWidth: 3,
              color: Colors.blue,
            ),
          ),
        )
      ),
    );
  }

  Widget _makeLatLongInput() {
    return Row(children: [

    ],)
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromRGBO(100, 100, 100, 0.5),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(50, 50, 50, 150),
        child: Center(
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    _makeCloseButton(),
                  ],
                ),
                
                _makeGeoLocator()
              ],
            ),
          ),
        ),
      ),
    );

  }
}