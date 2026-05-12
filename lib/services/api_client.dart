import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Thin HTTP client for the Traford Fresh public API
/// (https://trafordfresh.pages.dev/api/public/*).
///
/// The Flutter app talks to this layer instead of writing to Supabase directly,
/// because:
///  - Server-side price lookup (we never trust client prices)
///  - Server creates the auth user + profile for guest checkouts
///  - Agro orders run through the configurable approval-threshold trigger
class ApiClient {
  static const String baseUrl = 'https://trafordfresh.pages.dev/api/public';

  /// Optional bearer token for staff-only endpoints (Agro shop, agro orders).
  /// Set this from AuthService when a Supabase session is available.
  static String? bearerToken;

  static Map<String, String> _headers({bool withAuth = false}) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth && bearerToken != null && bearerToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $bearerToken';
    }
    return h;
  }

  // ---------------------------------------------------------------------------
  // PUBLIC CATALOG (no auth required) — Farm Fresh products
  // ---------------------------------------------------------------------------

  /// GET /products  — public Farm Fresh catalogue.
  /// Optional: search query, category id, limit (default 100, max 200).
  static Future<List<Map<String, dynamic>>> getProducts({
    String? search,
    int? categoryId,
    int limit = 100,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (categoryId != null) params['category_id'] = categoryId.toString();

    final uri = Uri.parse('$baseUrl/products')
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers());
    if (res.statusCode != 200) {
      throw ApiException('Failed to load products', res.statusCode, res.body);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(body['data'] as List? ?? []);
  }

  /// GET /categories — Farm Fresh categories (audience='public').
  static Future<List<Map<String, dynamic>>> getCategories() async {
    final res = await http.get(
      Uri.parse('$baseUrl/categories'),
      headers: _headers(),
    );
    if (res.statusCode != 200) {
      throw ApiException(
          'Failed to load categories', res.statusCode, res.body);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(body['data'] as List? ?? []);
  }

  // ---------------------------------------------------------------------------
  // GUEST CHECKOUT — public endpoint (server creates auth user + profile)
  // ---------------------------------------------------------------------------

  /// POST /orders/guest-checkout
  ///
  /// items: [{product_id, quantity}]
  /// Server validates audience='public', looks up prices, and applies the
  /// default_shipping_fee_ugx from app_settings.
  static Future<Map<String, dynamic>> guestCheckout({
    required String fullName,
    required String phone,
    String? email,
    required String deliveryAddress,
    String? deliveryCity,
    String? notes,
    required List<Map<String, dynamic>> items,
    /// 'delivery' (default — charge shipping fee) or 'pickup' (no shipping fee).
    String deliveryMethod = 'delivery',
  }) async {
    final body = <String, dynamic>{
      'full_name': fullName,
      'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      'delivery_address': deliveryAddress,
      if (deliveryCity != null && deliveryCity.isNotEmpty)
        'delivery_city': deliveryCity,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'delivery_method': deliveryMethod,
      'items': items,
    };

    final res = await http.post(
      Uri.parse('$baseUrl/orders/guest-checkout'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      final msg = decoded is Map && decoded['error'] != null
          ? decoded['error'].toString()
          : 'Order failed (${res.statusCode})';
      throw ApiException(msg, res.statusCode, res.body);
    }
    return Map<String, dynamic>.from(decoded as Map);
  }

  /// GET /orders/by-number/:order_number — public refresh of a single order
  /// status. The TFF order number is the customer's only handle.
  static Future<Map<String, dynamic>> getOrderByNumber(String orderNumber) async {
    final encoded = Uri.encodeComponent(orderNumber);
    final res = await http.get(
      Uri.parse('$baseUrl/orders/by-number/$encoded'),
      headers: _headers(),
    );
    if (res.statusCode == 404) {
      throw ApiException('Order not found', 404, res.body);
    }
    if (res.statusCode != 200) {
      throw ApiException(
          'Failed to refresh order status', res.statusCode, res.body);
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  // ---------------------------------------------------------------------------
  // STAFF AGRO SHOP — JWT required (field_staff / admin_staff / admin / director)
  // ---------------------------------------------------------------------------

  /// GET /agro-products — agro inputs catalogue (audience='field_staff_only').
  static Future<List<Map<String, dynamic>>> getAgroProducts({
    String? search,
    int? categoryId,
    int limit = 100,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (categoryId != null) params['category_id'] = categoryId.toString();

    final uri = Uri.parse('$baseUrl/agro-products')
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers(withAuth: true));
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw ApiException(
          'Sign in as field staff to view agro inputs',
          res.statusCode,
          res.body);
    }
    if (res.statusCode != 200) {
      throw ApiException(
          'Failed to load agro products', res.statusCode, res.body);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(body['data'] as List? ?? []);
  }

  /// POST /agro-orders — staff places an agro-input order.
  /// Server enforces audience match + applies the auto-route trigger
  /// (≤ threshold => auto-confirmed, > threshold => pending admin approval).
  static Future<Map<String, dynamic>> placeAgroOrder({
    required String deliveryAddress,
    String? deliveryCity,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final body = <String, dynamic>{
      'delivery_address': deliveryAddress,
      if (deliveryCity != null && deliveryCity.isNotEmpty)
        'delivery_city': deliveryCity,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'items': items,
    };

    final res = await http.post(
      Uri.parse('$baseUrl/agro-orders'),
      headers: _headers(withAuth: true),
      body: jsonEncode(body),
    );
    final decoded = jsonDecode(res.body);
    if (res.statusCode != 200 && res.statusCode != 201) {
      final msg = decoded is Map && decoded['error'] != null
          ? decoded['error'].toString()
          : 'Agro order failed (${res.statusCode})';
      throw ApiException(msg, res.statusCode, res.body);
    }
    return Map<String, dynamic>.from(decoded as Map);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String body;
  ApiException(this.message, this.statusCode, this.body);

  @override
  String toString() {
    if (kDebugMode) return 'ApiException($statusCode): $message — $body';
    return message;
  }
}
