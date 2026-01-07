import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/screens/meeting_details_page.dart';
import 'package:strayconnected/widgets/global_bottom_nav.dart';

const Color _bg = Color(0xFFF6F5F5);
const Color _primary = Color(0xFF2D0C57);
const Color _muted = Color(0xFF9586A8);
const Color _stroke = Color(0xFFD8D0E3);
const Color _accent = Color(0xFF0BCE83);
const Color _warn = Color(0xFFFFB04C);
const Color _reject = Colors.redAccent;
const Color _info = Color(0xFF5B30B5);

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
              'meeting_id, date, time, status, meeting_type, contact_phone, animal:animal_id(name, link_picture), adopter_id, rescuer_id, shelter_id',
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

  @override
  Widget build(BuildContext context) {
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    const double navHeight = 86;
    final title =
        (_role == 'adopter') ? 'My Adoption Requests' : 'Meeting Requests';

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
                    ..._items.map(
                      (item) => _MeetingCard(
                        item: item,
                        statusColor: _statusColor(item.status),
                        role: _role,
                        busy: _updating.contains(item.meetingId),
                        onAccept: () => _updateStatus(item, 'Accepted'),
                        onReject: () => _updateStatus(item, 'Rejected'),
                        onReschedule: _updating.contains(item.meetingId)
                            ? null
                            : () => _requestReschedule(item),
                        onChat: () => Navigator.pushReplacementNamed(context, '/chats'),
                        onEdit: _updating.contains(item.meetingId)
                            ? null
                            : () => _editMeeting(item),
                        onCancel: () => _updateStatus(item, 'Cancelled'),
                        onViewDetails: () => _openDetails(item),
                      ),
                    ),
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
                onShelterProfile: () =>
                    Navigator.pushReplacementNamed(context, '/shelterProfile'),
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
          backgroundColor: status.toLowerCase() == 'accepted'
              ? _accent
              : (status.toLowerCase() == 'rejected' ? _reject : _info),
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

  void _showToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _openDetails(MeetingItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MeetingDetailsPage(
          meetingId: item.meetingId,
          status: item.status,
          date: item.date,
          time: item.time,
          animalName: item.animalName,
          animalImage: item.animalImage,
          meetingType: item.meetingType,
          contactPhone: item.contactPhone,
          rescuerId: item.rescuerId,
          shelterId: item.shelterId,
          adopterId: item.adopterId,
          role: _role,
        ),
      ),
    );
  }

  Future<void> _requestReschedule(MeetingItem item) async {
    final picked = await _pickMeetingDateTime(item);
    if (picked == null) return;

    final dateForDb = _formatDateForDb(picked.date);
    final timeForDb = _formatTimeForDb(picked.time);

    setState(() => _updating.add(item.meetingId));
    try {
      await _supabase
          .from('adoption_meeting')
          .update({
            'date': dateForDb,
            'time': timeForDb,
            'status': 'Reschedule Requested',
          })
          .eq('meeting_id', item.meetingId);

      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (m) => m.meetingId == item.meetingId
                  ? m.copyWith(
                      status: 'Reschedule Requested',
                      date: dateForDb,
                      time: timeForDb,
                    )
                  : m,
            )
            .toList();
        _updating.remove(item.meetingId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reschedule requested.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating.remove(item.meetingId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not request reschedule: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _editMeeting(MeetingItem item) async {
    final picked = await _pickMeetingDateTime(item);
    if (picked == null) return;

    final dateForDb = _formatDateForDb(picked.date);
    final timeForDb = _formatTimeForDb(picked.time);

    setState(() => _updating.add(item.meetingId));
    try {
      await _supabase
          .from('adoption_meeting')
          .update({'date': dateForDb, 'time': timeForDb})
          .eq('meeting_id', item.meetingId);

      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (m) => m.meetingId == item.meetingId
                  ? m.copyWith(date: dateForDb, time: timeForDb)
                  : m,
            )
            .toList();
        _updating.remove(item.meetingId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meeting request updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating.remove(item.meetingId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update meeting: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<_MeetingDateTime?> _pickMeetingDateTime(MeetingItem item) async {
    final initialDate = _parseDate(item.date) ?? DateTime.now();
    final initialTime = _parseTime(item.time) ?? TimeOfDay.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _primary,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: _primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _primary,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (pickedTime == null) return null;
    return _MeetingDateTime(date: pickedDate, time: pickedTime);
  }
}

class MeetingItem {
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

  MeetingItem({
    required this.meetingId,
    required this.status,
    required this.date,
    required this.time,
    this.animalName,
    this.animalImage,
    this.meetingType,
    this.contactPhone,
    this.rescuerId,
    this.shelterId,
    this.adopterId,
  });

  factory MeetingItem.fromMap(Map<String, dynamic> map) {
    final animal = map['animal'] as Map?;
    final imageUrls = _parseImageUrls(animal?['link_picture']);
    return MeetingItem(
      meetingId: _parseMeetingId(map['meeting_id']),
      status: (map['status'] as String?) ?? 'Pending',
      date: (map['date'] as String?) ?? '',
      time: (map['time'] as String?) ?? '',
      animalName: animal?['name'] as String?,
      animalImage: imageUrls.isNotEmpty ? imageUrls.first : null,
      meetingType: (map['meeting_type'] as String?)?.trim(),
      contactPhone: (map['contact_phone'] as String?)?.trim(),
      rescuerId: map['rescuer_id'] as String?,
      shelterId: map['shelter_id'] as String?,
      adopterId: map['adopter_id'] as String?,
    );
  }

  MeetingItem copyWith({String? status, String? date, String? time}) {
    return MeetingItem(
      meetingId: meetingId,
      status: status ?? this.status,
      date: date ?? this.date,
      time: time ?? this.time,
      animalName: animalName,
      animalImage: animalImage,
      meetingType: meetingType,
      contactPhone: contactPhone,
      rescuerId: rescuerId,
      shelterId: shelterId,
      adopterId: adopterId,
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final MeetingItem item;
  final Color statusColor;
  final bool busy;
  final String role;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onReschedule;
  final VoidCallback? onChat;
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onViewDetails;

  const _MeetingCard({
    required this.item,
    required this.statusColor,
    required this.role,
    this.busy = false,
    this.onAccept,
    this.onReject,
    this.onReschedule,
    this.onChat,
    this.onEdit,
    this.onCancel,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAdopter = role == 'adopter';
    final bool isModerator = role == 'rescuer' || role == 'shelter';
    final statusLower = item.status.toLowerCase().trim();

    Widget actionRow() {
      if (isAdopter) {
        switch (statusLower) {
          case 'pending':
            return _AdopterActions(
              onEdit: onEdit,
              onCancel: onCancel,
              onChat: onChat,
            );
          case 'accepted':
          case 'approved':
          case 'confirmed':
            return _AdopterAcceptedActions(
              onViewDetails: onViewDetails,
              onChat: onChat,
            );
          case 'rejected':
            return _AdopterRejectedActions(onReschedule: onReschedule);
          case 'reschedule requested':
            return _AdopterRescheduleActions(onReschedule: onReschedule);
          case 'cancelled':
          case 'completed':
            return _ChatOnlyActions(onChat: onChat);
          default:
            return _ChatOnlyActions(onChat: onChat);
        }
      }
      if (isModerator &&
          (statusLower == 'pending' || statusLower == 'reschedule requested')) {
        return _ModeratorActions(
          busy: busy,
          onAccept: onAccept,
          onReject: onReject,
          onReschedule: onReschedule,
          onChat: onChat,
        );
      }
      return _ModeratorActions(
        busy: busy,
        onAccept: null,
        onReject: null,
        onReschedule: null,
        onChat: onChat,
      );
    }

    String counterpart() {
      if (isAdopter) {
        return 'Shelter/Rescuer: ${(item.shelterId ?? item.rescuerId ?? 'Unknown').toString()}';
      }
      return 'Adopter: ${(item.adopterId ?? 'Unknown').toString()}';
    }

    final dateLabel = item.date.isNotEmpty ? item.date : 'TBD';
    final timeLabel = _formatTimeForDisplay(item.time);
    final meetingType = (item.meetingType ?? '').trim();
    final contactPhone = (item.contactPhone ?? '').trim();

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
                      const SizedBox(height: 2),
                      Text(
                        counterpart(),
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: $dateLabel • Time: $timeLabel',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 13,
                        ),
                      ),
                      if (meetingType.isNotEmpty || contactPhone.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            [
                              if (meetingType.isNotEmpty)
                                'Type: $meetingType',
                              if (contactPhone.isNotEmpty)
                                'Contact: $contactPhone',
                            ].join(' • '),
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12,
                            ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(color: _stroke, height: 14),
                const SizedBox(height: 4),
                actionRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeratorActions extends StatelessWidget {
  const _ModeratorActions({
    required this.busy,
    this.onAccept,
    this.onReject,
    this.onReschedule,
    this.onChat,
  });

  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onReschedule;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (onChat != null)
          TextButton.icon(
            onPressed: onChat,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Message'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
            ),
          ),
        TextButton(
          onPressed: busy ? null : onReject,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          ),
          child: const Text('Reject', style: TextStyle(color: _reject)),
        ),
        TextButton(
          onPressed: busy ? null : onReschedule,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          ),
          child: const Text('Reschedule'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
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
              : const Text('Accept'),
        ),
      ],
    );
  }
}

class _AdopterActions extends StatelessWidget {
  const _AdopterActions({this.onEdit, this.onCancel, this.onChat});
  final VoidCallback? onEdit;
  final VoidCallback? onCancel;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (onChat != null)
          TextButton.icon(
            onPressed: onChat,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Message'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
            ),
          ),
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          ),
          onPressed: onEdit,
          child: const Text('Edit request'),
        ),
      ],
    );
  }
}

