import 'package:flutter/material.dart';
import 'supabase_config.dart';

class District {
  final int id;
  final String name;
  final String region;

  const District({required this.id, required this.name, required this.region});

  factory District.fromJson(Map<String, dynamic> json) => District(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        region: json['region'] as String? ?? '',
      );
}

class Subcounty {
  final int id;
  final String name;
  final int districtId;

  const Subcounty(
      {required this.id, required this.name, required this.districtId});

  factory Subcounty.fromJson(Map<String, dynamic> json) => Subcounty(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        districtId: json['district_id'] as int? ?? 0,
      );
}

class Parish {
  final int id;
  final String name;
  final int subcountyId;

  const Parish(
      {required this.id, required this.name, required this.subcountyId});

  factory Parish.fromJson(Map<String, dynamic> json) => Parish(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        subcountyId: json['subcounty_id'] as int? ?? 0,
      );
}

class Village {
  final int id;
  final String name;
  final int parishId;

  const Village(
      {required this.id, required this.name, required this.parishId});

  factory Village.fromJson(Map<String, dynamic> json) => Village(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        parishId: json['parish_id'] as int? ?? 0,
      );
}

class LocationService extends ChangeNotifier {
  List<District> _districts = [];
  List<Subcounty> _subcounties = [];
  List<Parish> _parishes = [];
  // Villages are 70k+ rows - NEVER load all at once, always lazy by parish
  final List<Village> _villages = [];
  // Track which parish ids we've already fetched villages for (avoid refetch)
  final Set<int> _villagesLoadedParishIds = <int>{};
  // Per-parish loading flag so the UI can show a small spinner
  final Set<int> _villagesLoadingParishIds = <int>{};

  bool _isLoading = false;
  bool _isLoaded = false;

  List<District> get districts => _districts;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;

  List<Subcounty> getSubcounties(int districtId) =>
      _subcounties.where((s) => s.districtId == districtId).toList();

  List<Parish> getParishes(int subcountyId) =>
      _parishes.where((p) => p.subcountyId == subcountyId).toList();

  List<Village> getVillages(int parishId) =>
      _villages.where((v) => v.parishId == parishId).toList();

  bool isVillagesLoadingFor(int parishId) =>
      _villagesLoadingParishIds.contains(parishId);

  bool isVillagesLoadedFor(int parishId) =>
      _villagesLoadedParishIds.contains(parishId);

  String? districtName(int? id) {
    if (id == null) return null;
    try {
      return _districts.firstWhere((d) => d.id == id).name;
    } catch (_) {
      return null;
    }
  }

  String? subcountyName(int? id) {
    if (id == null) return null;
    try {
      return _subcounties.firstWhere((s) => s.id == id).name;
    } catch (_) {
      return null;
    }
  }

  String? parishName(int? id) {
    if (id == null) return null;
    try {
      return _parishes.firstWhere((p) => p.id == id).name;
    } catch (_) {
      return null;
    }
  }

  String? villageName(int? id) {
    if (id == null) return null;
    try {
      return _villages.firstWhere((v) => v.id == id).name;
    } catch (_) {
      return null;
    }
  }

  /// Load ALL location data from Supabase in parallel
  Future<void> loadAll() async {
    if (_isLoaded) return; // Already loaded, skip
    _isLoading = true;
    notifyListeners();

    try {
      // Fetch all three tables in parallel for speed
      final results = await Future.wait([
        SupabaseConfig.client
            .from('districts')
            .select()
            .order('name'),
        SupabaseConfig.client
            .from('subcounties')
            .select()
            .order('name'),
        SupabaseConfig.client
            .from('parishes')
            .select()
            .order('name'),
      ]);

      _districts = (results[0] as List)
          .map((j) => District.fromJson(j as Map<String, dynamic>))
          .toList();

      _subcounties = (results[1] as List)
          .map((j) => Subcounty.fromJson(j as Map<String, dynamic>))
          .toList();

      _parishes = (results[2] as List)
          .map((j) => Parish.fromJson(j as Map<String, dynamic>))
          .toList();

      _isLoaded = true;
    } catch (e) {
      debugPrint('Error loading locations from Supabase: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load subcounties for a specific district (lazy loading for forms)
  Future<void> loadSubcountiesFor(int districtId) async {
    // If already loaded all, no need to fetch again
    if (_isLoaded) return;
    try {
      final res = await SupabaseConfig.client
          .from('subcounties')
          .select()
          .eq('district_id', districtId)
          .order('name');

      final fetched = (res as List)
          .map((j) => Subcounty.fromJson(j as Map<String, dynamic>))
          .toList();

      // Merge into existing list (avoid duplicates)
      for (final s in fetched) {
        if (!_subcounties.any((x) => x.id == s.id)) {
          _subcounties.add(s);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading subcounties: $e');
    }
  }

  /// Load parishes for a specific subcounty (lazy loading for forms)
  Future<void> loadParishesFor(int subcountyId) async {
    if (_isLoaded) return;
    try {
      final res = await SupabaseConfig.client
          .from('parishes')
          .select()
          .eq('subcounty_id', subcountyId)
          .order('name');

      final fetched = (res as List)
          .map((j) => Parish.fromJson(j as Map<String, dynamic>))
          .toList();

      for (final p in fetched) {
        if (!_parishes.any((x) => x.id == p.id)) {
          _parishes.add(p);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading parishes: $e');
    }
  }

  /// Load villages for a specific parish (lazy loading; villages table is huge)
  Future<void> loadVillagesFor(int parishId) async {
    if (_villagesLoadedParishIds.contains(parishId)) return;
    if (_villagesLoadingParishIds.contains(parishId)) return;

    _villagesLoadingParishIds.add(parishId);
    notifyListeners();

    try {
      final res = await SupabaseConfig.client
          .from('villages')
          .select()
          .eq('parish_id', parishId)
          .order('name');

      final fetched = (res as List)
          .map((j) => Village.fromJson(j as Map<String, dynamic>))
          .toList();

      for (final v in fetched) {
        if (!_villages.any((x) => x.id == v.id)) {
          _villages.add(v);
        }
      }
      _villagesLoadedParishIds.add(parishId);
    } catch (e) {
      debugPrint('Error loading villages: $e');
    } finally {
      _villagesLoadingParishIds.remove(parishId);
      notifyListeners();
    }
  }
}
