import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _bg = Color(0xFFF6F5F5);
const Color _primary = Color(0xFF2D0C57);
const Color _muted = Color(0xFF9586A8);
const Color _stroke = Color(0xFFD8D0E3);
const Color _accent = Color(0xFF0BCE83);
const Color _warn = Color(0xFFFFB04C);
const Color _reject = Colors.redAccent;
const Color _info = Color(0xFF5B30B5);

class MeetingDetailsPage extends StatefulWidget {
  final int meetingId;
  final String status;
  final String date;
  final String time;
  final String? animalName;
  final String? animalImage;
  final String? meetingType;
  final String? contactPhone;
  final String? rescuerId;
  final String? shelterId;
  final String? adopterId;
  final String role;

  const MeetingDetailsPage({
    super.key,
    required this.meetingId,
    required this.status,
    required this.date,
    required this.time,
    required this.animalName,
    required this.animalImage,
    required this.meetingType,
    required this.contactPhone,
    required this.rescuerId,
    required this.shelterId,
    required this.adopterId,
    required this.role,
  });

  @override
  State<MeetingDetailsPage> createState() => _MeetingDetailsPageState();
}

class _MeetingDetailsPageState extends State<MeetingDetailsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  double? _lat;
  double? _lng;
  bool _loadingLocation = true;
  String? _locationError;

  Color _statusColor(String value) {
    switch (value.toLowerCase().trim()) {
      case 'accepted':
      case 'approved':
      case 'confirmed':
        return _accent;
      case 'pending':
        return _warn;
      case 'rejected':
      case 'cancelled':
        return _reject;
      case 'reschedule requested':
        return _info;
      case 'completed':
        return Colors.teal;
      default:
        return _muted;
    }
  }

  String _formatTimeForDisplay(String value) {
    if (value.trim().isEmpty) return 'TBD';
    final parts = value.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return value;
  }

  String _counterpartLabel() {
    if (widget.role == 'adopter') {
      return 'Shelter/Rescuer: ${widget.shelterId ?? widget.rescuerId ?? 'Unknown'}';
    }
    return 'Adopter: ${widget.adopterId ?? 'Unknown'}';
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = widget.date.isNotEmpty ? widget.date : 'TBD';
    final timeLabel = _formatTimeForDisplay(widget.time);
    final typeLabel = (widget.meetingType ?? '').trim();
    final contactLabel = (widget.contactPhone ?? '').trim();
    final statusColor = _statusColor(widget.status);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text(
          'Meeting Details',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: _primary),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 72,
                    height: 72,
                    color: Colors.grey.shade200,
                    child: (widget.animalImage != null &&
                            widget.animalImage!.isNotEmpty)
                        ? Image.network(widget.animalImage!, fit: BoxFit.cover)
                        : const Icon(Icons.pets, color: _muted),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.animalName ?? 'Unknown pet',
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _counterpartLabel(),
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          widget.status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(label: 'Date', value: dateLabel),
          _InfoRow(label: 'Time', value: timeLabel),
          _InfoRow(label: 'Meeting ID', value: widget.meetingId.toString()),
          if (typeLabel.isNotEmpty) _InfoRow(label: 'Type', value: typeLabel),
          if (contactLabel.isNotEmpty)
            _InfoRow(label: 'Contact', value: contactLabel),
          if (_shouldShowLocation()) ...[
            const SizedBox(height: 16),
            const Text(
              'Location',
              style: TextStyle(
                color: _primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _buildLocationCard(),
          ],
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (_shouldShowLocation()) {
      _loadLocation();
    } else {
      _loadingLocation = false;
    }
  }

  bool _shouldShowLocation() {
    return widget.role == 'adopter' &&
        widget.shelterId != null &&
        widget.shelterId!.isNotEmpty;
  }

  Future<void> _loadLocation() async {
    final targetId = widget.shelterId;
    if (targetId == null || targetId.isEmpty) {
      setState(() {
        _loadingLocation = false;
        _locationError = 'No location available.';
      });
      return;
    }

    try {
      final data =
          await _supabase
              .from('user')
              .select('latitude, longitude')
              .eq('id', targetId)
              .maybeSingle();
      final lat = (data?['latitude'] as num?)?.toDouble();
      final lng = (data?['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) {
        setState(() {
          _loadingLocation = false;
          _locationError = 'No location saved for this user.';
        });
        return;
      }
      setState(() {
        _lat = lat;
        _lng = lng;
        _loadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _loadingLocation = false;
        _locationError = e.toString();
      });
    }
  }

  Widget _buildLocationCard() {
    if (_loadingLocation) {
      return _LocationCard(
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_locationError != null) {
      return _LocationCard(
        child: Center(
          child: Text(
            _locationError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted),
          ),
        ),
      );
    }
    if (_lat == null || _lng == null) {
      return _LocationCard(
        child: const Center(
          child: Text(
            'No location available.',
            style: TextStyle(color: _muted),
          ),
        ),
      );
    }

    final pos = LatLng(_lat!, _lng!);
    return _LocationCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: pos, zoom: 13),
          markers: {
            Marker(
              markerId: const MarkerId('meeting-location'),
              position: pos,
            ),
          },
          zoomControlsEnabled: false,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _stroke),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  final Widget child;
  const _LocationCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }
}
