import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:strayconnected/screens/pet_profile_page.dart';
import 'package:strayconnected/widgets/global_bottom_nav.dart';

/// Supabase client (same instance you initialized in main.dart)
final SupabaseClient _supabase = Supabase.instance.client;

/// Which filter is currently active.
enum PetFilter { all, vaccinated, young, cats, dogs }

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final List<Pet> _allPets = [];
  bool _isLoading = true;
  String? _loadError;
  String? _role;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  PetFilter _activeFilter = PetFilter.all;

  @override
  void initState() {
    super.initState();
    _loadRole();
    _loadPets();
  }

  @override
  void dispose() {
    _searchController.dispose(); // ← CLEAN IT HERE
    super.dispose();
  }

  bool get _canCreate =>
      _role == 'rescuer' || _role == 'shelter' || _role == 'admin'; // support legacy shelter role

  Future<void> _loadRole() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      setState(() {
        _role = 'user';
      });
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
        _role = data?['role'] as String? ?? 'user';
      });
    } catch (_) {
      setState(() {
        _role = 'user';
      });
    }
  }

  Future<void> _loadPets() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final data = await _supabase
          .from('animal')
          .select(
            'animal_id, name, age, breed, species, description, health_status, known_diseases, vaccination_certificate_url, shelter_id, rescuer_id, link_picture',
          )
          .order('animal_id', ascending: false); // NEWEST FIRST

      // data is List<dynamic>
      final list =
          (data as List)
              .map((row) => Pet.fromMap(Map<String, dynamic>.from(row as Map)))
              .toList();

      setState(() {
        _allPets
          ..clear()
          ..addAll(list);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  /// List of pets after applying current filter.
  List<Pet> get _filteredPets {
    // 1) Apply filter chip logic
    List<Pet> base;
    switch (_activeFilter) {
      case PetFilter.vaccinated:
        base =
            _allPets
                .where(
                  (p) => p.isVaccinatedConfirmed,
                )
                .toList();
        break;

      case PetFilter.young:
        base = _allPets.where((p) => p.age != null && p.age! <= 12).toList();
        break;

      case PetFilter.cats:
        base =
            _allPets
                .where((p) => (p.species ?? '').toLowerCase() == 'cat')
                .toList();
        break;

      case PetFilter.dogs:
        base =
            _allPets
                .where((p) => (p.species ?? '').toLowerCase() == 'dog')
                .toList();
        break;

      case PetFilter.all:
        base = _allPets;
        break;
    }

    // 2) Apply search if not empty
    if (_searchQuery.isEmpty) return base;

    bool matches(String? s) =>
        s != null && s.toLowerCase().contains(_searchQuery);

    return base.where((p) {
      return matches(p.name) ||
          matches(p.breed) ||
          matches(p.species) ||
          matches(p.description);
    }).toList();
  }

  int _countForFilter(PetFilter filter) {
    switch (filter) {
      case PetFilter.all:
        return _allPets.length;
      case PetFilter.vaccinated:
        return _allPets
            .where((p) => p.isVaccinatedConfirmed)
            .length;
      case PetFilter.young:
        return _allPets.where((p) => p.age != null && p.age! <= 12).length;
      case PetFilter.cats:
        return _allPets
            .where((p) => (p.species ?? '').toLowerCase() == 'cat')
            .length;
      case PetFilter.dogs:
        return _allPets
            .where((p) => (p.species ?? '').toLowerCase() == 'dog')
            .length;
    }
  }

  List<FilterOption> get _filterOptions {
    return [
      FilterOption(
        type: PetFilter.all,
        label: 'All',
        count: _countForFilter(PetFilter.all),
      ),
      FilterOption(
        type: PetFilter.vaccinated,
        label: 'Vaccinated',
        count: _countForFilter(PetFilter.vaccinated),
      ),
      FilterOption(
        type: PetFilter.young,
        label: 'Puppies/Kittens',
        count: _countForFilter(PetFilter.young),
      ),
      FilterOption(
        type: PetFilter.cats,
        label: 'Cats',
        count: _countForFilter(PetFilter.cats),
      ),
      FilterOption(
        type: PetFilter.dogs,
        label: 'Dogs',
        count: _countForFilter(PetFilter.dogs),
      ),
    ];
  }

  void _handleCreate() {
    if (!_canCreate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only rescuers or shelters can add listings.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    Navigator.pushNamed(context, '/createAnimal');
  }

  @override
  Widget build(BuildContext context) {
    const double navHeight = 86;
    return Stack(
      children: [
        Container(
          color: const Color.fromARGB(255, 246, 245, 245),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, // <-- Important
                  children: [
                    // LEFT SIDE — Title with extra padding
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 60,
                      ), //  moves text downward
                      child: const Text(
                        'Listing',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2D0C57),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Big logo on the top-right
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // Background circle
                          Container(
                            width: 90,
                            height: 90,
                            decoration: const BoxDecoration(
                              color: Color(0xFFCDFFB6),
                              shape: BoxShape.circle,
                            ),
                          ),

                          // Logo overflowing outside the circle
                          Positioned(
                            top: 5, // moves the logo upward
                            child: Image.asset(
                              'assets/images/catlogo.png',
                              width:
                                  120, // bigger than parent — allows overflow
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFFB7AFC3),
                    ),
                    hintText: 'Search',
                    hintStyle: const TextStyle(color: Color(0xFFB7AFC3)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),

                    // 🔹 Add stroke border here
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(27),
                      borderSide: const BorderSide(
                        color: Color(0xFFE4E2EE), // soft stroke color
                        width: 1.4,
                      ),
                    ),

                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: Color(
                          0xFF5B30B5,
                        ), // purple highlight when focused
                        width: 1.6,
                      ),
                    ),
                  ),

                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase().trim();
                    });
                  },
                ),
              ),

              // Title row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Row(
                  children: [
                    const Text(
                      'Available nearby',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D0C57),
                      ),
                    ),
                    const Spacer(),
                    if (!_isLoading && _allPets.isNotEmpty)
                      Text(
                        '${_filteredPets.length} found',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9586A8),
                        ),
                      ),
                  ],
                ),
              ),

              // 🔹 Filter row (static)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 0, 8),
                child: _FilterRow(
                  options: _filterOptions,
                  active: _activeFilter,
                  onSelected: (filter) {
                    setState(() {
                      _activeFilter = filter;
                    });
                  },
                ),
              ),

              // Content: loading / error / list
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (_isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (_loadError != null) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Failed to load animals:\n$_loadError',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      );
                    }
                    if (_allPets.isEmpty) {
                      return const Center(
                        child: Text(
                          'No animals found yet.',
                          style: TextStyle(color: Color(0xFF9586A8)),
                        ),
                      );
                    }

                    final pets = _filteredPets;
                    if (pets.isEmpty) {
                      return const Center(
                        child: Text(
                          'No animals match this filter.',
                          style: TextStyle(color: Color(0xFF9586A8)),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _loadPets,
                      child: ListView.separated(
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(
                          20,
                          4,
                          20,
                          navHeight + 12,
                        ),
                        itemCount: pets.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final pet = pets[index];
                          return _PetCard(pet: pet);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: RoleAwareBottomNav(
            activeTab: BottomNavTab.home,
            onCreateAllowed: _handleCreate,
            onHome: () {},
            onMessages: () =>
                Navigator.pushReplacementNamed(context, '/chats'),
            onMeetings: () =>
                Navigator.pushReplacementNamed(context, '/meetings'),
            onProfile: () => Navigator.pushNamed(context, '/profile'),
            onShelterProfile: () =>
                Navigator.pushNamed(context, '/shelterProfile'),
          ),
        ),
      ],
    );
  }
}

