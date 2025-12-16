import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:strayconnected/screens/user_home_page.dart';
import 'package:strayconnected/widgets/global_bottom_nav.dart';

const Color _bg = Color(0xFFF6F5F5);
const Color _primary = Color(0xFF2D0C57);
const Color _muted = Color(0xFF9586A8);
const Color _stroke = Color(0xFFD8D0E3);
const Color _accent = Color(0xFF0BCE83);

class MeetingRequestsPage extends StatefulWidget {
  const MeetingRequestsPage({super.key});

  @override
  State<MeetingRequestsPage> createState() => _MeetingRequestsPageState();
}

class _MeetingRequestsPageState extends State<MeetingRequestsPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _role = 'user';
  bool _loading = true;
  String? _error;
  List<MeetingItem> _items = const [];
  final Set<int> _updating = {};

  @override
  void initState() {
    super.initState();
    _loadRoleAndData();
  }

  Future<void> _loadRoleAndData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) {
        setState(() {
          _role = 'user';
          _items = const [];
          _loading = false;
        });
        return;
      }
      String role = 'user';
      try {
        final data =
            await _supabase.from('user').select('role').eq('id', uid).maybeSingle();
        role = (data?['role'] as String?) ?? 'user';
      } catch (_) {
        role = 'user';
      }
      final items = await _fetchMeetings(uid: uid, role: role);
      if (!mounted) return;
      setState(() {
        _role = role;
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<List<MeetingItem>> _fetchMeetings({
    required String uid,
    required String role,
  }) async {
    String filterColumn;
    if (role == 'adopter') {
      filterColumn = 'adopter_id';
    } else if (role == 'rescuer') {
      filterColumn = 'rescuer_id';
    } else if (role == 'shelter') {
      filterColumn = 'shelter_id';
    } else {
      return [];
    }

    final response =
        await _supabase
            .from('adoption_meeting')
            .select(
              'meeting_id, date, time, status, animal:animal_id(name, link_picture), adopter_id, rescuer_id, shelter_id',
            )
            .eq(filterColumn, uid)
            .order('date', ascending: true)
            .order('time', ascending: true);

    final list = (response as List)
        .map((raw) => MeetingItem.fromMap(Map<String, dynamic>.from(raw)))
        .toList();
    return list;
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return _accent;
      case 'rejected':
        return Colors.redAccent;
      default:
        return _muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    const double navHeight = 86;
    final title =
        (_role == 'adopter') ? 'My Adoption Requests' : 'Meeting Requests';
    final bool canModerate = _role == 'rescuer' || _role == 'shelter';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadRoleAndData,
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 16, 20, navHeight + 24 + paddingBottom),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: _primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Could not load meetings:\n$_error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  else if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No meeting requests yet.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    )
                  else
                    ..._items.map((item) => _MeetingCard(
                      item: item,
                      statusColor: _statusColor(item.status),
                      showActions: canModerate && item.status.toLowerCase() == 'pending',
                      busy: _updating.contains(item.meetingId),
                      onAccept: () => _updateStatus(item, 'Approved'),
                      onReject: () => _updateStatus(item, 'Rejected'),
                    )),
                ],
              ),
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
                activeTab: BottomNavTab.meetings,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateStatus(MeetingItem item, String status) async {
    setState(() => _updating.add(item.meetingId));
    try {
      await _supabase
          .from('adoption_meeting')
          .update({'status': status})
          .eq('meeting_id', item.meetingId);

      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (m) => m.meetingId == item.meetingId
                  ? m.copyWith(status: status)
                  : m,
            )
            .toList();
        _updating.remove(item.meetingId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked as $status'),
          backgroundColor: status.toLowerCase() == 'approved'
              ? _accent
              : Colors.redAccent,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating.remove(item.meetingId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

class MeetingItem {
  final int meetingId;
  final String status;
  final String date;
  final String time;
  final String? animalName;
  final String? animalImage;
  final String? rescuerId;
  final String? shelterId;
  final String? adopterId;

  MeetingItem({
    required this.meetingId,
    required this.status,
    required this.date,
    required this.time,
    this.animalName,
    this.animalImage,
    this.rescuerId,
    this.shelterId,
    this.adopterId,
  });

  factory MeetingItem.fromMap(Map<String, dynamic> map) {
    final animal = map['animal'] as Map?;
    return MeetingItem(
      meetingId: map['meeting_id'] as int,
      status: (map['status'] as String?) ?? 'Pending',
      date: (map['date'] as String?) ?? '',
      time: (map['time'] as String?) ?? '',
      animalName: animal?['name'] as String?,
      animalImage: animal?['link_picture'] as String?,
      rescuerId: map['rescuer_id'] as String?,
      shelterId: map['shelter_id'] as String?,
      adopterId: map['adopter_id'] as String?,
    );
  }

  MeetingItem copyWith({String? status}) {
    return MeetingItem(
      meetingId: meetingId,
      status: status ?? this.status,
      date: date,
      time: time,
      animalName: animalName,
      animalImage: animalImage,
      rescuerId: rescuerId,
      shelterId: shelterId,
      adopterId: adopterId,
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final MeetingItem item;
  final Color statusColor;
  final bool showActions;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const _MeetingCard({
    required this.item,
    required this.statusColor,
    this.showActions = false,
    this.busy = false,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 64,
                    height: 64,
                    color: Colors.grey.shade200,
                    child: (item.animalImage != null &&
                            item.animalImage!.isNotEmpty)
                        ? Image.network(item.animalImage!, fit: BoxFit.cover)
                        : const Icon(Icons.pets, color: _muted),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.animalName ?? 'Unknown pet',
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.date} • ${item.time}',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.status,
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
          if (showActions)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: busy ? null : onReject,
                    child: const Text(
                      'Reject',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(width: 4),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onPressed: busy ? null : onAccept,
                    child: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Approve'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
