import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_config.dart';
import '../models/product.dart';

/// Cart + wishlist state.
///
/// Local-first: the cart is always persisted to SharedPreferences so it
/// survives app restarts for both guests and signed-in users. Signed-in
/// users additionally mirror writes to the Supabase `cart_items` table.
class CartService extends ChangeNotifier {
  static const String _kCartKey = 'tff_local_cart_v1';
  static const String _kWishlistKey = 'tff_local_wishlist_v1';

  List<CartItem> _items = [];
  final Set<int> _wishlistProductIds = {};
  bool _isLoading = false;
  int? _userId;
  // Monotonic id generator for local-only cart line ids (avoid collision with
  // server ids which are positive ints).
  int _localIdSeq = -1;

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

  // ---------------------------------------------------------------------------
  // INIT / SIGN-IN
  // ---------------------------------------------------------------------------

  /// Call once at app start (from main.dart) to restore the cart from disk.
  /// Safe to call before the user signs in.
  Future<void> hydrateFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCartKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _items = list.map(CartItem.fromLocalJson).toList();
        // Make sure the local id generator never collides with whatever is
        // already on disk.
        for (final item in _items) {
          if (item.id <= _localIdSeq) _localIdSeq = item.id - 1;
        }
      }
      final wl = prefs.getString(_kWishlistKey);
      if (wl != null && wl.isNotEmpty) {
        final ids = (jsonDecode(wl) as List).cast<int>();
        _wishlistProductIds
          ..clear()
          ..addAll(ids);
      }
    } catch (e) {
      debugPrint('hydrateFromLocal error: $e');
    }
    notifyListeners();
  }

  /// The legacy `users.id = 2` shared "guest" row. We deliberately do NOT
  /// sync that account's server cart_items because they are shared across
  /// every guest device — pulling them would corrupt this device's cart.
  static const int _kSharedGuestUserId = 2;

  /// Called by AuthService once we know who the user is. For real users we
  /// merge the server cart in; for the shared guest sentinel we keep the
  /// device-local cart authoritative.
  void setUserId(int id) {
    _userId = id;
    if (id != _kSharedGuestUserId) {
      // Real user: pull server cart in the background and merge.
      _loadServerCartAndMerge();
      loadWishlist();
    }
  }

  /// Clears the user binding (sign-out). Local cart is preserved on the
  /// device so a guest can keep shopping.
  void clearUserId() {
    _userId = null;
    notifyListeners();
  }

  Future<void> _persistLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          jsonEncode(_items.map((it) => it.toLocalJson()).toList());
      await prefs.setString(_kCartKey, encoded);
    } catch (e) {
      debugPrint('Cart _persistLocal error: $e');
    }
  }

  Future<void> _persistWishlistLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kWishlistKey, jsonEncode(_wishlistProductIds.toList()));
    } catch (e) {
      debugPrint('Wishlist _persistLocal error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // CART OPERATIONS (local-first)
  // ---------------------------------------------------------------------------

  /// Best-effort sync: pulls cart_items for the signed-in user and merges
  /// them with whatever is in the local cart (sum quantities by product_id).
  Future<void> _loadServerCartAndMerge() async {
    if (_userId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await SupabaseConfig.client
          .from('cart_items')
          .select(
              '*, products(id, name, slug, price, image, stock, unit, category_id, featured, rating, review_count)')
          .eq('user_id', _userId!)
          .order('created_at', ascending: false);

      final serverItems = (response as List)
          .map((json) => CartItem.fromJson(json as Map<String, dynamic>))
          .toList();

      // Merge: server items + local items, summed by productId.
      final byPid = <int, CartItem>{};
      for (final it in [..._items, ...serverItems]) {
        if (byPid.containsKey(it.productId)) {
          byPid[it.productId]!.quantity += it.quantity;
        } else {
          byPid[it.productId] = CartItem(
            id: it.id,
            productId: it.productId,
            product: it.product,
            quantity: it.quantity,
          );
        }
      }
      _items = byPid.values.toList();
      await _persistLocal();
    } catch (e) {
      // Network/RLS hiccups must not blow away the local cart.
      debugPrint('Cart server-merge error: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  /// Legacy alias retained so existing callers continue to compile. For
  /// signed-in users this re-syncs with the server; for guests it is a no-op
  /// because the in-memory list is already authoritative.
  Future<void> loadCart() async {
    if (_userId != null) {
      await _loadServerCartAndMerge();
    } else {
      notifyListeners();
    }
  }

  /// True only when this device is bound to a real (non-shared) user that
  /// owns a private server-side cart we should mirror to.
  bool get _shouldMirrorToServer =>
      _userId != null && _userId != _kSharedGuestUserId;

  Future<void> addToCart(Product product, {int quantity = 1}) async {
    // 1) Update local state immediately so the UI reflects the change.
    final idx = _items.indexWhere((it) => it.productId == product.id);
    if (idx >= 0) {
      _items[idx].quantity += quantity;
    } else {
      _items.add(CartItem(
        id: _localIdSeq--, // negative id => local-only line
        productId: product.id,
        product: product,
        quantity: quantity,
      ));
    }
    await _persistLocal();
    notifyListeners();

    // 2) Best-effort mirror to server when signed in as a real user.
    if (_shouldMirrorToServer) {
      try {
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
      } catch (e) {
        debugPrint('addToCart server mirror failed (kept locally): $e');
      }
    }
  }

  Future<void> updateQuantity(int cartItemId, int quantity) async {
    if (quantity <= 0) {
      await removeFromCart(cartItemId);
      return;
    }
    final idx = _items.indexWhere((it) => it.id == cartItemId);
    if (idx >= 0) {
      _items[idx].quantity = quantity;
      await _persistLocal();
      notifyListeners();
    }
    if (_shouldMirrorToServer && cartItemId > 0) {
      try {
        await SupabaseConfig.client
            .from('cart_items')
            .update({'quantity': quantity}).eq('id', cartItemId);
      } catch (e) {
        debugPrint('updateQuantity server mirror failed: $e');
      }
    }
  }

  Future<void> removeFromCart(int cartItemId) async {
    _items.removeWhere((it) => it.id == cartItemId);
    await _persistLocal();
    notifyListeners();
    if (_shouldMirrorToServer && cartItemId > 0) {
      try {
        await SupabaseConfig.client
            .from('cart_items')
            .delete()
            .eq('id', cartItemId);
      } catch (e) {
        debugPrint('removeFromCart server mirror failed: $e');
      }
    }
  }

  /// Full clear — wipes both local and (if signed in as a real user)
  /// server cart_items.
  Future<void> clearCart() async {
    _items = [];
    await _persistLocal();
    notifyListeners();
    if (_shouldMirrorToServer) {
      try {
        await SupabaseConfig.client
            .from('cart_items')
            .delete()
            .eq('user_id', _userId!);
      } catch (e) {
        debugPrint('clearCart server delete failed: $e');
      }
    }
  }

  /// Local-only clear (no server round-trip). Used after a successful
  /// guest checkout — kept for backwards compatibility with callers that
  /// still distinguish guest vs. signed-in flows.
  void clearCartLocal() {
    _items = [];
    notifyListeners();
    // Fire-and-forget persistence — UI doesn't need to wait.
    _persistLocal();
  }

  // ---------------------------------------------------------------------------
  // WISHLIST (local-first, with optional server mirror)
  // ---------------------------------------------------------------------------

  Future<void> loadWishlist() async {
    if (_userId == null) return;
    try {
      final response = await SupabaseConfig.client
          .from('wishlist_items')
          .select('product_id')
          .eq('user_id', _userId!);

      for (final row in response as List) {
        _wishlistProductIds.add(row['product_id'] as int);
      }
      await _persistWishlistLocal();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading wishlist: $e');
    }
  }

  Future<void> toggleWishlist(int productId) async {
    if (_wishlistProductIds.contains(productId)) {
      _wishlistProductIds.remove(productId);
    } else {
      _wishlistProductIds.add(productId);
    }
    await _persistWishlistLocal();
    notifyListeners();

    if (_userId == null) return;
    try {
      if (_wishlistProductIds.contains(productId)) {
        await SupabaseConfig.client.from('wishlist_items').insert({
          'user_id': _userId,
          'product_id': productId,
        });
      } else {
        await SupabaseConfig.client
            .from('wishlist_items')
            .delete()
            .eq('user_id', _userId!)
            .eq('product_id', productId);
      }
    } catch (e) {
      debugPrint('toggleWishlist server mirror failed: $e');
    }
  }
}
