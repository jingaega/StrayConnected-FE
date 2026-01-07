import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/screens/meeting_confirmation_page.dart';
import 'package:strayconnected/screens/user_home_page.dart';
import 'package:strayconnected/strayconnected.dart';

const Color _bg = Color(0xFFF6F5F5);
const Color _primary = Color(0xFF2D0C57);
const Color _muted = Color(0xFF9586A8);
const Color _stroke = Color(0xFFD8D0E3);
const Color _accent = Color(0xFF0ACF83);

class ArrangeAdoptionPage extends StatefulWidget {
  final Pet pet;
  final bool isAdopter;
  final String? shelterId;
  final String? rescuerId;

  const ArrangeAdoptionPage({
    super.key,
    required this.pet,
    required this.isAdopter,
    this.shelterId,
    this.rescuerId,
  });

  @override
  State<ArrangeAdoptionPage> createState() => _ArrangeAdoptionPageState();
}

class _ArrangeAdoptionPageState extends State<ArrangeAdoptionPage> {
  final TextEditingController _dateCtrl = TextEditingController();
  final TextEditingController _timeCtrl = TextEditingController();
  final TextEditingController _meetingCtrl = TextEditingController();
  final TextEditingController _contactCtrl = TextEditingController();
  String _meetingType = 'In Person';
  bool _isSubmitting = false;
  final SupabaseClient _supabase = Supabase.instance.client;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  static final RegExp _indoPhoneFull = RegExp(
    r'^(?:\+62|0)8[1-9][0-9]{7,10}$',
  );
  static const int _maxPhoneBodyLength = 12;
  late final TextInputFormatter _indonesianPhoneFormatter =
      TextInputFormatter.withFunction((oldValue, newValue) {
        final text = newValue.text;
        if (_isValidIndonesianPhonePartial(text)) {
          return newValue;
        }
        return oldValue;
      });

