import 'package:flutter/material.dart';
import 'package:strayconnected/data/auth_repository.dart';
import 'package:strayconnected/screens/admin_console_page.dart';

const Color _bg = Color(0xFFF6F5F5);
const Color _primary = Color(0xFF2D0C57);
const Color _muted = Color(0xFF9586A8);
const Color _purple = Color(0xFF5B30B5);
const Color _green = Color(0xFF0BCE83);
const Color _stroke = Color(0xFFD8D0E3);

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final AuthRepository _auth = AuthRepository();

  bool _checkingRole = true;
  bool _authorized = false;
  String? _error;

  void _monitorListings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AdminConsolePage(),
      ),
    );
  }

  void _openHealthValidation() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Validate Health Info',
              style: TextStyle(
                color: _primary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Admins confirm or reject health updates. Mark as authentic when verified, or reject as incomplete/non-authentic.',
              style: TextStyle(color: _muted),
            ),
            const SizedBox(height: 4),
            const Text(
              'Use uploaded PDF health reports as the source of truth before confirming.',
              style: TextStyle(color: _muted, fontSize: 12.5),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _green),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Health info marked as authentic'),
                        backgroundColor: _green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('Confirm authentic'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Health info flagged as non-authentic'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  },
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openPlatformOversight() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Validating shelter info from PDFs and monitoring listings'),
        backgroundColor: _purple,
      ),
    );
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
        _checkingRole = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _checkingRole = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingRole) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: _purple),
        ),
      );
    }

    if (!_authorized) {
      return Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: _AccessDenied(
            error: _error,
            onBack: () => Navigator.pop(context),
          ),
        ),
      );
    }

    return const AdminConsolePage();
  }
}

class _GovernancePanel extends StatelessWidget {
  const _GovernancePanel({
    required this.onMonitorListings,
    required this.onValidateHealth,
    required this.onPlatformOversight,
  });

  final VoidCallback onMonitorListings;
  final VoidCallback onValidateHealth;
  final VoidCallback onPlatformOversight;

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
          const Text(
            'Governance & Validation',
            style: TextStyle(
              color: _primary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Monitor listings, validate health authenticity, and oversee platform compliance.',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Column(
            children: [
              _ActionTile(
                icon: Icons.fact_check_outlined,
                color: _purple,
                title: 'Monitor listings',
                subtitle: 'Review/flag incorrect listings & support corrections',
                onTap: onMonitorListings,
              ),
              const Divider(height: 16, color: _stroke),
              _ActionTile(
                icon: Icons.health_and_safety_outlined,
                color: _green,
                title: 'Validate health info',
                subtitle:
                    'Confirm authenticity from uploaded PDF health reports; reject if incomplete',
                onTap: onValidateHealth,
              ),
              const Divider(height: 16, color: _stroke),
              _ActionTile(
                icon: Icons.verified_user_outlined,
                color: Colors.orange,
                title: 'Platform oversight',
                subtitle: 'Validate shelter documentation from PDFs and monitor platform',
                onTap: onPlatformOversight,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: _muted),
        ],
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
    required this.animals,
    required this.meetings,
  });

  final int animals;
  final int meetings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
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
