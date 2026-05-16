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

  List<Order> _orders = [];
  bool _isLoading = false;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;

  /// Load orders from local cache (guest orders) and merge with server orders.
  ///
  /// New flow (Dec 2025):
  ///   - Always start from the on-device local cache (guest orders + any
  ///     locally-recorded confirmations) for an instant first paint.
  ///   - If a `phone` is supplied, hit POST /orders/by-phone — a service-role
  ///     endpoint that returns every customer-typed order for that phone
  ///     number. This is what makes "previous orders" actually appear after
  ///     the user signs in (RLS on the profiles + orders tables was hiding
  ///     them before).
  ///   - If `isStaff` is true, additionally pull GET /agro-orders/mine using
  ///     the Supabase JWT so staff see their agro orders in the same tab.
  ///   - Merge by order_number (server is authoritative; locals fill the gap).
  Future<void> loadOrders(
    int userId, {
    String? phone,
    bool isStaff = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1) Start from the local cache so guest/just-checked-out orders
      //    appear immediately.
      final localOrders = await _loadLocalOrders();
      List<Order> serverOrders = [];

      // 2) Phone-based lookup for customer orders (works for both signed-in
      //    customers AND for someone who placed a guest order but later
      //    creates an account on the same phone).
      if (phone != null && phone.trim().isNotEmpty) {
        try {
          final rows = await ApiClient.getOrdersByPhone(phone.trim());
          serverOrders = rows.map(_orderFromPublicJson).toList();
        } catch (e) {
          debugPrint('orders/by-phone failed: $e');
        }
      }

      // 3) Staff agro orders.
      if (isStaff) {
        try {
          final rows = await ApiClient.getMyAgroOrders();
          final agroOrders = rows.map(_orderFromPublicJson).toList();
          // Tag agro orders so the UI can visually distinguish them.
          serverOrders = [...serverOrders, ...agroOrders];
        } catch (e) {
          debugPrint('agro-orders/mine failed: $e');
        }
      }

      // 4) Merge — server orders first (authoritative), then locals that
      //    don't already exist server-side (matched by order_number).
      final serverNumbers =
          serverOrders.map((o) => o.orderNumber).toSet();
      final localOnly = localOrders
          .where((o) => !serverNumbers.contains(o.orderNumber))
          .toList();
      // Sort merged list by createdAt desc.
      final merged = [...serverOrders, ...localOnly];
      merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _orders = merged;
    } catch (e) {
      debugPrint('Error loading orders: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Parse an order from the public /orders/by-phone or /agro-orders/mine
  /// response, where line items are embedded under `items` and amounts may
  /// be returned as strings.
  Order _orderFromPublicJson(Map<String, dynamic> json) {
    double parseAmount(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    final rawItems = (json['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map((it) {
          final m = Map<String, dynamic>.from(it);
          return OrderItem(
            productName: m['product_name'] as String? ?? 'Product',
            quantity: m['quantity'] as int? ?? 1,
            price: parseAmount(m['unit_price'] ?? m['price'] ?? m['subtotal']),
          );
        })
        .toList();

    return Order(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      orderNumber: (json['order_number'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'pending',
      subtotal: parseAmount(json['subtotal']),
      tax: parseAmount(json['tax'] ?? json['shipping_fee']),
      total: parseAmount(json['total']),
      shippingAddress: json['shipping_address'] as String?,
      shippingCity: json['shipping_city'] as String?,
      shippingPhone: json['shipping_phone'] as String?,
      paymentMethod: json['payment_method'] as String?,
      paymentStatus: (json['payment_status'] as String?) ?? 'pending',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      items: items,
    );
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

  /// Wipe the on-device orders (in-memory + SharedPreferences). Called on
  /// logout so the next signed-in user doesn't see the previous user's
  /// cached order history.
  Future<void> clearLocalCache() async {
    _orders = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLocalOrdersKey);
    } catch (e) {
      debugPrint('OrderService clearLocalCache failed: $e');
    }
    notifyListeners();
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
