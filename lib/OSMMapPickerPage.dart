import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class OSMMapPickerPage extends StatefulWidget {
  @override
  _OSMMapPickerPageState createState() => _OSMMapPickerPageState();
}

class _OSMMapPickerPageState extends State<OSMMapPickerPage> {
  LatLng _pickedLocation = LatLng(31.5204, 74.3587); // Lahore

  void _onTap(LatLng latlng) {
    setState(() {
      _pickedLocation = latlng;
    });
  }

  void _confirmLocation() {
    Navigator.pop(context, {
      'lat': _pickedLocation.latitude,
      'lng': _pickedLocation.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pick Location (OpenStreetMap)"),
        backgroundColor: Colors.lightBlue,
        actions: [
          TextButton(
            onPressed: _confirmLocation,
            child: const Text("CONFIRM", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          center: _pickedLocation,
          zoom: 13.0,
          onTap: (tapPosition, point) => _onTap(point),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _pickedLocation,
                child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
