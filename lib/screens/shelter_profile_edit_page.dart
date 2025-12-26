import 'package:flutter/material.dart';
import 'package:strayconnected/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShelterProfileEditPage extends StatefulWidget {
  const ShelterProfileEditPage({super.key});

  @override
  State<ShelterProfileEditPage> createState() => _ShelterProfileEditPageState();
}

class _ShelterProfileEditPageState extends State<ShelterProfileEditPage> {
  final AuthRepository _auth = AuthRepository();
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _shelter;
  bool _saving = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _openedOnController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _hoursController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _statusValue;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openedOnController.dispose();
    _locationController.dispose();
    _hoursController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Not logged in';
          _loading = false;
        });
        return;
      }
      final role =
          (await _auth.getMyProfile())?['role']?.toString().toLowerCase();
      if (role != 'shelter') {
        setState(() {
          _error = 'Shelter only';
          _loading = false;
        });
        return;
      }
      final data = await Supabase.instance.client
          .from('shelter')
          .select()
          .eq('shelter_id', user.id)
          .maybeSingle();
      setState(() {
        _shelter = data as Map<String, dynamic>?;
        _hydrateFields();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (_shelter?['shelter_name'] as String?) ?? 'Shelter';
    final rawStatus = (_shelter?['status'] as String?)?.trim();
    final status = (rawStatus == null || rawStatus.isEmpty)
        ? 'Not set'
        : rawStatus;
    final contact = (_shelter?['contact_info'] as String?) ?? '';
    final location = (_shelter?['location'] as String?) ?? '';
    final openRange = _extractOpenRange(contact);
    final description = _extractNotes(contact).join('\n');
    final openedOn = _formatOpenedOn(_shelter?['opened_on']);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F5F5),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                _HeaderBar(
                  title: 'Edit Shelter Profile',
                  onBack: () => Navigator.maybePop(context),
                ),
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(26),
                      topRight: Radius.circular(26),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ProfileCard(
                          name: name,
                          status: status,
                        ),
                        const SizedBox(height: 18),
                        if (_loading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: CircularProgressIndicator(
                                color: Color(0xFF5B30B5),
                              ),
                            ),
                          )
                        else if (_error != null)
                          _ErrorCard(message: _error ?? '')
                        else ...[
                          _LabeledField(
                            label: 'Shelter Name',
                            value: name,
                            controller: _nameController,
                          ),
                          const SizedBox(height: 14),
                          _LabeledField(
                            label: 'Opened since',
                            value: openedOn,
                            controller: _openedOnController,
                            trailing: Icons.calendar_today_outlined,
                          ),
                          const SizedBox(height: 14),
                          _LabeledField(
                            label: 'Status',
                            value: status,
                            controller: null,
                            trailing: null,
                            isDropdown: true,
                            dropdownValue: _statusValue,
                            onDropdownChanged: (val) =>
                                setState(() => _statusValue = val),
                          ),
                          const SizedBox(height: 14),
                          _LabeledField(
                            label: 'Location',
                            value:
                                location.isEmpty ? 'Not set' : location,
                            controller: _locationController,
                          ),
                          const SizedBox(height: 14),
                          _LabeledField(
                            label: 'Operating hours',
                            value: openRange.isEmpty
                                ? 'Not set'
                                : openRange,
                            controller: _hoursController,
                          ),
                          const SizedBox(height: 14),
                          _LabeledField(
                            label: 'Description',
                            value: description.isEmpty
                                ? 'No description yet.'
                                : description,
                            isMultiline: true,
                            controller: _descriptionController,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0ACF83),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed:
                                  _saving ? null : _saveShelterChanges,
                              child: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'SAVE CHANGES',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _extractOpenRange(String contact) {
    final lines = contact.split('\n');
    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.startsWith('open:')) {
        return line.replaceFirst(RegExp('open:\\s*', caseSensitive: false), '');
      }
    }
    return '';
  }

  String _formatOpenedOn(dynamic value) {
    if (value == null) return 'Not set';
    final raw = value.toString().trim();
    if (raw.isEmpty) return 'Not set';
    return raw;
  }

  void _hydrateFields() {
    final name = (_shelter?['shelter_name'] as String?) ?? '';
    final location = (_shelter?['location'] as String?) ?? '';
    final contact = (_shelter?['contact_info'] as String?) ?? '';
    final openRange = _extractOpenRange(contact);
    final description = _extractNotes(contact).join('\n');
    final openedOn = _formatOpenedOn(_shelter?['opened_on']);
    final rawStatus = (_shelter?['status'] as String?)?.trim();
    _nameController.text = name;
    _locationController.text = location;
    _hoursController.text = openRange;
    _descriptionController.text = description;
    _openedOnController.text = openedOn == 'Not set' ? '' : openedOn;
    _statusValue = rawStatus;
  }

  Future<void> _saveShelterChanges() async {
    if (_saving) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final openRange = _hoursController.text.trim();
      final desc = _descriptionController.text.trim();
      final timeLine = openRange.isEmpty ? '' : 'Open: $openRange\n';
      final contactInfo = '$timeLine$desc'.trim();
      DateTime? openedOn;
      if (_openedOnController.text.trim().isNotEmpty) {
        openedOn = DateTime.tryParse(_openedOnController.text.trim());
      }

      final payload = <String, dynamic>{
        'shelter_name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'contact_info': contactInfo,
        'status': _statusValue,
        'opened_on': openedOn,
      };

      await Supabase.instance.client
          .from('shelter')
          .update(payload)
          .eq('shelter_id', user.id);

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save profile: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      setState(() => _saving = false);
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

List<String> _splitContact(String contact) {
  return contact
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

List<String> _extractNotes(String contact) {
  final lines = _splitContact(contact);
  return lines.where((l) => !l.toLowerCase().startsWith('open:')).toList();
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5B30B5), Color(0xFF0BCE83)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.status,
  });

  final String name;
  final String status;

  @override
  Widget build(BuildContext context) {
    final isOpen = status.toLowerCase() == 'open';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.08),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFE7E1F2)),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF5B30B5), Color(0xFF0BCE83)],
              ),
            ),
            child: const Center(
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.pets,
                  color: Color(0xFF5B30B5),
                  size: 30,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D0C57),
                  ),
                ),
                const SizedBox(height: 6),
                _StatusPill(
                  label: status.isEmpty ? 'Not set' : status,
                  color: isOpen ? const Color(0xFF0ACF83) : Colors.grey,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.value,
    this.trailing,
    this.isMultiline = false,
    this.controller,
    this.isDropdown = false,
    this.dropdownValue,
    this.onDropdownChanged,
  });

  final String label;
  final String value;
  final IconData? trailing;
  final bool isMultiline;
  final TextEditingController? controller;
  final bool isDropdown;
  final String? dropdownValue;
  final ValueChanged<String?>? onDropdownChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9586A8),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD9D0E3)),
          ),
          child: isDropdown
              ? DropdownButtonFormField<String>(
                  value: dropdownValue,
                  decoration: const InputDecoration(border: InputBorder.none),
                  hint: const Text(
                    'Select status',
                    style: TextStyle(color: Color(0xFF9586A8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: onDropdownChanged,
                )
              : controller != null
                  ? TextField(
                      controller: controller,
                      maxLines: isMultiline ? null : 1,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        suffixIcon: trailing == null
                            ? null
                            : Icon(trailing,
                                size: 18, color: const Color(0xFF9586A8)),
                      ),
                      style: const TextStyle(
                        color: Color(0xFF2D0C57),
                        fontSize: 15,
                      ),
                    )
                  : Row(
                      crossAxisAlignment: isMultiline
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            value,
                            style: const TextStyle(
                              color: Color(0xFF2D0C57),
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (trailing != null)
                          Icon(trailing,
                              size: 18, color: const Color(0xFF9586A8)),
                      ],
                    ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD1D1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8A3B3B),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
