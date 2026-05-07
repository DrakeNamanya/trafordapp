import 'package:flutter/material.dart';
import 'supabase_config.dart';
import '../models/product.dart';

class CartService extends ChangeNotifier {
  List<CartItem> _items = [];
  final Set<int> _wishlistProductIds = {};
  bool _isLoading = false;
  int? _userId;

  List<CartItem> get items => _items;
  bool get isLoading => _isLoading;
  int? get userId => _userId;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  int get wishlistCount => _wishlistProductIds.length;

  double get subtotal => _items.fold(0, (sum, item) => sum + item.subtotal);
  double get tax => subtotal * 0.1;
  double get total => subtotal + tax;

  bool isInCart(int productId) =>
      _items.any((item) => item.productId == productId);

  bool isInWishlist(int productId) => _wishlistProductIds.contains(productId);

  void setUserId(int id) {
    _userId = id;
    loadCart();
    loadWishlist();
  }

  // ---- CART OPERATIONS ----

  Future<void> loadCart() async {
    if (_userId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final response = await SupabaseConfig.client
          .from('cart_items')
          .select('*, products(id, name, slug, price, image, stock, unit, category_id, featured, rating, review_count)')
          .eq('user_id', _userId!)
          .order('created_at', ascending: false);

      _items = (response as List)
          .map((json) => CartItem.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading cart: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addToCart(Product product, {int quantity = 1}) async {
    if (_userId == null) return;

    try {
      // Check if already in cart
      final existing = await SupabaseConfig.client
          .from('cart_items')
          .select()
          .eq('user_id', _userId!)
          .eq('product_id', product.id)
          .maybeSingle();

      if (existing != null) {
        await SupabaseConfig.client.from('cart_items').update({
          'quantity': (existing['quantity'] as int) + quantity,
        }).eq('id', existing['id']);
      } else {
        await SupabaseConfig.client.from('cart_items').insert({
          'user_id': _userId,
          'product_id': product.id,
          'quantity': quantity,
        });
      }

      await loadCart();
    } catch (e) {
      debugPrint('Error adding to cart: $e');
    }
  }

  Future<void> updateQuantity(int cartItemId, int quantity) async {
    if (quantity <= 0) {
      await removeFromCart(cartItemId);
      return;
    }

    try {
      await SupabaseConfig.client
          .from('cart_items')
          .update({'quantity': quantity})
          .eq('id', cartItemId);
      await loadCart();
    } catch (e) {
      debugPrint('Error updating quantity: $e');
    }
  }

  Future<void> removeFromCart(int cartItemId) async {
    try {
      await SupabaseConfig.client
          .from('cart_items')
          .delete()
          .eq('id', cartItemId);
      await loadCart();
    } catch (e) {
      debugPrint('Error removing from cart: $e');
    }
  }

  Future<void> clearCart() async {
    if (_userId == null) return;
    try {
      await SupabaseConfig.client
          .from('cart_items')
          .delete()
          .eq('user_id', _userId!);
      _items = [];
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing cart: $e');
    }
  }

  // ---- WISHLIST OPERATIONS ----

  Future<void> loadWishlist() async {
    if (_userId == null) return;
    try {
      final response = await SupabaseConfig.client
          .from('wishlist_items')
          .select('product_id')
          .eq('user_id', _userId!);

      _wishlistProductIds.clear();
      for (final row in response as List) {
        _wishlistProductIds.add(row['product_id'] as int);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading wishlist: $e');
    }
  }

  Future<void> toggleWishlist(int productId) async {
    if (_userId == null) return;

    try {
      if (_wishlistProductIds.contains(productId)) {
        await SupabaseConfig.client
            .from('wishlist_items')
            .delete()
            .eq('user_id', _userId!)
            .eq('product_id', productId);
        _wishlistProductIds.remove(productId);
      } else {
        await SupabaseConfig.client.from('wishlist_items').insert({
          'user_id': _userId,
          'product_id': productId,
        });
        _wishlistProductIds.add(productId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling wishlist: $e');
    }
  }
}
