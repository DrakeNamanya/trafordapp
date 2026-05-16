import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/api_client.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _reload();
    });
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final auth = Provider.of<AuthService>(context, listen: false);
    final orderService = Provider.of<OrderService>(context, listen: false);

    // Make sure the staff JWT is on ApiClient before calling
    // /agro-orders/mine.
    if (auth.canShopAgro) {
      ApiClient.bearerToken = auth.accessToken;
    }

    // Pull customer orders by phone (works around RLS) and, for staff,
    // also pull agro orders via the JWT-authenticated /agro-orders/mine.
    await orderService.loadOrders(
      auth.userId ?? 2,
      phone: auth.userPhone,
      isStaff: auth.canShopAgro,
    );
    await orderService.refreshAllStatuses();
    if (!mounted) return;
    if (auth.userId != null) {
      await Provider.of<NotificationService>(context, listen: false)
          .loadNotifications(auth.userId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderService = context.watch<OrderService>();
    final notifService = context.watch<NotificationService>();
    // Watch auth so we re-trigger when the role changes (customer -> staff
    // after a staff sign-in) — we don't reference it directly in the tree.
    context.watch<AuthService>();
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
            onPressed: _reload,
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
                  onRefresh: _reload,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _openOrderDetail(order),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: AppTheme.cardBorder),
                              ),
                              child: Column(
                                children: [
                                  // Header
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                            color: AppTheme.cardBorder),
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
                                                overflow:
                                                    TextOverflow.ellipsis,
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
                                        const SizedBox(width: 4),
                                        const Icon(Icons.chevron_right,
                                            color: AppTheme.textMuted),
                                      ],
                                    ),
                                  ),

                                  // Items preview (max 2)
                                  if (order.items.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          ...order.items.take(2).map(
                                                (item) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 6),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          '${item.productName} x${item.quantity}',
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      13),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                      Text(
                                                        'UGX ${formatUGX(item.price * item.quantity)}',
                                                        style:
                                                            const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          if (order.items.length > 2)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 2),
                                              child: Text(
                                                '+${order.items.length - 2} more item(s) — tap to view',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.textMuted,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                  // Footer
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bgGray,
                                      borderRadius:
                                          const BorderRadius.vertical(
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
                                                order.shippingAddress ??
                                                    'Uganda',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow:
                                                    TextOverflow.ellipsis,
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
                                                color:
                                                    AppTheme.trafordOrange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _openOrderDetail(Order order) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return _OrderDetailSheet(
              order: order,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  Widget _statusChip(String status) {
    final s = status.toLowerCase();
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (s) {
      case 'pending':
        bgColor = AppTheme.statusPending;
        textColor = const Color(0xFF92400E);
        icon = Icons.schedule;
        break;
      case 'confirmed':
      case 'processing':
      case 'preparing':
        bgColor = AppTheme.statusProcessing;
        textColor = const Color(0xFF1E40AF);
        icon = Icons.autorenew;
        break;
      case 'shipped':
      case 'out_for_delivery':
        bgColor = AppTheme.statusShipped;
        textColor = const Color(0xFF6B21A8);
        icon = Icons.local_shipping;
        break;
      case 'delivered':
      case 'completed':
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
            status.isEmpty
                ? 'Unknown'
                : status[0].toUpperCase() + status.substring(1),
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

/// Full order detail bottom sheet — shows status timeline, items, delivery
/// info, payment status, and a "Refresh status" button that re-pulls the
/// latest status from the public `/orders/by-number` endpoint.
class _OrderDetailSheet extends StatefulWidget {
  final Order order;
  final ScrollController scrollController;

  const _OrderDetailSheet({
    required this.order,
    required this.scrollController,
  });

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  bool _refreshing = false;

  static const _statusSteps = <String>[
    'pending',
    'confirmed',
    'preparing',
    'shipped',
    'delivered',
  ];

  int _currentStepIndex(String status) {
    final s = status.toLowerCase();
    if (s == 'cancelled') return -1;
    if (s == 'processing') return _statusSteps.indexOf('preparing');
    if (s == 'completed') return _statusSteps.indexOf('delivered');
    if (s == 'out_for_delivery') return _statusSteps.indexOf('shipped');
    final i = _statusSteps.indexOf(s);
    return i < 0 ? 0 : i;
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final orderService =
          Provider.of<OrderService>(context, listen: false);
      final changed =
          await orderService.refreshOrderStatus(widget.order.orderNumber);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(changed
              ? 'Status updated to "${widget.order.status}"'
              : 'No status change yet'),
          duration: const Duration(seconds: 2),
        ),
      );
      // Trigger a rebuild of this sheet.
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not refresh status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final stepIdx = _currentStepIndex(order.status);
    final isCancelled = order.status.toLowerCase() == 'cancelled';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.orderNumber,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: AppTheme.trafordOrange,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: widget.scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                // Status timeline
                _sectionTitle('Status'),
                const SizedBox(height: 12),
                if (isCancelled)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.statusCancelled,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.cancel, color: Color(0xFF991B1B)),
                        SizedBox(width: 10),
                        Text(
                          'This order was cancelled',
                          style: TextStyle(
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: List.generate(_statusSteps.length, (i) {
                      final step = _statusSteps[i];
                      final done = i <= stepIdx;
                      final isCurrent = i == stepIdx;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: done
                                    ? AppTheme.trafordOrange
                                    : Colors.grey.shade200,
                              ),
                              child: done
                                  ? const Icon(Icons.check,
                                      size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              step[0].toUpperCase() + step.substring(1),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isCurrent
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: done
                                    ? AppTheme.textDark
                                    : AppTheme.textMuted,
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.trafordOrange
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Current',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.trafordOrange,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _refreshing ? null : _refresh,
                    icon: _refreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(_refreshing
                        ? 'Checking with our team...'
                        : 'Refresh status'),
                  ),
                ),

                const SizedBox(height: 24),

                // Items
                _sectionTitle('Items'),
                const SizedBox(height: 12),
                if (order.items.isEmpty)
                  const Text(
                    'No items recorded for this order.',
                    style: TextStyle(color: AppTheme.textMuted),
                  )
                else
                  ...order.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${item.productName} x${item.quantity}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            'UGX ${formatUGX(item.price * item.quantity)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
                const Divider(),
                _kvRow('Subtotal', 'UGX ${formatUGX(order.subtotal)}'),
                if (order.tax > 0)
                  _kvRow('Tax', 'UGX ${formatUGX(order.tax)}'),
                _kvRow(
                  'Total',
                  'UGX ${formatUGX(order.total)}',
                  emphasize: true,
                ),

                const SizedBox(height: 24),

                // Delivery
                _sectionTitle('Delivery Information'),
                const SizedBox(height: 12),
                _kvRow('Address', order.shippingAddress ?? '—'),
                if ((order.shippingCity ?? '').isNotEmpty)
                  _kvRow('City / Country', order.shippingCity!),
                if ((order.shippingPhone ?? '').isNotEmpty)
                  _kvRow('Phone', order.shippingPhone!),

                const SizedBox(height: 24),

                // Payment
                _sectionTitle('Payment'),
                const SizedBox(height: 12),
                _kvRow(
                  'Method',
                  (order.paymentMethod ?? 'cash').toUpperCase(),
                ),
                _kvRow(
                  'Payment status',
                  order.paymentStatus.toUpperCase(),
                ),

                const SizedBox(height: 24),

                // Helper note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.bgGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 18, color: AppTheme.textMuted),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tap "Refresh status" to check the latest update from our team. We also update automatically when you open the Orders tab.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppTheme.textDark,
      ),
    );
  }

  Widget _kvRow(String label, String value, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: emphasize ? 16 : 13,
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                color: emphasize
                    ? AppTheme.trafordOrange
                    : AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