class _AdopterAcceptedActions extends StatelessWidget {
  const _AdopterAcceptedActions({this.onViewDetails, this.onChat});
  final VoidCallback? onViewDetails;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (onChat != null)
          TextButton.icon(
            onPressed: onChat,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Message'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
            ),
          ),
        TextButton(
          onPressed: onViewDetails,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          ),
          child: const Text('View details'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          ),
          onPressed: onViewDetails,
          child: const Text('Get directions'),
        ),
      ],
    );
  }
}

class _AdopterRejectedActions extends StatelessWidget {
  const _AdopterRejectedActions({this.onReschedule});
  final VoidCallback? onReschedule;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _info,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          ),
          onPressed: onReschedule,
          child: const Text('Request another time'),
        ),
      ],
    );
  }
}

class _AdopterRescheduleActions extends StatelessWidget {
  const _AdopterRescheduleActions({this.onReschedule});
  final VoidCallback? onReschedule;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _info,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          ),
          onPressed: onReschedule,
          child: const Text('Pick a new time'),
        ),
      ],
    );
  }
}

class _ChatOnlyActions extends StatelessWidget {
  const _ChatOnlyActions({this.onChat});
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (onChat != null)
          TextButton.icon(
            onPressed: onChat,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Message'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
            ),
          ),
      ],
    );
  }
}

List<String> _parseImageUrls(Object? raw) {
  if (raw == null) return [];
  if (raw is List) {
    return raw
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return [];
    if (trimmed.startsWith('[')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .whereType<String>()
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    return [trimmed];
  }
  return [];
}

DateTime? _parseDate(String value) {
  if (value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}

TimeOfDay? _parseTime(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

int _parseMeetingId(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? -1;
  return -1;
}

String _formatDateForDb(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _formatTimeForDb(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

String _formatTimeForDisplay(String value) {
  if (value.trim().isEmpty) return 'TBD';
  final parts = value.split(':');
  if (parts.length >= 2) {
    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }
  return value;
}

class _MeetingDateTime {
  final DateTime date;
  final TimeOfDay time;

  const _MeetingDateTime({required this.date, required this.time});
}
