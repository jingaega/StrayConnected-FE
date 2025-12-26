import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
  final _descriptionController = TextEditingController();
  TimeOfDay? _openTime;
  TimeOfDay? _closeTime;
  String? _statusValue;
  String? _credentialFileName;
  String? _pickedAddress;
  double? _lat;
  double? _lng;
  bool _checkingAccess = true;
  List<PlatformFile> _photoFiles = const [];
  bool _saving = false;
  bool _isPendingRegistration = false;

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
    _descriptionController.dispose();
    super.dispose();
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
        _pickedAddress = result.address;
      });
    }
  }

  Future<void> _handleConfirm() async {
    final name = _nameController.text.trim();
    final desc = _descriptionController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shelter name is required.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_openTime == null || _closeTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Opening and closing time are required.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_statusValue == null || _statusValue!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shelter status is required.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_lat == null || _lng == null || _pickedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick your shelter location.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (_credentialFileName == null || _credentialFileName!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload shelter credentials.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Description is required.'),
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
        name: name,
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
      final Map<String, dynamic> payload = {
        'shelter_id': uid,
        'shelter_name': name,
        'location': _pickedAddress,
        'contact_info': _buildContactInfo(),
        'opened_on': null, // storing time only; no date column here
        'status': _statusValue,
      };

      await client.from('shelter').upsert(payload);
      await client
          .from('user')
          .update({'latitude': _lat, 'longitude': _lng}).eq('id', uid);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shelter info saved'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
      if (_isPendingRegistration) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      }
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

  Future<void> _pickOpenDate() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _openTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _openTime = picked);
    }
  }

  Future<void> _pickCloseDate() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _closeTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _closeTime = picked);
    }
  }

  Future<void> _pickCredentials() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() => _credentialFileName = res.files.first.name);
    }
  }

  String get _openTimeLabel {
    if (_openTime == null) return 'Select time';
    final h = _openTime!.hour.toString().padLeft(2, '0');
    final m = _openTime!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get _closeTimeLabel {
    if (_closeTime == null) return 'Select time';
    final h = _closeTime!.hour.toString().padLeft(2, '0');
    final m = _closeTime!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _buildContactInfo() {
    final desc = _descriptionController.text.trim();
    String time = '';
    if (_openTimeLabel != 'Select time' || _closeTimeLabel != 'Select time') {
      final open = _openTimeLabel == 'Select time' ? '?' : _openTimeLabel;
      final close = _closeTimeLabel == 'Select time' ? '?' : _closeTimeLabel;
      time = 'Open: $open - $close\n';
    }
    return '$time$desc'.trim();
  }

  Future<void> _checkAccess() async {
    try {
      final profile = await _auth.getMyProfile();
      final role = (profile?['role'] as String?)?.toLowerCase().trim() ?? '';
      if (!mounted) return;
      if (role != 'shelter') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shelter profile is only available for shelter accounts.'),
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

  Future<void> _pickPhotos() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() => _photoFiles = res.files);
    }
  }

  bool get _isFormComplete {
    final name = _nameController.text.trim();
    final desc = _descriptionController.text.trim();
    final hasLocation = _lat != null && _lng != null && _pickedAddress != null;
    final hasCredentials =
        _credentialFileName != null && _credentialFileName!.trim().isNotEmpty;
    return name.isNotEmpty &&
        desc.isNotEmpty &&
        _openTime != null &&
        _closeTime != null &&
        (_statusValue != null && _statusValue!.trim().isNotEmpty) &&
        hasLocation &&
        hasCredentials;
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF6F5F5);
    const border = Color(0xFFD8D0E3);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            if (_checkingAccess)
              const Center(
                child: CircularProgressIndicator(),
              ),
            if (!_checkingAccess) ...[
              Positioned(
                left: 0,
                right: 0,
                child: Container(
                  height: 96,
                  decoration: const BoxDecoration(
                    color: bg,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x02000000),
                        blurRadius: 18,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.arrow_back_ios_new,
                                color: Color(0xFF2D0C57)),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Complete Shelter Profile',
                            style: TextStyle(
                              color: Color(0xFF2D0C57),
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.41,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Complete every field to finish shelter setup.',
                        style: TextStyle(
                          color: Color(0xFF9586A8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Upload photos box
                      Center(
                        child: InkWell(
                          onTap: _pickPhotos,
                          child: Container(
                            width: 344,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF9B9B9B)),
                            ),
                            child: _photoFiles.isEmpty
                                ? Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.image_outlined,
                                          size: 42, color: Color(0xFF9B9B9B)),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Upload photos',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Tap to choose images',
                                        style: TextStyle(
                                          color: Color(0xFF9586A8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.image, color: Color(0xFF5B30B5)),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${_photoFiles.length} photo(s) selected',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const Spacer(),
                                          TextButton(
                                            onPressed: _pickPhotos,
                                            child: const Text('Change'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: _photoFiles
                                            .take(6)
                                            .map(
                                              (f) => Chip(
                                                label: Text(
                                                  f.name,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                backgroundColor:
                                                    const Color(0xFFF0EDF6),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      Row(
                        children: [
                          Expanded(
                            child: _LabeledBox(
                              label: 'Shelter Name',
                              child: TextField(
                                controller: _nameController,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Shelter Name',
                                  hintStyle: TextStyle(
                                    color: Color(0xFF9586A8),
                                    fontSize: 16,
                                  ),
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
                              label: 'Opening Time',
                              child: InkWell(
                                onTap: _pickOpenDate,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12),
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
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _LabeledBox(
                              label: 'Closing Time',
                              child: InkWell(
                                onTap: _pickCloseDate,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12),
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: _LabeledBox(
                              label: 'Status',
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: DropdownButtonFormField<String>(
                                  value: _statusValue,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                  ),
                                  hint: const Text(
                                    'Select status',
                                    style: TextStyle(
                                      color: Color(0xFF9586A8),
                                      fontSize: 16,
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'open',
                                      child: Text('Open'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'closed',
                                      child: Text('Closed'),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    setState(() => _statusValue = val);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _LabeledBox(
                        label: 'Shelter Location',
                        height: 96,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _pickedAddress ?? 'No location selected',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF2D0C57),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _lat != null && _lng != null
                                          ? 'Lat: ${_lat!.toStringAsFixed(5)}, Lng: ${_lng!.toStringAsFixed(5)}'
                                          : 'Pick on map to set coordinates',
                                      style: const TextStyle(
                                        color: Color(0xFF9586A8),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _pickOnMap,
                                    child: const Text('Pick on map'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _LabeledBox(
                        label: 'Upload Credentials',
                        child: InkWell(
                          onTap: _pickCredentials,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.picture_as_pdf,
                                    color: Colors.red.shade400),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _credentialFileName ??
                                        'Upload PDF credentials',
                                    style: TextStyle(
                                      color: _credentialFileName == null
                                          ? const Color(0xFF9586A8)
                                          : const Color(0xFF2D0C57),
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _LabeledBox(
                        label: 'Insert Description',
                        height: 120,
                        child: TextField(
                          controller: _descriptionController,
                          onChanged: (_) => setState(() {}),
                          maxLines: null,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Insert Description',
                            hintStyle: TextStyle(
                              color: Color(0xFF9586A8),
                              fontSize: 16,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0ACF83),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed:
                              (_saving || !_isFormComplete) ? null : _handleConfirm,
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
                                  'CONFIRM',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    letterSpacing: -0.01,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LabeledBox extends StatelessWidget {
  const _LabeledBox({
    required this.label,
    required this.child,
    this.height = 69,
  });

  final String label;
  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    const border = Color(0xFFD8D0E3);
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
        const SizedBox(height: 6),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ],
    );
  }
}