  @override
  void dispose() {
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _meetingCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose date and time.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (_contactCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a contact number.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final contact = _contactCtrl.text.trim();
    if (!_isValidIndonesianPhone(contact)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter a valid Indonesian phone number (e.g. 08xx or +628xx).',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (!widget.isAdopter) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only adopters can arrange an adoption meeting.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    final adopterId = _supabase.auth.currentUser?.id;
    if (adopterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in first.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      await _supabase.from('adopter').upsert({'adopter_id': adopterId});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not verify adopter profile: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final payload = <String, dynamic>{
      'adopter_id': adopterId,
      'animal_id': widget.pet.animalId,
      'date': _formatDateForDb(_selectedDate!),
      'time': _formatTimeForDb(_selectedTime!),
      'status': 'Pending',
      'meeting_type': _meetingType,
      'contact_phone': contact,
      if (widget.rescuerId != null && widget.rescuerId!.isNotEmpty)
        'rescuer_id': widget.rescuerId,
      if (widget.shelterId != null && widget.shelterId!.isNotEmpty)
        'shelter_id': widget.shelterId,
    };

    setState(() => _isSubmitting = true);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => BackgroundWrapper(
              child: MeetingConfirmationPage(
                onEdit: _handleEditRequest,
                onConfirm: (ctx) => _handleConfirmRequest(ctx, payload),
              ),
            ),
      ),
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
  }

  void _handleEditRequest() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _handleConfirmRequest(
    BuildContext context,
    Map<String, dynamic> payload,
  ) async {
    try {
      await _supabase.from('adoption_meeting').insert(payload);
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, '/meetings');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create meeting: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
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
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = _formatDate(picked);
      });
    }
  }

  Future<void> _showTimeSheet() async {
    final options = _buildTimeOptions();
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: options.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final label = options[index];
              final slot = _timeFromLabel(label);
              return ListTile(
                title: Text(label),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedTime = slot;
                    _timeCtrl.text = label;
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  List<String> _buildTimeOptions() {
    final List<String> slots = [];
    TimeOfDay t = const TimeOfDay(hour: 8, minute: 0);
    while (t.hour < 21) {
      slots.add(_formatTime(t));
      final totalMinutes = t.hour * 60 + t.minute + 30;
      t = TimeOfDay(hour: totalMinutes ~/ 60, minute: totalMinutes % 60);
    }
    return slots;
  }

  String _formatDate(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';

  String _formatDateForDb(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final suffix = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }

  String _formatTimeForDb(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  TimeOfDay _timeFromLabel(String label) {
    final parts = label.split(' ');
    if (parts.length != 2) return const TimeOfDay(hour: 12, minute: 0);
    final hm = parts.first.split(':');
    if (hm.length != 2) return const TimeOfDay(hour: 12, minute: 0);
    int hour = int.tryParse(hm.first) ?? 12;
    final minute = int.tryParse(hm.last) ?? 0;
    final isPm = parts.last.toUpperCase() == 'PM';
    if (hour == 12) {
      hour = isPm ? 12 : 0;
    } else if (isPm) {
      hour += 12;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  static bool _isValidIndonesianPhone(String value) {
    return _indoPhoneFull.hasMatch(value);
  }

  static bool _isValidIndonesianPhonePartial(String value) {
    if (value.isEmpty) return true;
    if (value == '+' || value == '+6' || value == '+62') return true;
    if (value.startsWith('+')) {
      if (!value.startsWith('+62')) return false;
      final body = value.substring(3);
      return _isValidIndonesianPhoneBodyPartial(body);
    }
    if (value.startsWith('0')) {
      final body = value.substring(1);
      return _isValidIndonesianPhoneBodyPartial(body);
    }
    return false;
  }

  static bool _isValidIndonesianPhoneBodyPartial(String body) {
    if (body.isEmpty) return true;
    if (!RegExp(r'^\d+$').hasMatch(body)) return false;
    if (body.length > _maxPhoneBodyLength) return false;
    return body.startsWith('8');
  }

  @override
  Widget build(BuildContext context) {
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    final pet = widget.pet;
    final String ageLabel = pet.ageLabelShort;
    final String traitLine = [
      if (pet.breed != null && pet.breed!.isNotEmpty) pet.breed,
      if (pet.species != null && pet.species!.isNotEmpty) pet.species,
      '20km away',
    ].whereType<String>().join(' - ');

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                120,
                20,
                140 + paddingBottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Arrange Adoption',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.37,
                      letterSpacing: 0.41,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _HeroCard(pet: pet),
                  const SizedBox(height: 20),
                  Text(
                    pet.name,
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.37,
                      letterSpacing: 0.41,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        ageLabel,
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          traitLine,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            height: 1.6,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Vaccinated and Healthy',
                    style: TextStyle(
                      color: Color(0xFF05BE77),
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      letterSpacing: -0.41,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          label: 'Date',
                          controller: _dateCtrl,
                          hint: 'Select date',
                          readOnly: true,
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Field(
                          label: 'Meeting Type',
                          controller: _meetingCtrl,
                          hint: 'Choose type',
                          readOnly: true,
                          onTap: _showMeetingTypeSheet,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _Field(
                          label: 'Time',
                          controller: _timeCtrl,
                          hint: 'Select time',
                          readOnly: true,
                          onTap: _showTimeSheet,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Field(
                          label: 'Contacts (Phone Number)',
                          controller: _contactCtrl,
                          hint: 'Add phone',
                          keyboardType: TextInputType.phone,
                          inputFormatters: [_indonesianPhoneFormatter],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 32 + paddingBottom,
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      widget.isAdopter ? _accent : Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed:
                    _isSubmitting || !widget.isAdopter ? null : _confirm,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'CONFIRM',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.01,
                        ),
                      ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 96,
            child: Container(
              decoration: BoxDecoration(
                color: _bg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: _primary),
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Back',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMeetingTypeSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final options = ['In Person', 'Virtual Call', 'Shelter Visit'];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
              return ListTile(
                title: Text(opt),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _meetingType = opt;
                    _meetingCtrl.text = opt;
                  });
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool readOnly;
  final TextInputType? keyboardType;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.readOnly = false,
    this.keyboardType,
    this.onTap,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.4,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: keyboardType,
          onTap: onTap,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _stroke, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _primary, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Pet pet;
  const _HeroCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          image: DecorationImage(
            image:
                (pet.primaryImageUrl != null &&
                        pet.primaryImageUrl!.isNotEmpty)
                    ? NetworkImage(pet.primaryImageUrl!) as ImageProvider
                : const AssetImage('assets/images/catlogo.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(0.5, 0.0),
                    end: const Alignment(0.5, 1.0),
                    colors: [
                      Colors.black.withOpacity(0.15),
                      Colors.black.withOpacity(0.30),
                      Colors.black.withOpacity(0.55),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Arrange a meet & greet to proceed with adoption.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
