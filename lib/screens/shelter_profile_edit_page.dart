import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:strayconnected/data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ShelterProfileEditPage extends StatefulWidget {
  const ShelterProfileEditPage({super.key});

  @override
  State<ShelterProfileEditPage> createState() => _ShelterProfileEditPageState();
}

class _ShelterProfileEditPageState extends State<ShelterProfileEditPage> {
  final AuthRepository _auth = AuthRepository();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _didInit = false;
  String? _targetShelterId;
  bool _isAdmin = false;
  bool _isVerified = false;

  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();

  DateTime? _openedOn;
  DateTime? _createdAt;
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;
  String? _statusValue;
  String? _credentialFileName;
  String? _photoFileName;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) {
      _targetShelterId = args;
    }
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
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
      _isAdmin = role == 'admin';
      if (role != 'shelter' && !_isAdmin) {
        setState(() {
          _error = 'Shelter only';
          _loading = false;
        });
        return;
      }
      final targetId = _targetShelterId ?? user.id;
      final data = await Supabase.instance.client
          .from('shelter')
          .select()
          .eq('shelter_id', targetId)
          .maybeSingle();
      _hydrateFields(data as Map<String, dynamic>?);
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _hydrateFields(Map<String, dynamic>? shelter) {
    if (shelter == null) return;
    _nameController.text = (shelter['shelter_name'] as String?) ?? '';
    _locationController.text = (shelter['location'] as String?) ?? '';
    _descriptionController.text = (shelter['description'] as String?) ?? '';
    _phoneController.text = (shelter['contact_info'] as String?) ?? '';
    _statusValue = (shelter['status'] as String?)?.trim();
    _credentialFileName = (shelter['credentials_url'] as String?)?.trim();
    _photoFileName = (shelter['shelter_photo_url'] as String?)?.trim();
    _isVerified = shelter['is_verified'] == true;
    _openedOn = _parseDate(shelter['opened_on']);
    _createdAt = _parseDate(shelter['created_at']);
    _openTime = _parseTime(shelter['operating_hours_start']);
    _closeTime = _parseTime(shelter['operating_hours_end']);
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  TimeOfDay? _parseTime(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  String get _openedOnLabel {
    if (_openedOn == null) return 'Time Opened';
    return '${_openedOn!.year}';
  }

  String get _openTimeLabel {
    if (_openTime == null) return '08:00';
    return _formatTime(_openTime).substring(0, 5);
  }

  String get _closeTimeLabel {
    if (_closeTime == null) return '17:00';
    return _formatTime(_closeTime).substring(0, 5);
  }

  String get _createdAtLabel {
    if (_createdAt == null) return 'Not available';
    return _createdAt!.toIso8601String().split('T').first;
  }

  String get _credentialLabel {
    if (_credentialFileName == null || _credentialFileName!.isEmpty) {
      return 'No credential file';
    }
    return _credentialFileName!;
  }

  Future<void> _pickOpenedOn() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _openedOn ?? DateTime(now.year - 1, now.month, now.day),
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _openedOn = picked);
    }
  }

  Future<void> _pickOpenTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _openTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      setState(() => _openTime = picked);
    }
  }

  Future<void> _pickCloseTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _closeTime ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (picked != null) {
      setState(() => _closeTime = picked);
    }
  }

  Future<void> _pickPhoto() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() => _photoFileName = res.files.first.name);
    }
  }

  Future<void> _pickCredentials() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg'],
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() => _credentialFileName = res.files.first.name);
    }
  }

  Future<void> _viewCredentialFile() async {
    final url = _credentialFileName;
    if (url == null || url.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No credential file'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid credential file link'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open credential file'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final targetId = _targetShelterId ?? user.id;
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'shelter_id': targetId,
        'shelter_name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'contact_info': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'opened_on': _openedOn?.toIso8601String().split('T').first,
        'status': _statusValue,
        'operating_hours_start':
            _openTime == null ? null : _formatTime(_openTime),
        'operating_hours_end':
            _closeTime == null ? null : _formatTime(_closeTime),
        'credentials_url': _credentialFileName,
        'shelter_photo_url': _photoFileName,
      };

      await Supabase.instance.client.from('shelter').upsert(payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save profile: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setVerification(bool approve) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final targetId = _targetShelterId ?? user.id;
    try {
      await Supabase.instance.client
          .from('shelter')
          .update({'is_verified': approve})
          .eq('shelter_id', targetId);
      setState(() {
        _isVerified = approve;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Shelter verified' : 'Verification removed'),
          backgroundColor: approve ? Colors.green : Colors.redAccent,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update verification: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6F5F5);
    final descCount = _descriptionController.text.length;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  onBack: () => Navigator.maybePop(context),
                ),
                const SizedBox(height: 18),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: CircularProgressIndicator(
                        color: Color(0xFF5B30B5),
                      ),
                    ),
                  )
                else if (_error != null)
                  _ErrorCard(message: _error ?? '')
                else ...[
                  _DashedBorder(
                    color: const Color(0xFFD8D0E3),
                    radius: 14,
                    dash: 6,
                    gap: 4,
                    child: Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F1F7),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.04),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF5B30B5),
                            side: const BorderSide(color: Color(0xFFD8D0E3)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _pickPhoto,
                          icon: const Icon(Icons.upload),
                          label: Text(
                            _photoFileName ?? 'Upload Shelter Photo',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const _HelperText(
                    'This photo will be shown on your public shelter profile.',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isVerified
                              ? const Color(0x330ACF83)
                              : const Color(0x33FF1744),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isVerified ? Icons.verified_outlined : Icons.report,
                              size: 16,
                              color: _isVerified
                                  ? const Color(0xFF0ACF83)
                                  : Colors.redAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isVerified ? 'Verified' : 'Not verified',
                              style: TextStyle(
                                color: _isVerified
                                    ? const Color(0xFF0ACF83)
                                    : Colors.redAccent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isAdmin) ...[
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: () => _setVerification(true),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF0ACF83)),
                            foregroundColor: const Color(0xFF0ACF83),
                          ),
                          child: const Text('Approve'),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          onPressed: () => _setVerification(false),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            foregroundColor: Colors.redAccent,
                          ),
                          child: const Text('Reject'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle('Shelter Details'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _LabeledBox(
                          label: 'Shelter Name',
                          child: TextField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Shelter Name',
                              hintStyle: TextStyle(color: Color(0xFFB0A3C6)),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LabeledBox(
                          label: 'Time Opened',
                          child: InkWell(
                            onTap: _pickOpenedOn,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: SizedBox(
                                height: 48,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _openedOnLabel,
                                        style: const TextStyle(
                                          color: Color(0xFF2D0C57),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.expand_more,
                                      color: Color(0xFF9586A8),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'This name will be visible to adopters.',
                    style: TextStyle(color: Color(0xFF9586A8), fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _LabeledBox(
                          label: 'Credential file',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            child: Text(
                              _credentialLabel,
                              style: const TextStyle(
                                color: Color(0xFF2D0C57),
                                fontSize: 15,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _viewCredentialFile,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('View credential'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _LabeledBox(
                    label: 'Phone Number',
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Add phone number',
                        hintStyle: TextStyle(color: Color(0xFFB0A3C6)),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _LabeledBox(
                          label: 'Status',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: DropdownButtonFormField<String>(
                              value: _statusValue,
                              isExpanded: true,
                              decoration:
                                  const InputDecoration(border: InputBorder.none),
                              hint: const Text(
                                'Select status',
                                style: TextStyle(color: Color(0xFFB0A3C6)),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'open',
                                  child: Text('Open'),
                                ),
                                DropdownMenuItem(
                                  value: 'closed',
                                  child: Text('Temporarily Closed'),
                                ),
                                DropdownMenuItem(
                                  value: 'limited_operation',
                                  child: Text('Limited Operation'),
                                ),
                              ],
                              onChanged: (val) =>
                                  setState(() => _statusValue = val),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LabeledBox(
                          label: 'Upload Credentials',
                          height: 80,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF5B30B5),
                                side: const BorderSide(color: Color(0xFFD8D0E3)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: _pickCredentials,
                              icon: const Icon(Icons.upload_file),
                              label: Text(
                                _credentialFileName ?? 'Upload Credentials',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: const [
                      Expanded(
                        child: Text(
                          'Controls whether adopters can request meetings.',
                          style: TextStyle(
                            color: Color(0xFF9586A8),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Accepted: PDF, JPG',
                          style: TextStyle(
                            color: Color(0xFF9586A8),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  const _SectionTitle('Operations'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _LabeledBox(
                          label: 'Operating Hours',
                          child: InkWell(
                            onTap: _pickOpenTime,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: SizedBox(
                                height: 48,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _openTimeLabel,
                                    style: const TextStyle(
                                      color: Color(0xFF2D0C57),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _LabeledBox(
                          label: ' ',
                          child: InkWell(
                            onTap: _pickCloseTime,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: SizedBox(
                                height: 48,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    _closeTimeLabel,
                                    style: const TextStyle(
                                      color: Color(0xFF2D0C57),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _LabeledBox(
                    label: 'Location',
                    child: TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'City or district',
                        hintStyle: TextStyle(color: Color(0xFFB0A3C6)),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _SectionTitle('About Your Shelter'),
                  const SizedBox(height: 10),
                  _LabeledBox(
                    label: 'Description',
                    height: 150,
                    child: TextField(
                      controller: _descriptionController,
                      maxLines: null,
                      maxLength: 300,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText:
                            "Describe your shelter's mission, policies, or adoption process",
                        hintStyle: TextStyle(color: Color(0xFFB0A3C6)),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$descCount / 300',
                      style: const TextStyle(
                        color: Color(0xFF9586A8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _PrimaryButton(
                    label: 'CONFIRM',
                    onPressed: _saving ? null : _save,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Color(0xFF5B30B5),
                ),
              ),
              Image.asset(
                'assets/images/LOGO.png',
                width: 100,
                height: 100,
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Manage Shelter',
          style: TextStyle(
            color: Color(0xFF2D0C57),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          "Update your shelter's public information",
          style: TextStyle(
            color: Color(0xFF9586A8),
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF5B30B5),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _LabeledBox extends StatelessWidget {
  const _LabeledBox({
    required this.label,
    required this.child,
    this.height = 69,
    this.helperText,
  });

  final String label;
  final Widget child;
  final double height;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9586A8),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 6),
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE4E2EE)),
          ),
          alignment: Alignment.centerLeft,
          child: child,
        ),
        if (helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            helperText!,
            style: const TextStyle(color: Color(0xFF9586A8), fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0ACF83),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            letterSpacing: -0.01,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _HelperText extends StatelessWidget {
  const _HelperText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF9586A8),
        fontSize: 12,
      ),
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

class _DashedBorder extends StatelessWidget {
  const _DashedBorder({
    required this.child,
    required this.color,
    this.radius = 12,
    this.strokeWidth = 1.2,
    this.dash = 6,
    this.gap = 4,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
      ),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dash != dash ||
        oldDelegate.gap != gap;
  }
}
