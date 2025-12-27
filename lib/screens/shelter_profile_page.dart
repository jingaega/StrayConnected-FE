import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as gc;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:strayconnected/data/auth_repository.dart';
import 'package:strayconnected/screens/update_health_page.dart';
import 'package:strayconnected/screens/user_home_page.dart';
import 'package:strayconnected/widgets/global_bottom_nav.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShelterProfilePage extends StatefulWidget {
  const ShelterProfilePage({super.key});

  @override
  State<ShelterProfilePage> createState() => _ShelterProfilePageState();
}

const Color _shelterProfileBg = Color.fromARGB(255, 246, 245, 245);
const Color _shelterProfileCard = Color(0xFFF6F5F9);
const Color _shelterProfileMuted = Color(0xFF7C7693);
const Color _shelterProfileAccent = Color(0xFF0BCE83);

class _ShelterProfilePageState extends State<ShelterProfilePage> {
  final AuthRepository _auth = AuthRepository();
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _shelter;
  dynamic _userCreatedAt;
  bool _canEdit = false;
  List<Pet> _animals = const [];
  String? _animalsError;
  String? _targetShelterId;
  bool _didInit = false;

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
    _targetShelterId = _parseShelterId(args);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _animalsError = null;
    });
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Not logged in';
          _loading = false;
        });
        return;
      }
      final role =
          (await _auth.getMyProfile())?['role']?.toString().toLowerCase();
      final shelterId = _targetShelterId ?? user.id;
      _canEdit = role == 'shelter' && shelterId == user.id;

      final data = await _supabase
          .from('shelter')
          .select()
          .eq('shelter_id', shelterId)
          .maybeSingle();
      final userRow =
          await _supabase
              .from('user')
              .select('created_at')
              .eq('id', shelterId)
              .maybeSingle();

      List<Pet> list = const [];
      try {
        final animals =
            await _supabase
                .from('animal')
                .select(
                  'animal_id, name, age, breed, species, description, health_status, shelter_id, rescuer_id, link_picture',
                )
                .eq('shelter_id', shelterId)
                .order('animal_id', ascending: false);
        list = (animals as List)
            .map((raw) => Pet.fromMap(Map<String, dynamic>.from(raw)))
            .toList();
      } catch (e) {
        _animalsError = e.toString();
      }

      setState(() {
        _shelter = data as Map<String, dynamic>?;
        _userCreatedAt = (userRow as Map<String, dynamic>?)?['created_at'];
        _animals = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String? _parseShelterId(Object? args) {
    if (args == null) return null;
    if (args is String) return args;
    if (args is Pet) return args.shelterId;
    if (args is Map) {
      final raw = args['shelterId'] ?? args['id'];
      return raw?.toString();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const double navHeight = 86;
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    final name = (_shelter?['shelter_name'] as String?) ?? 'Shelter';
    final rawStatus = (_shelter?['status'] as String?)?.trim();
    final status = _formatStatus(rawStatus);
    final location = (_shelter?['location'] as String?) ?? '';
    final hoursStart = _shelter?['operating_hours_start'];
    final hoursEnd = _shelter?['operating_hours_end'];
    final contact = (_shelter?['contact_info'] as String?) ?? '';
    final openRange = _formatHoursRange(hoursStart, hoursEnd, contact);
    final establishedAt = _formatEstablishedAt(_userCreatedAt);
    final followers = (_shelter?['followers'] as int?) ?? 0;
    final locationShort = _shortLocation(location);
    final credentialsUrl = (_shelter?['credentials_url'] as String?)?.trim();
    final isVerified = credentialsUrl != null && credentialsUrl.isNotEmpty;
    final description = (_shelter?['description'] as String?)?.trim() ?? '';

    return Container(
      color: _shelterProfileBg,
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.08),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopBar(
                          handle: '',
                          onSettings: () =>
                              Navigator.pushNamed(context, '/profile'),
                        ),
                        const SizedBox(height: 18),
                        if (_loading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: CircularProgressIndicator(
                                color: Color(0xFF5B30B5),
                              ),
                            ),
                          )
                        else if (_error != null)
                          _ErrorCard(message: _error ?? '')
                        else ...[
                          _HeaderIdentity(
                            name: name,
                            status: status,
                            isVerified: isVerified,
                          ),
                          const SizedBox(height: 14),
                          _MetaRow(
                            icon: Icons.calendar_today_outlined,
                            text: establishedAt == 'Not provided'
                                ? 'Established -'
                                : 'Established $establishedAt',
                          ),
                          const SizedBox(height: 8),
                          _MetaRow(
                            icon: Icons.schedule_outlined,
                            text: openRange.isEmpty ? 'Hours -' : openRange,
                          ),
                          const SizedBox(height: 8),
                          _MetaRow(
                            icon: Icons.place_outlined,
                            text: locationShort.isEmpty
                                ? 'Location -'
                                : locationShort,
                            textColor: locationShort.isEmpty
                                ? _shelterProfileMuted
                                : const Color(0xFF0BCE83),
                            trailing: locationShort.isEmpty
                                ? null
                                : const Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: _shelterProfileAccent,
                                  ),
                            onTap: location.isEmpty
                                ? null
                                : () => _openMap(context, location),
                          ),
                          const SizedBox(height: 16),
                          if (description.isNotEmpty) ...[
                            const _SectionSpacer(),
                            const _SectionTitleText('About'),
                            const SizedBox(height: 8),
                            Text(
                              description,
                              style: const TextStyle(
                                color: _shelterProfileMuted,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _ActionRow(
                            isOwner: _canEdit,
                            followers: followers,
                            onEdit: () => Navigator.pushNamed(
                              context,
                              '/shelterProfileEdit',
                            ),
                            onShare: () {},
                            onFollow: () {},
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    decoration: const BoxDecoration(
                      color: _shelterProfileBg,
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.06),
                          blurRadius: 18,
                          offset: Offset(0, -4),
                        ),
                      ],
                      borderRadius: BorderRadius.all(Radius.circular(18)),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionHeader(
                          title: 'Available for Adoption',
                          subtitle: '(${_animals.length})',
                          showViewAll: _animals.length > 2,
                          onViewAll: () {},
                        ),
                        const SizedBox(height: 12),
                        if (_animalsError != null)
                          Text(
                            'Could not load animals: $_animalsError',
                            style: const TextStyle(color: Colors.redAccent),
                          )
                        else if (_animals.isEmpty)
                          const _EmptyAnimals()
                        else
                          _AnimalGrid(animals: _animals),
                      ],
                    ),
                  ),
                  SizedBox(height: navHeight + 16 + paddingBottom),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RoleAwareBottomNav(
              onCreateAllowed: () =>
                  Navigator.pushNamed(context, '/createAnimal'),
              onHome: () => Navigator.pushReplacementNamed(context, '/home'),
              onMessages: () => Navigator.pushReplacementNamed(context, '/chats'),
              onMeetings: () =>
                  Navigator.pushReplacementNamed(context, '/meetings'),
              onProfile: () => Navigator.pushReplacementNamed(context, '/profile'),
              onShelterProfile: () =>
                  Navigator.pushReplacementNamed(context, '/shelterProfile'),
              activeTab: BottomNavTab.profile,
              showCreate: _canEdit,
            ),
          ),
        ],
      ),
    );
  }

  String _formatHoursRange(
    dynamic hoursStart,
    dynamic hoursEnd,
    String contact,
  ) {
    final start = _formatHour(hoursStart);
    final end = _formatHour(hoursEnd);
    if (start.isNotEmpty && end.isNotEmpty) {
      return '$start - $end';
    }
    return _extractOpenRange(contact);
  }

  String _formatHour(dynamic value) {
    if (value == null) return '';
    final raw = value.toString().trim();
    if (raw.isEmpty) return '';
    if (raw.contains(':') && raw.length >= 5) {
      return raw.substring(0, 5);
    }
    return raw;
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

  String _formatEstablishedAt(dynamic value) {
    if (value == null) return 'Not provided';
    if (value is DateTime) {
      return _formatDate(value);
    }
    final raw = value.toString().trim();
    if (raw.isEmpty) return 'Not provided';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return _formatDate(parsed);
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatStatus(String? value) {
    if (value == null || value.trim().isEmpty) return 'Not set';
    final lower = value.trim().toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  String _shortLocation(String location) {
    final trimmed = location.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(',').map((e) => e.trim()).toList();
    if (parts.length >= 2) {
      return '${parts[0]}, ${parts[1]}';
    }
    return trimmed;
  }

  Future<void> _openMap(BuildContext context, String address) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ShelterMapPage(address: address),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.handle, required this.onSettings});

  final String handle;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              if (handle.isNotEmpty)
                Text(
                  handle,
                  style: const TextStyle(
                    color: Color(0xFF2D0C57),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
        _TopIconButton(
          icon: Icons.settings,
          onTap: onSettings,
        ),
      ],
    );
  }
}

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFF1ECF7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: const Color(0xFF2D0C57), size: 20),
        onPressed: onTap,
      ),
    );
  }
}

