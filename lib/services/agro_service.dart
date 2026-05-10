import 'package:flutter/material.dart';
import '../models/product.dart';
import 'api_client.dart';

/// Service for the staff-only Agro Inputs shop.
///
/// Talks to /api/public/agro-products and /api/public/agro-orders, both of
/// which require a Supabase JWT for a profile with role in
/// {field_staff, admin_staff, admin, director}.
class AgroService extends ChangeNotifier {
  List<Product> _products = [];
  final List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get products => _products;
  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Items selected for the current agro order (in-memory cart).
  /// `Map<productId, quantity>`
  final Map<int, int> _cart = {};
  Map<int, int> get cart => Map.unmodifiable(_cart);
  int get cartCount => _cart.values.fold(0, (sum, q) => sum + q);

  double cartSubtotal() {
    double total = 0;
    for (final entry in _cart.entries) {
      final p = _products.firstWhere(
        (x) => x.id == entry.key,
        orElse: () => Product(
            id: entry.key, name: '', slug: '', categoryId: 0, price: 0),
      );
      total += p.price * entry.value;
    }
    return total;
  }

  void addToCart(int productId, [int qty = 1]) {
    _cart[productId] = (_cart[productId] ?? 0) + qty;
    notifyListeners();
  }

  void setQuantity(int productId, int qty) {
    if (qty <= 0) {
      _cart.remove(productId);
    } else {
      _cart[productId] = qty;
    }
    notifyListeners();
  }

  void removeFromCart(int productId) {
    _cart.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  /// Load the agro catalogue. Requires ApiClient.bearerToken to be set.
  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await ApiClient.getAgroProducts(limit: 200);
      _products = raw.map((j) => Product.fromJson(j)).toList();
    } catch (e) {
      _error = e.toString();
      _products = [];
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Place the in-memory agro cart as an order via /agro-orders.
  /// Returns the parsed order response on success.
  Future<Map<String, dynamic>> placeOrder({
    required String deliveryAddress,
    String? deliveryCity,
    String? notes,
  }) async {
    if (_cart.isEmpty) {
      throw Exception('Agro cart is empty');
    }
    final items = _cart.entries
        .map((e) => {'product_id': e.key, 'quantity': e.value})
        .toList();

    final result = await ApiClient.placeAgroOrder(
      deliveryAddress: deliveryAddress,
      deliveryCity: deliveryCity,
      notes: notes,
      items: items,
    );

    // Clear cart on success
    _cart.clear();
    notifyListeners();
    return result;
  }
}
