import 'package:flutter/material.dart';
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
    final status = (rawStatus == null || rawStatus.isEmpty)
        ? 'Not set'
        : rawStatus;
    final contact = (_shelter?['contact_info'] as String?) ?? '';
    final location = (_shelter?['location'] as String?) ?? '';
    final openRange = _extractOpenRange(contact);
    final description = _extractNotes(contact).join('\n');
    final openedOn = _formatOpenedOn(_shelter?['opened_on']);
    const handle = 'Shelter Profile';

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
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.08),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TopBar(
                          handle: 'Shelter Profile',
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
                          _ProfileHeader(
                            name: name,
                            description: description,
                            status: status,
                            openedOn: openedOn,
                            location: location,
                            openRange: openRange,
                            canEdit: _canEdit,
                            onEdit: () => Navigator.pushNamed(
                              context,
                              '/shelterProfileEdit',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _ActionButton(
                                  label: _canEdit
                                      ? 'Edit profile'
                                      : 'Contact shelter',
                                  onTap: () {
                                    if (_canEdit) {
                                      Navigator.pushNamed(
                                        context,
                                        '/shelterProfileEdit',
                                      );
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ActionButton(
                                  label: 'Share profile',
                                  onTap: () {},
                                ),
                              ),
                              const SizedBox(width: 10),
                              _CircleAction(
                                icon: Icons.favorite_border,
                                onTap: () {},
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: _shelterProfileBg,
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.06),
                          blurRadius: 18,
                          offset: Offset(0, -4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionHeader(
                          title: 'Our Furry Friends',
                          subtitle: '${_animals.length} animals',
                        ),
                        const SizedBox(height: 12),
                        if (_animalsError != null)
                          Text(
                            'Could not load animals: $_animalsError',
                            style: const TextStyle(color: Colors.redAccent),
                          )
                        else if (_animals.isEmpty)
                          const Text(
                            'No animals listed yet.',
                            style: TextStyle(color: _shelterProfileMuted),
                          )
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
            ),
          ),
        ],
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.description,
    required this.status,
    required this.openedOn,
    required this.location,
    required this.openRange,
    required this.canEdit,
    required this.onEdit,
  });

  final String name;
  final String description;
  final String status;
  final String openedOn;
  final String location;
  final String openRange;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF5B30B5), Color(0xFF0BCE83)],
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.pets, color: Color(0xFF5B30B5), size: 40),
                  ),
                ),
                Positioned(
                  bottom: -4,
                  right: -4,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0BCE83),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, size: 16, color: Colors.white),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (canEdit)
                        GestureDetector(
                          onTap: onEdit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1ECF7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Color(0xFF5B30B5),
                              size: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _StatusPill(
                        label: status.isEmpty ? 'Not set' : status,
                        color: _shelterProfileAccent,
                      ),
                      const _StatusPill(
                        label: 'Verified',
                        color: Color(0xFF5B30B5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (description.isNotEmpty)
          Text(
            description,
            style: const TextStyle(
              color: _shelterProfileMuted,
              fontSize: 13,
              height: 1.4,
            ),
          )
        else
          const Text(
            'No description yet.',
            style: TextStyle(
              color: _shelterProfileMuted,
              fontSize: 13,
            ),
          ),
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.calendar_today_outlined,
          text: openedOn == 'Not set'
              ? 'Opened since not set'
              : 'Opened since $openedOn',
        ),
        const SizedBox(height: 6),
        _InfoRow(
          icon: Icons.schedule_outlined,
          text: openRange.isEmpty ? 'Hours not set' : 'Open $openRange',
        ),
        const SizedBox(height: 6),
        _InfoRow(
          icon: Icons.place_outlined,
          text: location.isEmpty ? 'Location not set' : location,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF5B30B5)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFB7AFC3),
              fontSize: 12,
            ),
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: _shelterProfileCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2DCEF)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF2D0C57),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _shelterProfileCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2DCEF)),
        ),
        child: Icon(icon, color: const Color(0xFF2D0C57), size: 18),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D0C57),
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: _shelterProfileMuted,
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
        childAspectRatio: 0.84,
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
          color: _shelterProfileCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2DCEF)),
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
                height: 140,
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
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
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
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                (pet.breed != null && pet.breed!.isNotEmpty)
                    ? pet.breed!
                    : (pet.species ?? ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _shelterProfileMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
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
