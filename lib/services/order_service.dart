import 'package:flutter/material.dart';
import 'supabase_config.dart';
import '../models/product.dart';

class OrderService extends ChangeNotifier {
  List<Order> _orders = [];
  bool _isLoading = false;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;

  Future<void> loadOrders(int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await SupabaseConfig.client
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _orders = (response as List)
          .map((json) => Order.fromJson(json as Map<String, dynamic>))
          .toList();

      // Load items for each order
      for (final order in _orders) {
        final itemsResponse = await SupabaseConfig.client
            .from('order_items')
            .select()
            .eq('order_id', order.id);

        order.items = (itemsResponse as List)
            .map((json) => OrderItem.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading orders: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

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

      // Create order
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

      // Create order items
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

      // Clear user's cart
      await SupabaseConfig.client
          .from('cart_items')
          .delete()
          .eq('user_id', userId);

      // Create order notification
      await _createOrderNotification(
        userId: userId,
        orderId: orderId,
        title: 'Order Placed',
        message:
            'Your order $orderNumber has been placed successfully and sent to admin for processing. We will notify you when it\'s being processed.',
      );

      // Reload orders
      await loadOrders(userId);

      return Order.fromJson(orderResponse);
    } catch (e) {
      debugPrint('Error placing order: $e');
      return null;
    }
  }

  /// Create a notification for order status updates
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
      // Notification table may not exist yet - skip silently
      debugPrint('Notification insert skipped: $e');
    }
  }
}
