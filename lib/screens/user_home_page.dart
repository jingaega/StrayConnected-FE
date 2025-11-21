import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase client (same instance you initialized in main.dart)
final SupabaseClient _supabase = Supabase.instance.client;

/// Which filter is currently active.
enum PetFilter {
  all,
  vaccinated,
  young,
  cats,
  dogs,
}

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final List<Pet> _allPets = [];
  bool _isLoading = true;
  String? _loadError;

  PetFilter _activeFilter = PetFilter.all;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final data = await _supabase
          .from('animal')
          .select('animal_id, name, age, breed, species, description, health_status, shelter_id, link_picture');

      // data is List<dynamic>
      final list = (data as List)
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
    switch (_activeFilter) {
      case PetFilter.vaccinated:
        return _allPets
            .where((p) =>
                (p.healthStatus ?? '').toLowerCase().contains('vaccinated'))
            .toList();

      case PetFilter.young:
        // Puppies/Kittens: age <= 1 year
        return _allPets
            .where((p) => p.age != null && p.age! <= 12)
            .toList();

      case PetFilter.cats:
        return _allPets
            .where((p) => (p.species ?? '').toLowerCase() == 'cat')
            .toList();

      case PetFilter.dogs:
        return _allPets
            .where((p) => (p.species ?? '').toLowerCase() == 'dog')
            .toList();

      case PetFilter.all:
      default:
        return _allPets;
    }
  }

  int _countForFilter(PetFilter filter) {
    switch (filter) {
      case PetFilter.all:
        return _allPets.length;
      case PetFilter.vaccinated:
        return _allPets
            .where((p) =>
                (p.healthStatus ?? '').toLowerCase().contains('vaccinated'))
            .length;
      case PetFilter.young:
        return _allPets
            .where((p) => p.age != null && p.age! <= 12)
            .length;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white, // white background
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top header: app name left, big logo right
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Listing',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D0C57),
                    ),
                  ),
                ),
                // Big logo on the top-right
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFFF4F2F9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.asset('assets/images/catlogo.png'),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Color(0xFF9586A8)),
                hintText: 'Search for cats, dogs, shelters...',
                hintStyle: const TextStyle(color: Color(0xFFB7AFC3)),
                filled: true,
                fillColor: const Color(0xFFF5F5F8),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
              // TODO: you can later wire this to local search if you want
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
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
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

    final String labelText = option.count != null
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
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF5B30B5).withOpacity(0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
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

    final ageText = pet.age != null ? '${pet.age} months' : 'Age unknown';
    final healthText =
        (pet.healthStatus == null || pet.healthStatus!.isEmpty)
            ? 'Health info not set'
            : pet.healthStatus!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
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
                // Pet image (placeholder using logo for now)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 80,
                    height: 80,
                    color: const Color(0xFFF4F2F9),
                    child: (pet.linkPicture != null && pet.linkPicture!.isNotEmpty)
                      ? Image.network(
                        pet.linkPicture!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
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
                          color: Color(0xFF2D0C57),
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
                          const Icon(Icons.cake_outlined,
                              size: 16, color: Color(0xFF9586A8)),
                          const SizedBox(width: 4),
                          Text(
                            ageText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9586A8),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.favorite_outline,
                              size: 16, color: Color(0xFF9586A8)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              healthText,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9586A8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
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
              child: GestureDetector(
                onTap: () {
                  // TODO: adopt / open detail later
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0BCE83),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.add,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
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
  final String? shelterId;
  final String? linkPicture;

  Pet({
    required this.animalId,
    required this.name,
    this.age,
    this.breed,
    this.species,
    this.description,
    this.healthStatus,
    this.shelterId,
    this.linkPicture,
  });

  factory Pet.fromMap(Map<String, dynamic> map) {
    return Pet(
      animalId: map['animal_id'] as int,
      name: (map['name'] ?? '') as String,
      age: map['age'] as int?,
      breed: map['breed'] as String?,
      species: map['species'] as String?,
      description: map['description'] as String?,
      healthStatus: map['health_status'] as String?,
      linkPicture: map['link_picture'] as String? ?? '',
      shelterId: map['shelter_id']?.toString(),
    );
  }
}

class FilterOption {
  final PetFilter type;
  final String label;
  final int? count;

  const FilterOption({
    required this.type,
    required this.label,
    this.count,
  });
}
