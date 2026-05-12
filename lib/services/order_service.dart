import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_config.dart';
import 'api_client.dart';
import '../models/product.dart';

class OrderService extends ChangeNotifier {
  /// Local-cache key — guest orders (placed without a real auth user) are
  /// stashed here so the user can still track them in the Orders tab on the
  /// same device. Persists across app restarts.
  static const _kLocalOrdersKey = 'tff_local_orders_v1';
  static const int _kSharedGuestUserId = 2;

  List<Order> _orders = [];
  bool _isLoading = false;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;

  /// Load orders from local cache (guest orders) and merge with server orders
  /// for logged-in users. Guest userId (2) only reads from the local cache so
  /// every device shows its own order history.
  Future<void> loadOrders(int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Always start from the local cache so the user sees their guest orders
      // (the ones placed without a real account) instantly.
      final localOrders = await _loadLocalOrders();

      if (userId == _kSharedGuestUserId) {
        _orders = localOrders;
      } else {
        // Logged-in user: fetch from server + merge.
        try {
          final response = await SupabaseConfig.client
              .from('orders')
              .select()
              .eq('user_id', userId)
              .order('created_at', ascending: false);

          final serverOrders = (response as List)
              .map((json) => Order.fromJson(json as Map<String, dynamic>))
              .toList();

          for (final order in serverOrders) {
            final itemsResponse = await SupabaseConfig.client
                .from('order_items')
                .select()
                .eq('order_id', order.id);
            order.items = (itemsResponse as List)
                .map((json) =>
                    OrderItem.fromJson(json as Map<String, dynamic>))
                .toList();
          }

          // Merge — server orders first (authoritative), then locals that
          // don't already exist server-side (matched by order_number).
          final serverNumbers =
              serverOrders.map((o) => o.orderNumber).toSet();
          final localOnly = localOrders
              .where((o) => !serverNumbers.contains(o.orderNumber))
              .toList();
          _orders = [...serverOrders, ...localOnly];
        } catch (e) {
          debugPrint('Error loading server orders, using local cache: $e');
          _orders = localOrders;
        }
      }
    } catch (e) {
      debugPrint('Error loading orders: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Record an order placed through the public guest-checkout API so it
  /// shows up in the Orders tab. Accepts the response map returned by
  /// `ApiClient.guestCheckout(...)` plus the items the user actually checked
  /// out (since the response shape varies).
  Future<void> recordGuestOrder({
    required Map<String, dynamic> response,
    required List<CartItem> cartItems,
    String? deliveryAddress,
    String? deliveryCity,
    String? phone,
    String? paymentMethod,
  }) async {
    try {
      // The public API returns { order: {...} } OR the order fields at the
      // top level. Normalize.
      final raw = (response['order'] is Map<String, dynamic>)
          ? response['order'] as Map<String, dynamic>
          : response;

      final orderNumber = (raw['order_number'] as String?) ?? 'TFF-LOCAL';
      final status = (raw['status'] as String?) ?? 'pending';
      final totalRaw = raw['total'] ?? raw['total_amount'];
      final double total = totalRaw is num
          ? totalRaw.toDouble()
          : double.tryParse('${totalRaw ?? ''}') ?? 0.0;
      final subtotalRaw = raw['subtotal'];
      final double subtotal = subtotalRaw is num
          ? subtotalRaw.toDouble()
          : cartItems.fold<double>(0, (s, ci) => s + ci.subtotal);

      // Try numeric server id; fall back to a unique local id derived from
      // the order_number string hash so different orders don't collide.
      int orderId;
      final rawId = raw['id'] ?? raw['order_id'];
      if (rawId is int) {
        orderId = rawId;
      } else if (rawId is String) {
        orderId = int.tryParse(rawId) ?? orderNumber.hashCode;
      } else {
        orderId = orderNumber.hashCode;
      }

      final items = cartItems
          .map((ci) => OrderItem(
                productName: ci.product.name,
                quantity: ci.quantity,
                price: ci.product.price,
              ))
          .toList();

      final order = Order(
        id: orderId,
        orderNumber: orderNumber,
        status: status,
        subtotal: subtotal,
        tax: 0,
        total: total,
        shippingAddress: deliveryAddress,
        shippingCity: deliveryCity,
        shippingPhone: phone,
        paymentMethod: paymentMethod,
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
        items: items,
      );

      // Prepend to local cache (newest first), de-dup by order_number.
      final existing = await _loadLocalOrders();
      final filtered = existing
          .where((o) => o.orderNumber != order.orderNumber)
          .toList();
      final next = [order, ...filtered];
      await _persistLocalOrders(next);

      // Show immediately in the Orders tab without waiting for a reload.
      _orders = [order, ..._orders.where((o) => o.orderNumber != order.orderNumber)];
      notifyListeners();
    } catch (e) {
      debugPrint('Error recording guest order locally: $e');
    }
  }

  /// Re-fetch the public order-by-number record and update the matching
  /// cached order's status + payment_status. This is the bridge that keeps
  /// guest customers in sync with the admin portal — guests have no Supabase
  /// JWT, so they can't query `orders` directly, but the TFF order_number is
  /// a long random token we expose through `/api/public/orders/by-number/`.
  Future<bool> refreshOrderStatus(String orderNumber) async {
    if (orderNumber.isEmpty) return false;
    try {
      final response = await ApiClient.getOrderByNumber(orderNumber);
      // The public endpoint returns the order at the top level (with `items`
      // and `payments` mixed in). Normalize.
      final raw = (response['order'] is Map<String, dynamic>)
          ? response['order'] as Map<String, dynamic>
          : response;
      final newStatus = (raw['status'] as String?) ?? '';
      if (newStatus.isEmpty) return false;

      // Try to infer payment_status from the latest payment row.
      String? newPaymentStatus;
      final payments = response['payments'];
      if (payments is List && payments.isNotEmpty) {
        final last = payments.last;
        if (last is Map && last['status'] is String) {
          newPaymentStatus = last['status'] as String;
        }
      }

      var changed = false;
      for (final o in _orders) {
        if (o.orderNumber == orderNumber) {
          if (o.status != newStatus) {
            o.status = newStatus;
            changed = true;
          }
          if (newPaymentStatus != null &&
              o.paymentStatus != newPaymentStatus) {
            o.paymentStatus = newPaymentStatus;
            changed = true;
          }
        }
      }

      if (changed) {
        await _persistLocalOrders(_orders);
        notifyListeners();
      }
      return changed;
    } catch (e) {
      debugPrint('refreshOrderStatus failed for $orderNumber: $e');
      return false;
    }
  }

  /// Refresh the status of every cached order. Used for pull-to-refresh on
  /// the Orders tab.
  Future<void> refreshAllStatuses() async {
    if (_orders.isEmpty) return;
    final numbers =
        _orders.map((o) => o.orderNumber).where((n) => n.isNotEmpty).toList();
    for (final n in numbers) {
      await refreshOrderStatus(n);
    }
  }

  Future<List<Order>> _loadLocalOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLocalOrdersKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = json.decode(raw);
      if (decoded is! List) return [];
      return decoded
          .map((e) => Order.fromLocalJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('Local orders load failed: $e');
      return [];
    }
  }

  Future<void> _persistLocalOrders(List<Order> orders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          json.encode(orders.map((o) => o.toLocalJson()).toList());
      await prefs.setString(_kLocalOrdersKey, encoded);
    } catch (e) {
      debugPrint('Local orders persist failed: $e');
    }
  }

