import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'supabase_config.dart';

/// AuthService — rewritten to use the canonical `profiles` table (UUID-keyed
/// via auth.users) and Supabase Auth.
///
/// IMPORTANT: the legacy `public.users` table no longer exists in Supabase.
/// All client code now reads/writes `profiles` and the user identity comes
/// from `Supabase.auth.currentUser.id` (UUID). Internally we still expose a
/// stable `int userId` derived from a hashed UUID so the rest of the app
/// (CartService, OrderService, NotificationService — all of which were
/// historically keyed by an int) keeps working without a full rewrite. The
/// canonical UUID is exposed as `userUuid` for code that needs it.
class AuthService extends ChangeNotifier {
  Map<String, dynamic>? _profile;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  Map<String, dynamic>? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get hasProfile => _profile != null && _profile!['is_complete'] == true;
  int? get userId => _profile?['user_id'] as int?;
  String? get userUuid => _profile?['user_uuid'] as String?;
  String? get userName => _profile?['full_name'] as String?;
  String? get userPhone => _profile?['phone'] as String?;

  /// Role string from the profiles table — used to gate the Agro Shop tab.
  String get role => (_profile?['role'] as String?) ?? 'customer';

  /// True if the user can see the staff-only Agro Inputs shop.
  bool get canShopAgro =>
      const {'field_staff', 'admin_staff', 'admin', 'finance', 'director'}
          .contains(role);

  /// Current Supabase JWT access token (for /agro-products + /agro-orders).
  String? get accessToken =>
      SupabaseConfig.client.auth.currentSession?.accessToken;

