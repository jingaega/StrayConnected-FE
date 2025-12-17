import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/widgets/global_bottom_nav.dart';

const Color _bg = Color(0xFFF6F5F5);
const Color _primary = Color(0xFF2D0C57);
const Color _muted = Color(0xFF9586A8);
const Color _stroke = Color(0xFFD8D0E3);

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _role = 'user';
  double? _lat;
  double? _lng;
  bool _loading = true;
  String? _error;
  GoogleMapController? _mapCtrl;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) {
        setState(() {
          _error = 'Not signed in';
          _loading = false;
        });
        return;
      }
      final data =
          await _supabase.from('user').select('role, latitude, longitude').eq('id', uid).maybeSingle();
      final role = (data?['role'] as String?) ?? 'user';
      _role = role;

      if (role == 'rescuer' || role == 'shelter') {
        final lat = (data?['latitude'] as num?)?.toDouble();
        final lng = (data?['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) {
          setState(() {
            _error = 'No location saved. Please add latitude/longitude in profile.';
            _loading = false;
          });
          return;
        }
        setState(() {
          _lat = lat;
          _lng = lng;
          _loading = false;
        });
      } else {
        // Adopter: use GPS
        final perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          setState(() {
            _error = 'Location permission denied.';
            _loading = false;
          });
          return;
        }
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
        );
        setState(() {
          _lat = pos.latitude;
          _lng = pos.longitude;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    const double navHeight = 86;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(),
                Expanded(
                  child: _buildBody(),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RoleAwareBottomNav(
                onCreateAllowed: () => Navigator.pushNamed(context, '/createAnimal'),
                onHome: () => Navigator.pushReplacementNamed(context, '/home'),
                onMessages: () => Navigator.pushReplacementNamed(context, '/chats'),
                onMeetings: () => Navigator.pushReplacementNamed(context, '/meetings'),
                onProfile: () => Navigator.pushReplacementNamed(context, '/profile'),
                activeTab: BottomNavTab.profile,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: (_lat != null && _lng != null)
          ? FloatingActionButton(
              onPressed: () {
                _mapCtrl?.animateCamera(
                  CameraUpdate.newLatLngZoom(LatLng(_lat!, _lng!), 14),
                );
              },
              child: const Icon(Icons.my_location),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }
    if (_lat == null || _lng == null) {
      return const Center(
        child: Text(
          'No location available.',
          style: TextStyle(color: _muted),
        ),
      );
    }

    final LatLng pos = LatLng(_lat!, _lng!);
    final String label =
        (_role == 'rescuer' || _role == 'shelter') ? 'Your saved location' : 'Your current location';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _stroke),
            ),
            child: Row(
              children: [
                const Icon(Icons.place, color: _primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$label\nLat: ${pos.latitude.toStringAsFixed(5)}, Lng: ${pos.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: _primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GoogleMap(
                onMapCreated: (ctrl) => _mapCtrl = ctrl,
                myLocationEnabled: _role == 'adopter',
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                initialCameraPosition: CameraPosition(target: pos, zoom: 13),
                markers: {
                  Marker(
                    markerId: const MarkerId('user'),
                    position: pos,
                    infoWindow: InfoWindow(title: label),
                  ),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new, color: _primary),
          ),
          const SizedBox(width: 8),
          const Text(
            'Location',
            style: TextStyle(
              color: _primary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
