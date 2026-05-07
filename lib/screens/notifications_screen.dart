import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthService>(context, listen: false);
      if (auth.userId != null) {
        Provider.of<NotificationService>(context, listen: false)
            .loadNotifications(auth.userId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifService = context.watch<NotificationService>();
    final notifications = notifService.notifications;
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.trafordOrange,
        title: const Text('Notifications'),
        actions: [
          if (notifService.unreadCount > 0)
            TextButton(
              onPressed: () {
                if (auth.userId != null) {
                  notifService.markAllAsRead(auth.userId!);
                }
              },
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
        ],
      ),
      body: notifService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'No notifications yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Order updates will appear here',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    if (auth.userId != null) {
                      await notifService.loadNotifications(auth.userId!);
                    }
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final notif = notifications[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: notif.isRead
                              ? Colors.white
                              : AppTheme.softLeaf,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: notif.isRead
                                ? AppTheme.cardBorder
                                : AppTheme.trafordOrange
                                    .withValues(alpha: 0.3),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: notif.isRead
                                  ? Colors.grey.shade100
                                  : AppTheme.trafordOrange
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getNotifIcon(notif.title),
                              color: notif.isRead
                                  ? AppTheme.textMuted
                                  : AppTheme.trafordOrange,
                              size: 24,
                            ),
                          ),
                          title: Text(
                            notif.title,
                            style: TextStyle(
                              fontWeight: notif.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                notif.message,
                                style: const TextStyle(
                                    fontSize: 13, color: AppTheme.textMuted),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _timeAgo(notif.createdAt),
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                          onTap: () {
                            if (!notif.isRead) {
                              notifService.markAsRead(notif.id);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  IconData _getNotifIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('placed') || lower.contains('new')) {
      return Icons.receipt_long;
    }
    if (lower.contains('processing')) return Icons.autorenew;
    if (lower.contains('shipped') || lower.contains('delivery')) {
      return Icons.local_shipping;
    }
    if (lower.contains('delivered')) return Icons.check_circle;
    if (lower.contains('cancelled')) return Icons.cancel;
    return Icons.notifications;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
