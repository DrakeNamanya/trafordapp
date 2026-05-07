import 'package:flutter/material.dart';
import 'supabase_config.dart';

class AppNotification {
  final int id;
  final int orderId;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.orderId,
    required this.title,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as int,
        orderId: json['order_id'] as int? ?? 0,
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        isRead: json['is_read'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}

class NotificationService extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  bool _isLoading = false;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> loadNotifications(int userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await SupabaseConfig.client
          .from('order_notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      _notifications = (response as List)
          .map((j) => AppNotification.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // order_notifications table may have UUID user_id column
      // or table may not be fully configured - gracefully degrade
      debugPrint('Notifications unavailable: $e');
      _notifications = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await SupabaseConfig.client
          .from('order_notifications')
          .update({'is_read': true}).eq('id', notificationId);

      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx != -1) {
        _notifications[idx] = AppNotification(
          id: _notifications[idx].id,
          orderId: _notifications[idx].orderId,
          title: _notifications[idx].title,
          message: _notifications[idx].message,
          isRead: true,
          createdAt: _notifications[idx].createdAt,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead(int userId) async {
    try {
      await SupabaseConfig.client
          .from('order_notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      _notifications = _notifications
          .map((n) => AppNotification(
                id: n.id,
                orderId: n.orderId,
                title: n.title,
                message: n.message,
                isRead: true,
                createdAt: n.createdAt,
              ))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  void clear() {
    _notifications = [];
    notifyListeners();
  }
}
