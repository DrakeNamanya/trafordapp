import 'package:flutter/foundation.dart';
import 'supabase_config.dart';

/// SupplierService — submits "Become Our Supplier" applications into the
/// public.suppliers table created by migration 20260301000001.
///
/// The admin portal reads this table via a "Suppliers" tab side-by-side with
/// "Customer Orders".
class SupplierService extends ChangeNotifier {
  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  /// Insert a new supplier application.
  /// Returns the inserted row on success, or throws on failure.
  Future<Map<String, dynamic>> submitApplication({
    int? userId,
    required String fullName,
    required String phone,
    String? email,
    required String product,
    String? quantity,
    String? frequency,
    String? notes,
    int? districtId,
    int? subcountyId,
    int? parishId,
    int? villageId,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final insertData = <String, dynamic>{
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'product': product.trim(),
        'status': 'pending',
      };

      if (userId != null) insertData['user_id'] = userId;
      if (email != null && email.trim().isNotEmpty) {
        insertData['email'] = email.trim();
      }
      if (quantity != null && quantity.trim().isNotEmpty) {
        insertData['quantity'] = quantity.trim();
      }
      if (frequency != null && frequency.trim().isNotEmpty) {
        insertData['frequency'] = frequency.trim();
      }
      if (notes != null && notes.trim().isNotEmpty) {
        insertData['notes'] = notes.trim();
      }
      if (districtId != null) insertData['district_id'] = districtId;
      if (subcountyId != null) insertData['subcounty_id'] = subcountyId;
      if (parishId != null) insertData['parish_id'] = parishId;
      if (villageId != null) insertData['village_id'] = villageId;

      final row = await SupabaseConfig.client
          .from('suppliers')
          .insert(insertData)
          .select()
          .single();

      return row;
    } catch (e) {
      debugPrint('SupplierService.submitApplication error: $e');
      rethrow;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// (Optional) Fetch this user's prior applications, newest first.
  Future<List<Map<String, dynamic>>> myApplications(int userId) async {
    try {
      final res = await SupabaseConfig.client
          .from('suppliers')
          .select()
          .eq('user_id', userId);
      final list = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      list.sort((a, b) => (b['created_at'] ?? '')
          .toString()
          .compareTo((a['created_at'] ?? '').toString()));
      return list;
    } catch (e) {
      debugPrint('SupplierService.myApplications error: $e');
      return [];
    }
  }
}
