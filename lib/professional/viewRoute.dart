import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:geolocator/geolocator.dart';
import 'professionalOrderPage.dart'; // Your file with `LocationAutocompleteField`



class ViewRoute extends StatefulWidget {
  final String address;
  final double lat;
  final double lng;

  const ViewRoute({
    super.key,
    required this.address,
    required this.lat,
    required this.lng,
  });

  @override
  State<ViewRoute> createState() => _ViewRouteState();
}



class _ViewRouteState extends State<ViewRoute> {
  LatLng? _selectedLocation;
  List<LatLng> _routePoints = [];
  final TextEditingController _searchController = TextEditingController();

  final String _locationIQKey = 'pk.c6205b1882bfb7c832c4fea13d2fc5b4';



  Future<void> _getRouteFromLocationIQ({required LatLng start, required LatLng end}) async {
    final url =
        'https://us1.locationiq.com/v1/directions/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?key=$_locationIQKey&geometries=geojson';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> coords = data['routes'][0]['geometry']['coordinates'];
      setState(() {
        _routePoints = coords.map((point) => LatLng(point[1], point[0])).toList();
      });
    } else {
      print("🚫 Failed to get route: ${response.body}");
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      LatLng current = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLocation = current;
      });

      await _getRouteFromLocationIQ(
        start: current,
        end: LatLng(widget.lat, widget.lng),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  void _onPlaceSelected(gmaps.LatLng latLng, String displayName) {
    if (latLng.latitude == 0 && latLng.longitude == 0) {
      // Clear case
      setState(() {
        _selectedLocation = null;
        _routePoints.clear();
      });
      return;
    }

    final selected = LatLng(latLng.latitude, latLng.longitude);
    setState(() {
      _selectedLocation = selected;
    });

    _getRouteFromLocationIQ(start: selected, end: LatLng(widget.lat, widget.lng));
  }

  @override
  Widget build(BuildContext context) {
    final customerPoint = LatLng(widget.lat, widget.lng);

    return Scaffold(
      appBar: AppBar(title: const Text("Route to Client")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _useCurrentLocation,
                    icon: const Icon(Icons.my_location),
                    label: const Text("Use Current Location"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EA5E9),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                LocationAutocompleteField(
                  controller: _searchController,
                  onPlaceSelected: _onPlaceSelected,
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: customerPoint,
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                  subdomains: const ['a', 'b', 'c'],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: customerPoint,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, size: 40, color: Colors.red),
                    ),
                    if (_selectedLocation != null)
                      Marker(
                        point: _selectedLocation!,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.person_pin_circle, size: 40, color: Colors.blue),
                      ),
                  ],
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 5,
                        color: Colors.deepPurple,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),


    );
  }
}