class _HeaderIdentity extends StatelessWidget {
  const _HeaderIdentity({
    required this.name,
    required this.status,
    required this.isVerified,
  });

  final String name;
  final String status;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF5B30B5), Color(0xFF0BCE83)],
                ),
              ),
              padding: const EdgeInsets.all(3),
              child: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.pets,
                  size: 40,
                  color: Color(0xFF5B30B5),
                ),
              ),
            ),
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Color(0xFF0BCE83),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Color(0xFF2D0C57),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Shelter',
                style: TextStyle(
                  color: _shelterProfileMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _StatusPill(
                    label: status.isEmpty ? 'Not set' : status,
                    color: _shelterProfileAccent,
                    icon: Icons.circle,
                    iconSize: 8,
                  ),
                  _StatusPill(
                    label: isVerified ? 'Verified' : 'Unverified',
                    color:
                        isVerified ? const Color(0xFF5B30B5) : const Color(0xFFE26D6D),
                    icon:
                        isVerified ? Icons.check : Icons.warning_amber_rounded,
                    iconSize: isVerified ? 12 : 14,
                    showInfo: true,
                    outlined: true,
                    infoMessage: isVerified
                        ? 'Verified by StrayConnected'
                        : 'Credentials not uploaded',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    this.icon,
    this.iconSize = 12,
    this.showInfo = false,
    this.outlined = false,
    this.infoMessage,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final double iconSize;
  final bool showInfo;
  final bool outlined;
  final String? infoMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: outlined ? Border.all(color: color.withOpacity(0.5)) : null,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showInfo) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: infoMessage ?? 'Verified by StrayConnected',
              child: Icon(Icons.info_outline, size: 12, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionSpacer extends StatelessWidget {
  const _SectionSpacer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: const Color(0xFFE6E0EF),
    );
  }
}

