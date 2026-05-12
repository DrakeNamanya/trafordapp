import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import 'notifications_screen.dart';

class OrdersScreen extends StatefulWidget {
  final void Function(int)? onNavigate;

  const OrdersScreen({super.key, this.onNavigate});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      // Always reload — even guests (userId=2) need to see their local
      // order cache. OrderService.loadOrders() returns the local cache for
      // guests and merges server + local for signed-in users.
      final userIdToLoad = auth.userId ?? 2;
      Provider.of<OrderService>(context, listen: false)
          .loadOrders(userIdToLoad);
      if (auth.userId != null) {
        Provider.of<NotificationService>(context, listen: false)
            .loadNotifications(auth.userId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderService = context.watch<OrderService>();
    final notifService = context.watch<NotificationService>();
    final auth = context.watch<AuthService>();
    final orders = orderService.orders;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.trafordOrange,
        title: const Text('My Orders'),
        actions: [
          // Notifications bell
          IconButton(
            icon: Badge(
              isLabelVisible: notifService.unreadCount > 0,
              label: Text(
                '${notifService.unreadCount}',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              backgroundColor: AppTheme.trafordOrange,
              child: const Icon(Icons.notifications_outlined,
                  color: Colors.white),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              final userIdToLoad = auth.userId ?? 2;
              orderService.loadOrders(userIdToLoad);
              if (auth.userId != null) {
                notifService.loadNotifications(auth.userId!);
              }
            },
          ),
        ],
      ),
      body: orderService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long,
                          size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'No orders yet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your order history will appear here',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => widget.onNavigate?.call(1),
                        child: const Text('Start Shopping'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    final userIdToLoad = auth.userId ?? 2;
                    await orderService.loadOrders(userIdToLoad);
                    if (auth.userId != null) {
                      await notifService.loadNotifications(auth.userId!);
                    }
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Column(
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom:
                                      BorderSide(color: AppTheme.cardBorder),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          order.orderNumber,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDate(order.createdAt),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _statusChip(order.status),
                                ],
                              ),
                            ),

                            // Items
                            if (order.items.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: order.items
                                      .map(
                                        (item) => Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 6),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment
                                                    .spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${item.productName} x${item.quantity}',
                                                  style: const TextStyle(
                                                      fontSize: 13),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                'UGX ${formatUGX(item.price * item.quantity)}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),

                            // Footer
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.bgGray,
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(16),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Delivery to',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textMuted,
                                          ),
                                        ),
                                        Text(
                                          order.shippingAddress ?? 'Uganda',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Total',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                      Text(
                                        'UGX ${formatUGX(order.total)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.trafordOrange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _statusChip(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case 'pending':
        bgColor = AppTheme.statusPending;
        textColor = const Color(0xFF92400E);
        icon = Icons.schedule;
        break;
      case 'processing':
        bgColor = AppTheme.statusProcessing;
        textColor = const Color(0xFF1E40AF);
        icon = Icons.autorenew;
        break;
      case 'shipped':
        bgColor = AppTheme.statusShipped;
        textColor = const Color(0xFF6B21A8);
        icon = Icons.local_shipping;
        break;
      case 'delivered':
        bgColor = AppTheme.statusDelivered;
        textColor = const Color(0xFF166534);
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        bgColor = AppTheme.statusCancelled;
        textColor = const Color(0xFF991B1B);
        icon = Icons.cancel;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
