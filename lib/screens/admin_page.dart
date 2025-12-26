import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/data/auth_repository.dart';
import 'package:strayconnected/widgets/global_bottom_nav.dart';

const Color _bg = Color(0xFFF6F5F5);
const Color _primary = Color(0xFF2D0C57);
const Color _muted = Color(0xFF9586A8);
const Color _purple = Color(0xFF5B30B5);
const Color _green = Color(0xFF0BCE83);
const Color _stroke = Color(0xFFD8D0E3);
const List<String> _roleOptions = ['adopter', 'rescuer', 'shelter', 'admin'];

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final AuthRepository _auth = AuthRepository();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _checkingRole = true;
  bool _authorized = false;
  bool _loadingData = false;
  String? _error;

  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _animals = const [];
  List<Map<String, dynamic>> _meetings = const [];
  final Set<String> _updatingUsers = {};
  final Set<String> _removingUsers = {};
  final Set<int> _removingAnimals = {};
  final Set<int> _updatingMeetings = {};

  Future<void> _changeUserRole(String userId, String newRole) async {
    if (userId.isEmpty) return;
    setState(() => _updatingUsers.add(userId));
    try {
      await _supabase
          .from('user')
          .update({'role': newRole})
          .eq('id', userId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role updated to $newRole'),
            backgroundColor: _purple,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update role: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingUsers.remove(userId));
      }
    }
  }

  Future<void> _removeUser(String userId) async {
    if (userId.isEmpty) return;
    setState(() => _removingUsers.add(userId));
    try {
      await _supabase.from('user').delete().eq('id', userId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User removed'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove user: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _removingUsers.remove(userId));
      }
    }
  }

  Future<void> _removeAnimal(int animalId) async {
    if (animalId <= 0) return;
    setState(() => _removingAnimals.add(animalId));
    try {
      await _supabase.from('animal').delete().eq('animal_id', animalId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Animal deleted'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete animal: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _removingAnimals.remove(animalId));
      }
    }
  }

  Future<void> _updateMeetingStatus(int meetingId, String status) async {
    if (meetingId <= 0) return;
    setState(() => _updatingMeetings.add(meetingId));
    try {
      await _supabase
          .from('adoption_meeting')
          .update({'status': status})
          .eq('meeting_id', meetingId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meeting status updated to $status'),
            backgroundColor: _green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update meeting: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updatingMeetings.remove(meetingId));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _checkingRole = true;
      _error = null;
    });
    try {
      final profile = await _auth.getMyProfile();
      final role = profile?['role']?.toString().toLowerCase();
      if (role != 'admin') {
        setState(() {
          _authorized = false;
          _checkingRole = false;
          _error = 'Admin only. Your role: ${role ?? 'unknown'}';
        });
        return;
      }
      setState(() {
        _authorized = true;
      });
      await _loadData();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _checkingRole = false;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _loadingData = true;
      _error = null;
      _checkingRole = false;
    });
    try {
      final usersRaw = await _supabase
          .from('user')
          .select('id, name, email, role, created_at')
          .order('created_at', ascending: false)
          .limit(12);
      final animalsRaw = await _supabase
          .from('animal')
          .select('animal_id, name, species, breed, health_status, link_picture')
          .order('animal_id', ascending: false)
          .limit(12);
      final meetingsRaw = await _supabase
          .from('adoption_meeting')
          .select(
            'meeting_id, status, date, time, animal_id, adopter_id, rescuer_id, shelter_id',
          )
          .order('meeting_id', ascending: false)
          .limit(12);

      if (!mounted) return;
      setState(() {
        _users = _toList(usersRaw);
        _animals = _toList(animalsRaw);
        _meetings = _toList(meetingsRaw);
        _loadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadingData = false;
      });
    }
  }

  List<Map<String, dynamic>> _toList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    const double navHeight = 86;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _primary,
        elevation: 0,
        title: const Text(
          'Admin Console',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            _checkingRole
                ? const Center(child: CircularProgressIndicator(color: _purple))
                : !_authorized
                    ? _AccessDenied(
                        error: _error,
                        onBack: () => Navigator.pop(context),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            navHeight + 24 + MediaQuery.of(context).padding.bottom,
                          ),
                          child: Column(
                            children: [
                              _HeaderRow(
                                loading: _loadingData,
                                onRefresh: _loadData,
                              ),
                              const SizedBox(height: 12),
                              _SummaryRow(
                                users: _users.length,
                                animals: _animals.length,
                                meetings: _meetings.length,
                              ),
                              const SizedBox(height: 18),
                              _AdminSection(
                                title: 'Users',
                                subtitle:
                                    'Change roles (adopter/rescuer/shelter/admin)',
                                child: _UserAdminList(
                                  users: _users,
                                  updating: _updatingUsers,
                                  removing: _removingUsers,
                                  onChangeRole: _changeUserRole,
                                  onRemoveUser: _removeUser,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _AdminSection(
                                title: 'Animals',
                                subtitle: 'Remove listings (destructive)',
                                child: _AnimalAdminList(
                                  animals: _animals,
                                  removing: _removingAnimals,
                                  onRemove: _removeAnimal,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _AdminSection(
                                title: 'Meetings',
                                subtitle: 'Update meeting statuses',
                                child: _MeetingAdminList(
                                  meetings: _meetings,
                                  updating: _updatingMeetings,
                                  onUpdateStatus: _updateMeetingStatus,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _HintCard(
                                title: 'Need deeper controls?',
                                body:
                                    'Use Supabase SQL editor/policies for admin-only mutations. The client intentionally blocks role changes and admin creation.',
                              ),
                            ],
                          ),
                        ),
                      ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GlobalBottomNav(
                canCreate: true, // admin can create
                onCreate: () => Navigator.pushNamed(context, '/createAnimal'),
                onHome: () => Navigator.pushReplacementNamed(context, '/home'),
                onMessages: () =>
                    Navigator.pushReplacementNamed(context, '/chats'),
                onMeetings: () =>
                    Navigator.pushReplacementNamed(context, '/meetings'),
                onProfile: () =>
                    Navigator.pushReplacementNamed(context, '/profile'),
                activeTab: BottomNavTab.profile,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied({required this.error, required this.onBack});

  final String? error;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 48, color: _purple),
          const SizedBox(height: 8),
          const Text(
            'Admin only',
            style: TextStyle(
              color: _primary,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                error!,
                style: const TextStyle(color: _muted),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
            ),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new),
            label: const Text('Go back'),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.loading, required this.onRefresh});

  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Overview',
          style: TextStyle(
            color: _primary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: loading ? null : onRefresh,
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, color: _primary),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.users,
    required this.animals,
    required this.meetings,
  });

  final int users;
  final int animals;
  final int meetings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Users',
            value: users,
            icon: Icons.group,
            color: _purple,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Animals',
            value: animals,
            icon: Icons.pets,
            color: _green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Meetings',
            value: meetings,
            icon: Icons.event,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(color: _muted, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSection extends StatelessWidget {
  const _AdminSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _primary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _UserAdminList extends StatelessWidget {
  const _UserAdminList({
    required this.users,
    required this.updating,
    required this.removing,
    required this.onChangeRole,
    required this.onRemoveUser,
  });

  final List<Map<String, dynamic>> users;
  final Set<String> updating;
  final Set<String> removing;
  final Future<void> Function(String userId, String newRole) onChangeRole;
  final Future<void> Function(String userId) onRemoveUser;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Text('No records found', style: TextStyle(color: _muted));
    }
    return Column(
      children: users.map((u) {
        final id = (u['id'] ?? '').toString();
        final role = (u['role'] ?? '').toString();
        final disabled = updating.contains(id);
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _purple.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person, color: _purple),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u['name'] ?? 'Unnamed user',
                        style: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                              u['email'] ?? '',
                              style: const TextStyle(color: _muted, fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: DropdownButton<String>(
                          isDense: true,
                          value: _roleOptions.contains(role)
                              ? role
                              : _roleOptions.first,
                          onChanged: disabled
                              ? null
                              : (val) {
                                  if (val != null) {
                                    onChangeRole(id, val);
                                  }
                                },
                          items: _roleOptions
                              .map(
                                (r) => DropdownMenuItem(
                                  value: r,
                                  child: Text(
                                    r,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton.icon(
                        onPressed: disabled || removing.contains(id)
                            ? null
                            : () async {
                                final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Remove user?'),
                                        content: const Text(
                                          'This will delete the user and related role records.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ) ??
                                    false;
                                if (ok) onRemoveUser(id);
                              },
                        icon: removing.contains(id)
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text(
                          'Remove',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (u != users.last) const Divider(height: 18, color: _stroke),
          ],
        );
      }).toList(),
    );
  }
}

class _AnimalAdminList extends StatelessWidget {
  const _AnimalAdminList({
    required this.animals,
    required this.removing,
    required this.onRemove,
  });

  final List<Map<String, dynamic>> animals;
  final Set<int> removing;
  final Future<void> Function(int animalId) onRemove;

  @override
  Widget build(BuildContext context) {
    if (animals.isEmpty) {
      return const Text('No records found', style: TextStyle(color: _muted));
    }
    return Column(
      children: animals.map((a) {
        final id = a['animal_id'] is int
            ? a['animal_id'] as int
            : int.tryParse((a['animal_id'] ?? '').toString()) ?? -1;
        final disabled = removing.contains(id);
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.pets, color: _green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a['name'] ?? 'Unnamed animal',
                        style: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(a['species'] ?? '').toString()} ${(a['breed'] ?? '').toString()}'
                            .trim(),
                        style: const TextStyle(color: _muted, fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: disabled
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Remove animal?'),
                                  content: const Text(
                                    'This will permanently delete this listing.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ) ??
                              false;
                          if (ok) onRemove(id);
                        },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: disabled
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                ),
              ],
            ),
            if (a != animals.last) const Divider(height: 18, color: _stroke),
          ],
        );
      }).toList(),
    );
  }
}

class _MeetingAdminList extends StatelessWidget {
  const _MeetingAdminList({
    required this.meetings,
    required this.updating,
    required this.onUpdateStatus,
  });

  final List<Map<String, dynamic>> meetings;
  final Set<int> updating;
  final Future<void> Function(int meetingId, String status) onUpdateStatus;

  static const _statusOptions = [
    'pending',
    'approved',
    'rejected',
    'completed',
  ];

  @override
  Widget build(BuildContext context) {
    if (meetings.isEmpty) {
      return const Text('No records found', style: TextStyle(color: _muted));
    }
    return Column(
      children: meetings.map((m) {
        final id = m['meeting_id'] is int
            ? m['meeting_id'] as int
            : int.tryParse((m['meeting_id'] ?? '').toString()) ?? -1;
        final status = (m['status'] ?? '').toString().toLowerCase();
        final disabled = updating.contains(id);
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.event_available, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meeting $id — ${m['date'] ?? ''} ${m['time'] ?? ''}',
                        style: const TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Animal ${m['animal_id'] ?? '-'} • Adopter ${m['adopter_id'] ?? '-'}',
                        style: const TextStyle(color: _muted, fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: DropdownButton<String>(
                        isDense: true,
                        value: _statusOptions.contains(status)
                            ? status
                            : _statusOptions.first,
                        onChanged: disabled
                            ? null
                            : (val) {
                                if (val != null) {
                                  onUpdateStatus(id, val);
                                }
                              },
                        items: _statusOptions
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(
                                  r,
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (m != meetings.last) const Divider(height: 18, color: _stroke),
          ],
        );
      }).toList(),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(color: _muted, height: 1.35),
          ),
        ],
      ),
    );
  }
}
