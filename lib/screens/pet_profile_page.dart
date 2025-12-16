import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/screens/arrange_adoption_page.dart';
import 'package:strayconnected/models/chat_preview_item.dart';
import 'package:strayconnected/screens/user_home_page.dart';
import 'package:strayconnected/widgets/global_bottom_nav.dart';

const Color _bg = Color(0xFFF6F5F5);
const Color _cardColor = Colors.white;
const Color _primary = Color(0xFF3F0C7A);
const Color _textSecondary = Color(0xFF9B94AD);
const Color _muted = Color(0xFF7C7693);
const Color _success = Color(0xFF0BCE83);
const Color _stroke = Color(0xFFD8D0E3);

class PetProfilePage extends StatefulWidget {
  final Pet pet;

  const PetProfilePage({super.key, required this.pet});

  @override
  State<PetProfilePage> createState() => _PetProfilePageState();
}

class _PetProfilePageState extends State<PetProfilePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  late Pet _pet;
  bool _isLoading = false;
  String? _loadError;
  String _role = 'user';
  bool _contactLoading = false;

  @override
  void initState() {
    super.initState();
    _pet = widget.pet;
    _loadRole();
    _refreshPet();
  }

  Future<void> _loadRole() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _role = 'user');
      return;
    }
    try {
      final data =
          await _supabase
              .from('user')
              .select('role')
              .eq('id', uid)
              .maybeSingle();
      setState(() {
        _role = (data?['role'] as String?) ?? 'user';
      });
    } catch (_) {
      setState(() => _role = 'user');
    }
  }

  bool get _isAdopter => _role == 'adopter';

  Future<void> _refreshPet() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final data =
          await _supabase
              .from('animal')
              .select(
                'animal_id, name, age, breed, species, description, health_status, shelter_id, rescuer_id, link_picture',
              )
              .eq('animal_id', widget.pet.animalId)
              .maybeSingle();

      if (!mounted) return;

      if (data != null) {
        final updated = Pet.fromMap(Map<String, dynamic>.from(data));
        setState(() {
          _pet = updated;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    const double navHeight = 86;
    final String ageLabel =
        _pet.age != null ? '${_pet.age} m/o' : 'Age unknown';
    final String traits = [
      if (_pet.breed != null && _pet.breed!.isNotEmpty) _pet.breed!.trim(),
      if (_pet.species != null && _pet.species!.isNotEmpty)
        _pet.species!.trim(),
    ].join(' • ');
    final String detailLine = [
      if (traits.isNotEmpty) traits,
      '20km away',
    ].join(' - ');

    final String descriptionText =
        (_pet.description != null && _pet.description!.trim().isNotEmpty)
            ? _pet.description!.trim()
            : 'No description provided yet for this pet.';

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(bottom: navHeight + 140 + paddingBottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroSection(
                  pet: _pet,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _InfoCard(
                      pet: _pet,
                      ageLabel: ageLabel,
                      detailLine: detailLine,
                      descriptionText: descriptionText,
                      isLoading: _isLoading,
                      loadError: _loadError,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: navHeight + 16 + paddingBottom,
            child: Row(
              children: [
                SizedBox(
                  height: 56,
                  width: 64,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _stroke, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.white,
                    ),
                    onPressed: _contactLoading ? null : _handleContact,
                    child:
                        _contactLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _primary,
                                ),
                              )
                            : const Icon(Icons.help_outline, color: _primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        _handleArrangeAdoption();
                      },
                      child: const Text(
                        'ARRANGE ADOPTION',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -0.01,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: RoleAwareBottomNav(
        onCreateAllowed: () => Navigator.pushNamed(context, '/createAnimal'),
        onHome: () => Navigator.pushReplacementNamed(context, '/home'),
        onMessages: () =>
            Navigator.pushReplacementNamed(context, '/chats'),
        onMeetings: () =>
            Navigator.pushReplacementNamed(context, '/meetings'),
        onProfile: () =>
            Navigator.pushReplacementNamed(context, '/profile'),
        activeTab: BottomNavTab.home,
      ),
    );
  }

  void _handleArrangeAdoption() {
    if (!_isAdopter) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only adopters can arrange an adoption meeting.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArrangeAdoptionPage(
          pet: _pet,
          isAdopter: _isAdopter,
          shelterId: _pet.shelterId,
          rescuerId: _pet.rescuerId,
        ),
      ),
    );
  }

  Future<void> _handleContact() async {
    final contactId = _pet.rescuerId ?? _pet.shelterId;
    if (contactId == null || contactId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No rescuer or shelter linked to this animal.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _contactLoading = true);
    try {
      String displayName = 'Rescuer';
      final data =
          await _supabase
              .from('user')
              .select('name, email')
              .eq('id', contactId)
              .maybeSingle();
      if (data != null) {
        displayName =
            (data['name'] as String?)?.trim().isNotEmpty == true
                ? (data['name'] as String).trim()
                : (data['email'] as String?) ?? displayName;
      }

      if (!mounted) return;
      Navigator.pushNamed(
        context,
        '/chatThread',
        arguments: ChatPreviewItem(
          userId: contactId,
          name: displayName,
          lastMessage: '',
          lastAt: DateTime.now(),
          avatarUrl: 'https://placehold.co/42x42',
          rescuerId: _pet.rescuerId,
          shelterId: _pet.shelterId,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not start chat: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _contactLoading = false);
    }
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.pet, required this.onBack});

  final Pet pet;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    const double heroHeight = 340;

    return SizedBox(
      height: heroHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HeroImage(linkPicture: pet.linkPicture),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: const Alignment(0.5, 0.0),
                end: const Alignment(0.5, 1.0),
                colors: [
                  Color.fromRGBO(0, 0, 0, 0.10),
                  Color.fromRGBO(0, 0, 0, 0.30),
                  Color.fromRGBO(0, 0, 0, 0.55),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                _Dot(isActive: true),
                SizedBox(width: 8),
                _Dot(isActive: false),
                SizedBox(width: 8),
                _Dot(isActive: false),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.topLeft,
                child: _CircleIconButton(icon: Icons.arrow_back, onTap: onBack),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.pet,
    required this.ageLabel,
    required this.detailLine,
    required this.descriptionText,
    required this.isLoading,
    required this.loadError,
  });

  final Pet pet;
  final String ageLabel;
  final String detailLine;
  final String descriptionText;
  final bool isLoading;
  final String? loadError;

  @override
  Widget build(BuildContext context) {
    final _DescriptionParts descriptionParts = _DescriptionParts.from(
      descriptionText,
      pet.name,
    );

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.06),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pet.name,
              style: const TextStyle(
                color: _primary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  ageLabel,
                  style: const TextStyle(
                    color: _primary,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    detailLine,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (pet.healthStatus != null &&
                pet.healthStatus!.trim().isNotEmpty) ...[
              Text(
                pet.healthStatus!,
                style: const TextStyle(
                  color: _success,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (isLoading) ...[
              const SizedBox(height: 14),
              Row(
                children: const [
                  SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Refreshing details…',
                    style: TextStyle(color: _textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ],
            if (loadError != null) ...[
              const SizedBox(height: 8),
              Text(
                'Could not refresh from database: $loadError',
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              descriptionParts.headline,
              style: const TextStyle(
                color: _primary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              descriptionParts.body,
              style: const TextStyle(
                color: _muted,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({this.linkPicture});

  final String? linkPicture;

  @override
  Widget build(BuildContext context) {
    if (linkPicture != null && linkPicture!.isNotEmpty) {
      return Image.network(
        linkPicture!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackHeroImage(),
      );
    }
    return _fallbackHeroImage();
  }

  Widget _fallbackHeroImage() {
    return Container(
      color: const Color(0xFF3E0C7A),
      alignment: Alignment.center,
      child: Image.asset(
        'assets/images/catlogo.png',
        fit: BoxFit.contain,
        width: 120,
        height: 120,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            isActive ? Colors.white : const Color.fromRGBO(255, 255, 255, 0.5),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color.fromRGBO(0, 0, 0, 0.25),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

class _DescriptionParts {
  final String headline;
  final String body;

  _DescriptionParts({required this.headline, required this.body});

  factory _DescriptionParts.from(String raw, String name) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return _DescriptionParts(
        headline: 'About $name',
        body: 'No description provided yet for this pet.',
      );
    }

    final sentences =
        trimmed
            .split(RegExp(r'(?<=[.!?])\s+'))
            .where((e) => e.trim().isNotEmpty)
            .toList();

    if (sentences.length > 1) {
      final headline = sentences.first.trim();
      final body = trimmed.substring(headline.length).trimLeft();
      return _DescriptionParts(headline: headline, body: body);
    }

    return _DescriptionParts(headline: 'About $name', body: trimmed);
  }
}