  /// Derive a stable positive int from a UUID so legacy `int userId`-based
  /// services (cart, orders, notifications) keep working. Two different UUIDs
  /// could in theory collide here, but with 2^31 buckets it's safe for an
  /// app at this scale.
  int _intFromUuid(String uuid) {
    var hash = 0;
    for (final code in uuid.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    // Keep it >= 1000 so we never collide with the historical "guest = 2".
    return 1000 + (hash % 2000000000);
  }

  /// Build a profile map from a profiles row + auth user.
  Map<String, dynamic> _buildProfile(
    Map<String, dynamic> row,
    String uuid,
  ) {
    return {
      'user_uuid': uuid,
      'user_id': _intFromUuid(uuid),
      'full_name': row['full_name'] ?? 'Customer',
      'phone': row['phone'] ?? '',
      'email': row['email'] ?? '',
      'role': row['role'] ?? 'customer',
      'street_address': row['street_address'] ?? '',
      'district_id': row['district_id'] as int?,
      'subcounty_id': row['subcounty_id'] as int?,
      'parish_id': row['parish_id'] as int?,
      'village_id': row['village_id'] as int?,
      'date_of_birth': row['date_of_birth'] as String?,
      'nin': row['nin'] as String?,
      'is_complete': true,
    };
  }

  /// Initialize auth — try to restore an existing Supabase session.
  Future<void> initialize() async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      try {
        await _loadProfileForUser(session.user.id);
      } catch (e) {
        debugPrint('initialize: profile load failed: $e');
      }
    }
  }

  Future<void> _loadProfileForUser(String uuid) async {
    final row = await SupabaseConfig.client
        .from('profiles')
        .select()
        .eq('id', uuid)
        .maybeSingle();
    if (row != null) {
      _profile = _buildProfile(row, uuid);
      _isLoggedIn = true;
      notifyListeners();
    }
  }

  /// Convert a 12-digit Uganda phone to the synthetic email Supabase Auth
  /// requires. Keeps phone-based login working without forcing users to
  /// supply an email.
  String _emailForPhone(String phone) =>
      '$phone@phone.trafordfresh.local';

  /// Check whether a user with this phone already exists in profiles.
  /// Returns 'has_password' (always — Supabase Auth enforces a password)
  /// for existing users, 'not_found' otherwise, or 'error' on failure.
  Future<String> userHasPasswordStatus(String phone) async {
    try {
      final row = await SupabaseConfig.client
          .from('profiles')
          .select('id')
          .eq('phone', phone)
          .maybeSingle();
      return row != null ? 'has_password' : 'not_found';
    } catch (e) {
      debugPrint('userHasPasswordStatus error: $e');
      return 'error';
    }
  }

  /// Phone + password login. We look up the email-for-phone, then sign in
  /// via Supabase Auth, then hydrate the profile row.
  Future<bool> loginWithPhonePassword(String phone, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      // First try the synthetic phone-email format.
      final res = await SupabaseConfig.client.auth.signInWithPassword(
        email: _emailForPhone(phone),
        password: password,
      );
      final user = res.user;
      if (user != null) {
        await _loadProfileForUser(user.id);
        _isLoading = false;
        notifyListeners();
        return _isLoggedIn;
      }
    } catch (e) {
      debugPrint('loginWithPhonePassword (phone-email) failed: $e');

      // Fallback: the user may have signed up with a real email — look it
      // up via the profiles row, then sign in with that real email.
      try {
        final row = await SupabaseConfig.client
            .from('profiles')
            .select('email')
            .eq('phone', phone)
            .maybeSingle();
        final realEmail = (row?['email'] as String?)?.trim();
        if (realEmail != null && realEmail.isNotEmpty) {
          final res = await SupabaseConfig.client.auth.signInWithPassword(
            email: realEmail,
            password: password,
          );
          final user = res.user;
          if (user != null) {
            await _loadProfileForUser(user.id);
            _isLoading = false;
            notifyListeners();
            return _isLoggedIn;
          }
        }
      } catch (e2) {
        debugPrint('loginWithPhonePassword (real-email) failed: $e2');
      }
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Phone-only login is no longer supported (Supabase Auth requires a
  /// password). Kept as a stub so older callers don't crash — returns false.
  Future<bool> loginWithPhone(String phone) async {
    return false;
  }

  /// Set / change the password on the currently logged-in user.
  Future<bool> setPassword(String newPassword) async {
    try {
      await SupabaseConfig.client.auth.updateUser(
        sb.UserAttributes(password: newPassword),
      );
      return true;
    } catch (e) {
      debugPrint('setPassword error: $e');
      return false;
    }
  }

  /// Register a new user via Supabase Auth, then create / update the matching
  /// row in `profiles`. Throws on failure so the UI can show a friendly
  /// error.
  Future<bool> register({
    required String fullName,
    required String phone,
    String? email,
    required DateTime dateOfBirth,
    required int districtId,
    required int subcountyId,
    required int parishId,
    int? villageId,
    String? streetAddress,
    required String districtName,
    required String subcountyName,
    required String parishName,
    String? villageName,
    double? gpsLatitude,
    double? gpsLongitude,
    String? nin,
    String? password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 16+ age check (enforced server-side too, but we re-check defensively).
      final age = _ageFromDob(dateOfBirth);
      if (age < 16) {
        throw Exception('You must be at least 16 years old to register.');
      }

      // Reject duplicate phones up-front so we don't leave behind orphan
      // auth.users rows.
      final existing = await SupabaseConfig.client
          .from('profiles')
          .select('id')
          .eq('phone', phone)
          .maybeSingle();
      if (existing != null) {
        throw Exception(
          'An account with this phone number already exists. Try signing in.',
        );
      }

      final emailToUse = (email != null && email.trim().isNotEmpty)
          ? email.trim()
          : _emailForPhone(phone);
      final pwd = (password != null && password.isNotEmpty)
          ? password
          : 'Traford${phone.substring(phone.length - 6)}!';

      // 1) Create the auth.users row.
      final signUp = await SupabaseConfig.client.auth.signUp(
        email: emailToUse,
        password: pwd,
        data: {
          'full_name': fullName,
          'phone': phone,
        },
      );

      final user = signUp.user;
      if (user == null) {
        throw Exception('Sign-up failed. Please try again.');
      }

      // 2) Upsert the profiles row keyed by the auth user UUID.
      final profileRow = <String, dynamic>{
        'id': user.id,
        'full_name': fullName,
        'phone': phone,
        'email': emailToUse,
        'role': 'customer',
        'date_of_birth': dateOfBirth.toIso8601String().split('T')[0],
        'district_id': districtId,
        'subcounty_id': subcountyId,
        'parish_id': parishId,
        if (villageId != null) 'village_id': villageId,
        if (streetAddress != null && streetAddress.trim().isNotEmpty)
          'street_address': streetAddress.trim(),
        if (nin != null && nin.trim().isNotEmpty) 'nin': nin.trim(),
      };

      try {
        await SupabaseConfig.client
            .from('profiles')
            .upsert(profileRow, onConflict: 'id');
      } catch (e) {
        // If the profile row was auto-created by a trigger, do an UPDATE
        // instead — RLS may forbid INSERT but allow UPDATE on own row.
        debugPrint('profile upsert failed, falling back to update: $e');
        try {
          await SupabaseConfig.client
              .from('profiles')
              .update(profileRow)
              .eq('id', user.id);
        } catch (e2) {
          debugPrint('profile update fallback also failed: $e2');
          // Non-fatal: the auth user exists, profile may sync via trigger.
        }
      }

      // 3) Load whatever ended up in profiles and finish.
      await _loadProfileForUser(user.id);

      _isLoading = false;
      notifyListeners();
      return _isLoggedIn;
    } catch (e) {
      debugPrint('Registration error: $e');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  int _ageFromDob(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  /// No-op guest "login" — there is no public guest row in profiles. We
  /// just keep _isLoggedIn=false so the UI shows the Sign-In prompt. Kept
  /// as a method so the existing call sites compile unchanged.
  Future<void> autoLoginGuest() async {
    // Nothing to do — browsing as guest is the default state.
  }

  Future<void> logout() async {
    try {
      await SupabaseConfig.client.auth.signOut();
    } catch (e) {
      debugPrint('logout error: $e');
    }
    _profile = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}