  /// Legacy direct-Supabase order placement — kept for backwards compatibility
  /// but the customer Flutter app now uses ApiClient.guestCheckout() instead.
  Future<Order?> placeOrder({
    required int userId,
    required List<CartItem> items,
    required double subtotal,
    required double tax,
    required double total,
    required String shippingAddress,
    required String shippingCity,
    required String shippingPhone,
    required String paymentMethod,
  }) async {
    try {
      final orderNumber =
          'TFF-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecond}';

      final orderResponse = await SupabaseConfig.client
          .from('orders')
          .insert({
            'user_id': userId,
            'order_number': orderNumber,
            'status': 'pending',
            'subtotal': subtotal,
            'tax': tax,
            'total': total,
            'shipping_address': shippingAddress,
            'shipping_city': shippingCity,
            'shipping_country': 'Uganda',
            'shipping_phone': shippingPhone,
            'payment_method': paymentMethod,
            'payment_status': 'pending',
          })
          .select()
          .single();

      final orderId = orderResponse['id'] as int;
      final orderItems = items
          .map((ci) => {
                'order_id': orderId,
                'product_id': ci.productId,
                'product_name': ci.product.name,
                'quantity': ci.quantity,
                'price': ci.product.price,
              })
          .toList();
      await SupabaseConfig.client.from('order_items').insert(orderItems);
      await SupabaseConfig.client
          .from('cart_items')
          .delete()
          .eq('user_id', userId);

      await _createOrderNotification(
        userId: userId,
        orderId: orderId,
        title: 'Order Placed',
        message:
            'Your order $orderNumber has been placed successfully and sent to admin for processing. We will notify you when it\'s being processed.',
      );

      await loadOrders(userId);
      return Order.fromJson(orderResponse);
    } catch (e) {
      debugPrint('Error placing order: $e');
      return null;
    }
  }

  Future<void> _createOrderNotification({
    required int userId,
    required int orderId,
    required String title,
    required String message,
  }) async {
    try {
      await SupabaseConfig.client.from('order_notifications').insert({
        'user_id': userId,
        'order_id': orderId,
        'title': title,
        'message': message,
        'is_read': false,
      });
    } catch (e) {
      debugPrint('Notification insert skipped: $e');
    }
  }
}
