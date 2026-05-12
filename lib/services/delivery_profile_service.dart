import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the customer's last successful delivery details on-device so the
/// checkout form can auto-fill next time and the user doesn't have to retype
/// their name, phone and email on every order.
///
/// Stored locally (SharedPreferences) — no PII leaves the device until the
/// user actually places an order.
class DeliveryProfileService extends ChangeNotifier {
  static const _kKey = 'tff_delivery_profile_v1';

  String? _fullName;
  String? _phone;
  String? _email;
  String? _deliveryAddress;
  String? _deliveryCity;

  bool _loaded = false;

  String? get fullName => _fullName;
  String? get phone => _phone;
  String? get email => _email;
  String? get deliveryAddress => _deliveryAddress;
  String? get deliveryCity => _deliveryCity;
  bool get hasProfile =>
      (_fullName?.isNotEmpty ?? false) && (_phone?.isNotEmpty ?? false);
  bool get isLoaded => _loaded;

  /// Read any previously saved delivery details from disk. Safe to call on
  /// startup — silently no-ops if nothing has been saved yet.
  Future<void> hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw != null && raw.isNotEmpty) {
        final map = Map<String, dynamic>.from(json.decode(raw) as Map);
        _fullName = map['full_name'] as String?;
        _phone = map['phone'] as String?;
        _email = map['email'] as String?;
        _deliveryAddress = map['delivery_address'] as String?;
        _deliveryCity = map['delivery_city'] as String?;
      }
    } catch (e) {
      debugPrint('DeliveryProfileService hydrate failed: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  /// Save the customer's delivery details after a successful checkout.
  Future<void> save({
    required String fullName,
    required String phone,
    String? email,
    required String deliveryAddress,
    String? deliveryCity,
  }) async {
    _fullName = fullName.trim();
    _phone = phone.trim();
    _email = email?.trim();
    _deliveryAddress = deliveryAddress.trim();
    _deliveryCity = deliveryCity?.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kKey,
        json.encode({
          'full_name': _fullName,
          'phone': _phone,
          'email': _email,
          'delivery_address': _deliveryAddress,
          'delivery_city': _deliveryCity,
        }),
      );
    } catch (e) {
      debugPrint('DeliveryProfileService save failed: $e');
    }
    notifyListeners();
  }

  /// Update just the delivery address without touching name/phone — useful
  /// for the "edit address only" flow.
  Future<void> updateAddress({
    required String deliveryAddress,
    String? deliveryCity,
  }) async {
    _deliveryAddress = deliveryAddress.trim();
    if (deliveryCity != null) _deliveryCity = deliveryCity.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kKey,
        json.encode({
          'full_name': _fullName,
          'phone': _phone,
          'email': _email,
          'delivery_address': _deliveryAddress,
          'delivery_city': _deliveryCity,
        }),
      );
    } catch (e) {
      debugPrint('DeliveryProfileService updateAddress failed: $e');
    }
    notifyListeners();
  }

  Future<void> clear() async {
    _fullName = null;
    _phone = null;
    _email = null;
    _deliveryAddress = null;
    _deliveryCity = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kKey);
    } catch (e) {
      debugPrint('DeliveryProfileService clear failed: $e');
    }
    notifyListeners();
  }
}