class _SectionTitleText extends StatelessWidget {
  const _SectionTitleText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF5B30B5),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.text,
    this.trailing,
    this.onTap,
    this.textColor = _shelterProfileMuted,
  });

  final IconData icon;
  final String text;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF5B30B5)),
          const SizedBox(width: 10),
          Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.isOwner,
    required this.followers,
    required this.onEdit,
    required this.onShare,
    required this.onFollow,
  });

  final bool isOwner;
  final int followers;
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    final followersLabel = _formatFollowers(followers);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                label: isOwner ? 'Edit Profile' : 'Follow Shelter',
                icon: isOwner ? Icons.edit : Icons.favorite,
                onTap: isOwner ? onEdit : onFollow,
                trailing: isOwner ? null : followersLabel,
                iconColor: isOwner ? null : Colors.pinkAccent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                label: 'Share',
                icon: Icons.share_outlined,
                onTap: onShare,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatFollowers(int value) {
    if (value >= 1000) {
      final rounded = (value / 1000).toStringAsFixed(1);
      final cleaned = rounded.endsWith('.0')
          ? rounded.substring(0, rounded.length - 2)
          : rounded;
      return '${cleaned}k';
    }
    return value.toString();
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.trailing,
    this.iconColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final String? trailing;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF5B30B5);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2DCEF)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: iconColor ?? textColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Text(
                trailing!,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.showViewAll = false,
    this.onViewAll,
  });

  final String title;
  final String subtitle;
  final bool showViewAll;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D0C57),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: _shelterProfileMuted,
                ),
              ),
            ],
          ),
        ),
        if (showViewAll)
          TextButton(
            onPressed: onViewAll,
            child: const Text(
              'View all animals >',
              style: TextStyle(
                color: Color(0xFF5B30B5),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _AnimalGrid extends StatelessWidget {
  const _AnimalGrid({required this.animals});
  final List<Pet> animals;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: animals.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) {
        final pet = animals[index];
        return _AnimalCard(pet: pet);
      },
    );
  }
}