//
// ========== FILTER UI ==========
//

class _FilterRow extends StatelessWidget {
  final List<FilterOption> options;
  final PetFilter active;
  final ValueChanged<PetFilter> onSelected;

  const _FilterRow({
    required this.options,
    required this.active,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final opt = options[index];
          final bool isActive = opt.type == active;
          return _FilterChip(
            option: opt,
            isActive: isActive,
            onTap: () => onSelected(opt.type),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final FilterOption option;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.option,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = isActive ? const Color(0xFFE5D4FF) : Colors.white;
    final Color textColor =
        isActive ? const Color(0xFF5B30B5) : const Color(0xFF6E6E6E);
    final BorderSide? border =
        isActive ? null : const BorderSide(color: Color(0xFFE4E2EE));

    final String labelText =
        option.count != null
            ? '${option.label} (${option.count})'
            : option.label;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
          border: border == null ? null : Border.fromBorderSide(border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isActive) ...[
              const Icon(Icons.check, size: 16, color: Color(0xFF5B30B5)),
              const SizedBox(width: 6),
            ],
            Text(
              labelText,
              style: TextStyle(
                fontSize: 13,
                color: textColor,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//
// ========== PET CARD ==========
//

class _PetCard extends StatelessWidget {
  final Pet pet;
  const _PetCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (pet.breed != null && pet.breed!.isNotEmpty) pet.breed,
      if (pet.species != null && pet.species!.isNotEmpty) pet.species,
    ].join(' • ');

    final ageText = pet.ageLabel;
    final healthLabel = pet.displayHealthLabel;
    final hasHealthLabel = healthLabel != null && healthLabel.isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => PetProfilePage(pet: pet)));
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 247, 247, 247),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row: image + text
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pet image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 80,
                      height: 80,
                      color: const Color.fromARGB(255, 230, 230, 230),
                      child:
                          (pet.primaryImageUrl != null &&
                                  pet.primaryImageUrl!.isNotEmpty)
                              ? Image.network(
                                pet.primaryImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => Image.asset(
                                      'assets/images/catlogo.png',
                                      fit: BoxFit.cover,
                                    ),
                              )
                              : Image.asset(
                                'assets/images/catlogo.png',
                                fit: BoxFit.cover,
                              ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Text info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color.fromARGB(255, 2, 2, 2),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (subtitle.isNotEmpty)
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9586A8),
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          pet.description ?? 'No description yet.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6E6E6E),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.cake_outlined,
                              size: 16,
                              color: Color(0xFF9586A8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              ageText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9586A8),
                              ),
                            ),
                            if (hasHealthLabel) ...[
                              const SizedBox(width: 12),
                              const Icon(
                                Icons.favorite_outline,
                                size: 16,
                                color: Color(0xFF9586A8),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  healthLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9586A8),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Bottom row: plus button aligned to the right
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0BCE83),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.add, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//
// ========== MODELS ==========
//

class Pet {
  final int animalId;
  final String name;
  final int? age;
  final String? breed;
  final String? species;
  final String? description;
  final String? healthStatus;
  final String? knownDiseases;
  final String? vaccinationCertificateUrl;
  final bool? vaccinationCertificateApproved;
  final String? shelterId;
  final String? rescuerId;
  final String? linkPicture;

