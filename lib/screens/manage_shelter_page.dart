import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:strayconnected/data/auth_repository.dart';
import 'package:strayconnected/screens/location_picker_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManageShelterPage extends StatefulWidget {
  const ManageShelterPage({super.key, this.pendingRegistration});

  final Map<String, dynamic>? pendingRegistration;

  @override
  State<ManageShelterPage> createState() => _ManageShelterPageState();
}

class _ManageShelterPageState extends State<ManageShelterPage> {
  final AuthRepository _auth = AuthRepository();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;
  String? _statusValue;
  String? _credentialFileName;
  List<PlatformFile> _photoFiles = const [];
  double? _lat;
  double? _lng;
  bool _hoursTouched = false;
  bool _checkingAccess = true;
  bool _saving = false;
  bool _isPendingRegistration = false;
  bool _showErrors = false;
  int _currentStep = 0;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _isPendingRegistration = widget.pendingRegistration != null;
    if (_isPendingRegistration) {
      final name = widget.pendingRegistration?['name'] as String?;
      if (name != null && name.trim().isNotEmpty) {
        _nameController.text = name.trim();
      }
      setState(() => _checkingAccess = false);
    } else {
      _checkAccess();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _checkAccess() async {
    try {
      final profile = await _auth.getMyProfile();
      final role = (profile?['role'] as String?)?.toLowerCase().trim() ?? '';
      if (!mounted) return;
      if (role != 'shelter') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Shelter profile is only available for shelter accounts.',
            ),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.pop(context);
        return;
      }
      final name = (profile?['name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) {
        _nameController.text = name;
      }
      final lat = (profile?['latitude'] as num?)?.toDouble();
      final lng = (profile?['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        _lat = lat;
        _lng = lng;
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not verify access.'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.redAccent,
        ),
      );
      Navigator.pop(context);
      return;
    } finally {
      if (mounted) setState(() => _checkingAccess = false);
    }
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );
    if (result != null) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
        _locationController.text = result.address;
      });
    }
  }

  Future<void> _pickPhotos() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() => _photoFiles = res.files);
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

  Future<void> _pickOpenTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _openTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _openTime = picked;
        _hoursTouched = true;
      });
    }
  }

  Future<void> _pickCloseTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _closeTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _closeTime = picked;
        _hoursTouched = true;
      });
    }
  }

  void _handleBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep -= 1);
      return;
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    if (_isPendingRegistration) {
      Navigator.pushReplacementNamed(context, '/registerRole');
      return;
    }
    Navigator.pushReplacementNamed(context, '/profile');
  }

  bool get _isStep1Complete {
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();
    final status = _statusValue?.trim() ?? '';
    return name.isNotEmpty && location.isNotEmpty && status.isNotEmpty;
  }

  String? _statusForDb() {
    if (_statusValue == null) return null;
    if (_statusValue == 'temporarily_closed') return 'closed';
    return _statusValue;
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return '';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  Future<void> _handleConfirm() async {
    setState(() => _showErrors = true);
    if (!_isStep1Complete) {
      return;
    }
    if (!_hoursTouched && _openTime == null && _closeTime == null) {
      _openTime = const TimeOfDay(hour: 8, minute: 0);
      _closeTime = const TimeOfDay(hour: 17, minute: 0);
      _hoursTouched = true;
    }
    if (_hoursTouched && (_openTime == null || _closeTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select both opening and closing times.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    String? uid = Supabase.instance.client.auth.currentUser?.id;
    if (_isPendingRegistration) {
      final email = widget.pendingRegistration?['email'] as String?;
      final password = widget.pendingRegistration?['password'] as String?;
      if (email == null || password == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missing registration details.'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      try {
        await _auth.signOut();
      } catch (_) {}
      uid = await _auth.signUp(
        email: email,
        password: password,
        name: _nameController.text.trim(),
        role: 'shelter',
      );
    } else if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to save.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final client = Supabase.instance.client;
      final hasHours =
          _hoursTouched && _openTime != null && _closeTime != null;
      final payload = <String, dynamic>{
        'shelter_id': uid,
        'shelter_name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'operating_hours_start':
            hasHours ? _formatTime(_openTime) : null,
        'operating_hours_end':
            hasHours ? _formatTime(_closeTime) : null,
        'credentials_url': _credentialFileName,
        'shelter_photo_url':
            _photoFiles.isEmpty ? null : _photoFiles.first.name,
        'status': _statusForDb(),
      };
      await client.from('shelter').upsert(payload);
      if (_lat != null && _lng != null) {
        await client
            .from('user')
            .update({'latitude': _lat, 'longitude': _lng}).eq('id', uid);
      }

      if (!mounted) return;
      setState(() => _showSuccess = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save shelter info: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _goToDashboard() {
    Navigator.pushReplacementNamed(context, '/shelterProfile');
  }

  void _continueFromStep1() {
    setState(() => _showErrors = true);
    if (_isStep1Complete) {
      setState(() {
        _currentStep = 1;
        _showErrors = false;
      });
    }
  }

  void _continueFromStep2() {
    setState(() {
      _currentStep = 2;
      _showErrors = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6F5F5);
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: _checkingAccess
            ? const Center(child: CircularProgressIndicator())
            : _showSuccess
                ? _buildSuccess()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        if (_currentStep == 0) _buildStep1(),
                        if (_currentStep == 1) _buildStep2(),
                        if (_currentStep == 2) _buildStep3(),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildHeader() {
    final title = _currentStep == 0
        ? 'Create Your Shelter Profile'
        : _currentStep == 1
            ? 'Verify Your Shelter'
            : 'Tell Your Story';
    final subtitle = _currentStep == 0
        ? 'Let adopters know who you are'
        : _currentStep == 1
            ? 'Build trust with adopters'
            : 'Help adopters understand your mission';

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
                onPressed: _handleBack,
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
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF2D0C57),
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF9586A8),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        _StepIndicator(step: _currentStep),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLabel(
                label: 'Shelter Name',
                requiredField: true,
              ),
              _InputBox(
                child: TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'e.g. StrayConnected Shelter',
                    hintStyle: TextStyle(color: Color(0xFFB0A3C6)),
                  ),
                ),
              ),
              if (_showErrors && _nameController.text.trim().isEmpty)
                const _ErrorText('Shelter name is required.'),
              const SizedBox(height: 6),
              const _HelperText('This name will be visible to adopters'),
              const SizedBox(height: 16),
              _FieldLabel(
                label: 'Location',
                requiredField: true,
              ),
              _InputBox(
                child: Row(
                  children: [
                    const Icon(Icons.place_outlined, color: Color(0xFF5B30B5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _locationController,
                        readOnly: true,
                        onTap: _pickOnMap,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'City or district',
                          hintStyle: TextStyle(color: Color(0xFFB0A3C6)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_showErrors && _locationController.text.trim().isEmpty)
                const _ErrorText('Location is required.'),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _pickOnMap,
                icon: const Icon(Icons.my_location),
                label: const Text('Use current location'),
              ),
              const SizedBox(height: 12),
              _FieldLabel(
                label: 'Operational Status',
                requiredField: true,
              ),
              _InputBox(
                child: DropdownButtonFormField<String>(
                  value: _statusValue,
                  decoration: const InputDecoration(border: InputBorder.none),
                  hint: const Text(
                    'Select status',
                    style: TextStyle(color: Color(0xFFB0A3C6)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(
                      value: 'temporarily_closed',
                      child: Text('Temporarily Closed'),
                    ),
                    DropdownMenuItem(
                      value: 'limited_operation',
                      child: Text('Limited Operation'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _statusValue = value),
                ),
              ),
              if (_showErrors && (_statusValue == null || _statusValue!.isEmpty))
                const _ErrorText('Operational status is required.'),
              const SizedBox(height: 6),
              const _HelperText(
                'Controls whether adopters can request meetings',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'CONTINUE',
          onPressed: _continueFromStep1,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLabel(label: 'Upload Shelter Photo'),
              const SizedBox(height: 8),
              _DashedBorder(
                color: const Color(0xFFD8D0E3),
                radius: 14,
                dash: 6,
                gap: 4,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F1F7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.upload, color: Color(0xFF5B30B5)),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _pickPhotos,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF5B30B5),
                          side: const BorderSide(color: Color(0xFFD8D0E3)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Upload Photo'),
                      ),
                      if (_photoFiles.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${_photoFiles.length} photo(s) selected',
                          style: const TextStyle(
                            color: Color(0xFF5B30B5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const _HelperText(
                'This photo will appear on your public profile',
              ),
              const SizedBox(height: 16),
              _FieldLabel(label: 'Upload Credentials'),
              _InputBox(
                child: OutlinedButton.icon(
                  onPressed: _pickCredentials,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF5B30B5),
                    side: const BorderSide(color: Color(0xFFD8D0E3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    _credentialFileName ?? 'Upload credentials',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const _HelperText('Accepted: PDF, JPG'),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EDF7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'You can still continue without verification, but your shelter will appear as Unverified',
                  style: TextStyle(
                    color: Color(0xFF5B30B5),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'CONTINUE',
          onPressed: _continueFromStep2,
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _continueFromStep2,
            child: const Text('Skip for now'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    final descCount = _descriptionController.text.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _FieldLabel(label: 'Operating Hours (Optional)'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _InputBox(
                      child: InkWell(
                        onTap: _pickOpenTime,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(
                            height: 48,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _openTime == null
                                    ? '08:00'
                                    : _formatTime(_openTime),
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
                    child: _InputBox(
                      child: InkWell(
                        onTap: _pickCloseTime,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(
                            height: 48,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _closeTime == null
                                    ? '17:00'
                                    : _formatTime(_closeTime),
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
              const SizedBox(height: 16),
              const _FieldLabel(label: 'Description (Optional)'),
              _InputBox(
                height: 140,
                child: TextField(
                  controller: _descriptionController,
                  maxLines: null,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText:
                        "Describe your shelter's mission, policies, or adoption process",
                    hintStyle: TextStyle(color: Color(0xFFB0A3C6)),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    counterText: '',
                  ),
                  onChanged: (_) => setState(() {}),
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
            ],
          ),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'CREATE ACCOUNT',
          onPressed: _saving ? null : _handleConfirm,
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF0ACF83), size: 48),
            const SizedBox(height: 12),
            const Text(
              'Your shelter profile is ready!',
              style: TextStyle(
                color: Color(0xFF2D0C57),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            _PrimaryButton(
              label: 'CONTINUE',
              onPressed: _goToDashboard,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Dot(active: step >= 0),
        _Dot(active: step >= 1),
        _Dot(active: step >= 2),
        const SizedBox(width: 10),
        Text(
          'Step ${step + 1} of 3',
          style: const TextStyle(
            color: Color(0xFF9586A8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF0ACF83) : const Color(0xFFD8D0E3),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.requiredField = false});

  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF5B30B5),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        children: requiredField
            ? const [
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: Color(0xFFE45656)),
                ),
              ]
            : const [],
      ),
    );
  }
}

class _InputBox extends StatelessWidget {
  const _InputBox({required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F8FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD8D0E3)),
      ),
      child: child,
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
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0ACF83),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
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

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Colors.redAccent, fontSize: 12),
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