class _AnimalCard extends StatelessWidget {
  const _AnimalCard({required this.pet});
  final Pet pet;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => UpdateHealthPage(pet: pet)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2DCEF)),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.06),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
              child: Container(
                height: 120,
                width: double.infinity,
                color: const Color(0xFFEDE7F6),
                child:
                    (pet.primaryImageUrl != null &&
                            pet.primaryImageUrl!.isNotEmpty)
                        ? Image.network(pet.primaryImageUrl!, fit: BoxFit.cover)
                        : const Icon(Icons.pets, size: 40, color: _shelterProfileMuted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
              child: Text(
                pet.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF2D0C57),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _animalMeta(pet),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _shelterProfileMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: Color(0xFF0BCE83),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Available',
                        style: TextStyle(
                          color: _shelterProfileMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _animalMeta(Pet pet) {
    final parts = <String>[];
    if (pet.breed != null && pet.breed!.isNotEmpty) {
      parts.add(pet.breed!.trim());
    } else if (pet.species != null && pet.species!.isNotEmpty) {
      parts.add(pet.species!.trim());
    }
    if (pet.age != null) {
      parts.add(pet.ageLabelShort);
    }
    return parts.isEmpty ? 'Unknown' : parts.join(' - ');
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
        color: _shelterProfileCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3A2430)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAnimals extends StatelessWidget {
  const _EmptyAnimals();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        SizedBox(height: 12),
        SizedBox(height: 8),
        Text(
          'No animals listed yet',
          style: TextStyle(
            color: _shelterProfileMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'This shelter hasn\'t posted any animals for adoption.',
          style: TextStyle(color: _shelterProfileMuted, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ShelterMapPage extends StatefulWidget {
  const _ShelterMapPage({required this.address});

  final String address;

  @override
  State<_ShelterMapPage> createState() => _ShelterMapPageState();
}

class _ShelterMapPageState extends State<_ShelterMapPage> {
  GoogleMapController? _mapController;
  LatLng? _target;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _geocode();
  }

  Future<void> _geocode() async {
    try {
      final results = await gc.locationFromAddress(widget.address);
      if (results.isNotEmpty) {
        final loc = results.first;
        setState(() {
          _target = LatLng(loc.latitude, loc.longitude);
          _loading = false;
        });
        return;
      }
      setState(() {
        _error = 'Location not found.';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load map: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2D0C57),
        elevation: 0,
        title: const Text('Shelter Location'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                )
              : GoogleMap(
                  onMapCreated: (c) => _mapController = c,
                  initialCameraPosition: CameraPosition(
                    target: _target!,
                    zoom: 14,
                  ),
                  markers: {
                    Marker(
                      markerId: const MarkerId('shelter'),
                      position: _target!,
                    ),
                  },
                ),
    );
  }
}