  Pet({
    required this.animalId,
    required this.name,
    this.age,
    this.breed,
    this.species,
    this.description,
    this.healthStatus,
    this.knownDiseases,
    this.vaccinationCertificateUrl,
    this.vaccinationCertificateApproved,
    this.shelterId,
    this.rescuerId,
    this.linkPicture,
  });

  List<String> get imageUrls => _parseImageUrls(linkPicture);

  String? get primaryImageUrl =>
      imageUrls.isNotEmpty ? imageUrls.first : null;

  String get ageLabel => _formatAgeLabel(age, short: false);

  String get ageLabelShort => _formatAgeLabel(age, short: true);

  bool get hasVaccinationCertificate =>
      vaccinationCertificateUrl != null &&
      vaccinationCertificateUrl!.trim().isNotEmpty;

  bool get isVaccinatedConfirmed => hasVaccinationCertificate;

  String? get displayHealthLabel {
    final hasKnownDisease =
        knownDiseases != null && knownDiseases!.trim().isNotEmpty;
    final hasCertificate = hasVaccinationCertificate;

    if (hasCertificate && !hasKnownDisease) {
      return 'Vaccinated and Healthy';
    }
    if (hasCertificate && hasKnownDisease) {
      return 'Vaccinated';
    }
    if (!hasCertificate && !hasKnownDisease) {
      return 'Healthy';
    }
    return 'Health info pending';
  }

  factory Pet.fromMap(Map<String, dynamic> map) {
    return Pet(
      animalId: map['animal_id'] as int,
      name: (map['name'] ?? '') as String,
      age: map['age'] as int?,
      breed: map['breed'] as String?,
      species: map['species'] as String?,
      description: map['description'] as String?,
      healthStatus: map['health_status'] as String?,
      knownDiseases: map['known_diseases'] as String?,
      vaccinationCertificateUrl:
          map['vaccination_certificate_url'] as String?,
      vaccinationCertificateApproved:
          map['vaccination_certificate_approved'] as bool?,
      linkPicture: map['link_picture'] as String? ?? '',
      shelterId: map['shelter_id']?.toString(),
      rescuerId: map['rescuer_id']?.toString(),
    );
  }
}

String _formatAgeLabel(int? months, {required bool short}) {
  if (months == null) return 'Age unknown';
  if (months >= 12) {
    final years = months ~/ 12;
    if (short) {
      return years == 1 ? '1 yr' : '$years yrs';
    }
    return years == 1 ? '1 year' : '$years years';
  }
  return short ? '$months m/o' : '$months months';
}

class FilterOption {
  final PetFilter type;
  final String label;
  final int? count;

  const FilterOption({required this.type, required this.label, this.count});
}

List<String> _parseImageUrls(String? raw) {
  if (raw == null) return [];
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return [];

  if (trimmed.startsWith('[')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (_) {}
  }

  return [trimmed];
}
