import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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
  LatLng? _currentLocation;
  List<LatLng> _routePoints = [];

  final String _locationIQKey = 'pk.c6205b1882bfb7c832c4fea13d2fc5b4'; // Replace with your real key

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocationAndRoute();
  }

  Future<void> _fetchCurrentLocationAndRoute() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception("Location services are off");

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Location permission denied");
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception("Location permission permanently denied");
      }

      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      await _getRouteFromLocationIQ(
          start: _currentLocation!, end: LatLng(widget.lat, widget.lng));
    } catch (e) {
      print("❌ Error fetching location or route: $e");
    }
  }

  Future<void> _getRouteFromLocationIQ({
    required LatLng start,
    required LatLng end,
  }) async {
    final url =
        'https://us1.locationiq.com/v1/directions/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?key=$_locationIQKey&geometries=geojson';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> coords =
      data['routes'][0]['geometry']['coordinates'];

      setState(() {
        _routePoints = coords
            .map((point) => LatLng(point[1], point[0])) // GeoJSON uses [lng, lat]
            .toList();
      });
    } else {
      print("🚫 Failed to get route: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Route to Client")),
      body: _currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
        options: MapOptions(
          initialCenter: _currentLocation!,
          initialZoom: 13,
        ),
        children: [
          TileLayer(
            urlTemplate:
            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _currentLocation!,
                width: 40,
                height: 40,
                child: const Icon(Icons.person_pin_circle,
                    size: 40, color: Colors.blue),
              ),
              Marker(
                point: LatLng(widget.lat, widget.lng),
                width: 40,
                height: 40,
                child: const Icon(Icons.location_on,
                    size: 40, color: Colors.red),
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
    );
  }
}
