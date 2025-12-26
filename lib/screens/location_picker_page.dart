import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as gc;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PickedLocation {
  final double latitude;
  final double longitude;
  final String address;

  PickedLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  GoogleMapController? _mapController;
  LatLng _center = const LatLng(-6.200000, 106.816666); // Jakarta default
  LatLng _marker = const LatLng(-6.200000, 106.816666);
  String _address = 'Fetching address...';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initPosition();
  }

  Future<void> _initPosition() async {
    try {
      final perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() {
          _address = 'Permission denied. Drag marker or search.';
          _loading = false;
        });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      _center = LatLng(pos.latitude, pos.longitude);
      _marker = _center;
      await _reverseGeocode(_marker);
    } catch (_) {
      setState(() {
        _address = 'Could not get location. Drag marker or search.';
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _reverseGeocode(LatLng latLng) async {
    try {
      final placemarks =
          await gc.placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final line = [
          p.name,
          p.street,
          p.subLocality,
          p.locality,
          p.administrativeArea,
          p.country
        ].where((e) => e != null && e.trim().isNotEmpty).join(', ');
        setState(() => _address = line.isNotEmpty ? line : 'Unnamed place');
      } else {
        setState(() => _address = 'Unnamed place');
      }
    } catch (_) {
      setState(() => _address = 'Unnamed place');
    }
  }

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final locations = await gc.locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final target = LatLng(loc.latitude, loc.longitude);
        setState(() {
          _marker = target;
          _center = target;
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
        await _reverseGeocode(target);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address not found')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not search address: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onDragEnd(LatLng pos) {
    setState(() => _marker = pos);
    _reverseGeocode(pos);
  }

  void _confirm() {
    Navigator.pop(
      context,
      PickedLocation(
        latitude: _marker.latitude,
        longitude: _marker.longitude,
        address: _address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
        title: const Text(
          'Pick Location',
          style: TextStyle(color: _primary),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search address',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _searchAddress,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: _initPosition,
                  tooltip: 'Use my location',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _address,
                style: const TextStyle(color: _primary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: (c) => _mapController = c,
                  initialCameraPosition: CameraPosition(target: _center, zoom: 13),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onTap: (p) => _onDragEnd(p),
                  markers: {
                    Marker(
                      markerId: const MarkerId('pick'),
                      position: _marker,
                      draggable: true,
                      onDragEnd: _onDragEnd,
                    ),
                  },
                ),
                if (_loading)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Use this location'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const Color _primary = Color(0xFF2D0C57);
