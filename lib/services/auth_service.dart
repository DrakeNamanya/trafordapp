import 'dart:convert';
import 'package:flutter/material.dart';
import 'supabase_config.dart';

class AuthService extends ChangeNotifier {
  Map<String, dynamic>? _profile;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  Map<String, dynamic>? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get hasProfile => _profile != null && _profile!['is_complete'] == true;
  int? get userId => _profile?['user_id'] as int?;
  String? get userName => _profile?['full_name'] as String?;
  String? get userPhone => _profile?['phone'] as String?;

  // ---- Phase 5: role + JWT access for the new public API ----

  /// Role string from the profiles table — used to gate the Agro Shop tab.
  /// Possible values: 'customer', 'field_staff', 'admin_staff', 'admin',
  /// 'finance', 'director'. Defaults to 'customer' when unknown.
  String get role => (_profile?['role'] as String?) ?? 'customer';

  /// True if the user can see the staff-only Agro Inputs shop.
  bool get canShopAgro =>
      const {'field_staff', 'admin_staff', 'admin', 'finance', 'director'}
          .contains(role);

  /// Current Supabase JWT access token (for /agro-products + /agro-orders).
  /// Returns null when there is no Supabase auth session (e.g. legacy phone-
  /// only login). The Agro shop will refuse to load if this is null.
  String? get accessToken =>
      SupabaseConfig.client.auth.currentSession?.accessToken;

  /// Initialize auth - no local storage, just reset state
  Future<void> initialize() async {
    // No Hive restoration - state starts fresh
    // Auto-login as guest will handle giving a browsing session
  }

  /// Parse extended profile data from auth_id JSON field
  Map<String, dynamic> _parseAuthIdExtras(String? authId) {
    if (authId == null || authId.isEmpty) return {};
    try {
      if (authId.startsWith('{')) {
        return Map<String, dynamic>.from(json.decode(authId) as Map);
      }
    } catch (_) {}
    return {};
  }

  /// Build a full profile map from a users table row
  Map<String, dynamic> _buildProfileFromUser(Map<String, dynamic> userRow) {
    final extras = _parseAuthIdExtras(userRow['auth_id'] as String?);

    return {
      'user_id': userRow['id'],
      'full_name': userRow['name'] ?? 'Customer',
      'phone': userRow['phone'] ?? '',
      'email': userRow['email'] ?? '',
      'address': userRow['address'] ?? '',
      'city': userRow['city'] ?? '',
      'district_id': extras['district_id'] as int?,
      'subcounty_id': extras['subcounty_id'] as int?,
      'parish_id': extras['parish_id'] as int?,
      'date_of_birth': extras['date_of_birth'] as String?,
      'nin': extras['nin'] as String?,
      'is_complete': true,
    };
  }

  /// Phone-only login - looks up users table in Supabase
  Future<bool> loginWithPhone(String phone) async {
    _isLoading = true;
    notifyListeners();

    try {
      final userRes = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('phone', phone)
          .maybeSingle();

      if (userRes != null) {
        _profile = _buildProfileFromUser(userRes);
        _isLoggedIn = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Login error: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Register a new user - stores ALL data in Supabase users table
  /// Email is optional - users can register with phone number only
  Future<bool> register({
    required String fullName,
    required String phone,
    String? email,
    required DateTime dateOfBirth,
    required int districtId,
    required int subcountyId,
    required int parishId,
    required String districtName,
    required String subcountyName,
    required String parishName,
    double? gpsLatitude,
    double? gpsLongitude,
    String? nin,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Extended profile data stored as JSON in auth_id
      final extrasJson = json.encode({
        'type': 'phone',
        'district_id': districtId,
        'subcounty_id': subcountyId,
        'parish_id': parishId,
        'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
        if (nin != null && nin.isNotEmpty) 'nin': nin,
        if (gpsLatitude != null) 'gps_latitude': gpsLatitude,
        if (gpsLongitude != null) 'gps_longitude': gpsLongitude,
      });

      final insertData = <String, dynamic>{
        'name': fullName,
        'phone': phone,
        'role': 'user',
        'auth_id': extrasJson,
        'address': '$parishName, $subcountyName',
        'city': districtName,
        'country': 'Uganda',
      };

      // Only include email if provided and non-empty
      if (email != null && email.trim().isNotEmpty) {
        insertData['email'] = email.trim();
      }

      // Create user in Supabase users table
      final userRes = await SupabaseConfig.client
          .from('users')
          .insert(insertData)
          .select()
          .single();

      // Build profile from the created user row
      _profile = _buildProfileFromUser(userRes);
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Registration error: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Auto-login as guest user (user_id 2) for browsing
  Future<void> autoLoginGuest() async {
    if (_isLoggedIn) return;

    try {
      final userRes = await SupabaseConfig.client
          .from('users')
          .select()
          .eq('id', 2)
          .maybeSingle();

      if (userRes != null) {
        _profile = {
          'user_id': userRes['id'],
          'full_name': userRes['name'] ?? 'Guest',
          'phone': userRes['phone'] ?? '',
          'email': userRes['email'] ?? '',
          'is_complete': false,
        };
        _isLoggedIn = true;
        // Don't persist guest session
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Auto-login error: $e');
    }
  }

  void logout() {
    _profile = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
