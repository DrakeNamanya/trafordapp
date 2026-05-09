import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';

/// Centralised Supabase Realtime subscriptions for the customer mobile app.
///
/// Subscribes to Postgres CDC changes on:
///   - orders         filtered by user_id
///   - payments       filtered by user_id
///   - deliveries     filtered by user_id
///   - notifications  filtered by user_id
///
/// All channels are scoped to the currently signed-in user, so the customer
/// only ever receives their own row updates. RLS on the server enforces the
/// same boundary as a defense in depth.
///
/// Usage:
///   final rt = RealtimeService();
///   await rt.start(userId: theUserUuid);
///   rt.orderStream.listen(...);
///   rt.notificationStream.listen(...);
///   await rt.stop();
class RealtimeService extends ChangeNotifier {
  RealtimeService._();
  static final RealtimeService instance = RealtimeService._();
  factory RealtimeService() => instance;

  RealtimeChannel? _ordersChannel;
  RealtimeChannel? _paymentsChannel;
  RealtimeChannel? _deliveriesChannel;
  RealtimeChannel? _notificationsChannel;

  String? _currentUserId;
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  String? get currentUserId => _currentUserId;

  // ---- In-memory mirrors for screens that prefer ChangeNotifier over streams
  final Map<String, Map<String, dynamic>> _orders = {};
  final List<Map<String, dynamic>> _notifications = [];

  List<Map<String, dynamic>> get orders {
    final list = _orders.values.toList();
    list.sort((a, b) {
      final aDate =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(0);
      final bDate =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(0);
      return bDate.compareTo(aDate);
    });
    return list;
  }

  List<Map<String, dynamic>> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadNotificationCount =>
      _notifications.where((n) => n['read_at'] == null).length;

  /// Start subscriptions for the given user. Idempotent: calling twice with
  /// the same userId is a no-op; calling with a new userId reconnects.
  Future<void> start({required String userId}) async {
    if (_currentUserId == userId && _isConnected) return;
    if (_currentUserId != null) {
      await stop();
    }
    _currentUserId = userId;

    final supabase = SupabaseConfig.client;

    // Orders channel — listen to inserts + updates on this user's orders
    _ordersChannel = supabase
        .channel('public:orders:user=$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: _handleOrderChange,
        )
        .subscribe();

    // Payments — fire when admin verifies / fails a payment
    _paymentsChannel = supabase
        .channel('public:payments:user=$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'payments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: _handlePaymentChange,
        )
        .subscribe();

    // Deliveries — driver / admin updates
    _deliveriesChannel = supabase
        .channel('public:deliveries:user=$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'deliveries',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: _handleDeliveryChange,
        )
        .subscribe();

    // Notifications — toast/badge feed
    _notificationsChannel = supabase
        .channel('public:notifications:user=$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: _handleNotificationInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: _handleNotificationUpdate,
        )
        .subscribe();

    _isConnected = true;

    // Hydrate initial state so UIs work even before the first realtime event
    await _hydrate(userId);
    notifyListeners();
  }

  Future<void> stop() async {
    final supabase = SupabaseConfig.client;
    final channels = [
      _ordersChannel,
      _paymentsChannel,
      _deliveriesChannel,
      _notificationsChannel,
    ];
    for (final ch in channels) {
      if (ch != null) {
        try {
          await supabase.removeChannel(ch);
        } catch (e) {
          debugPrint('RealtimeService: error removing channel: $e');
        }
      }
    }
    _ordersChannel = null;
    _paymentsChannel = null;
    _deliveriesChannel = null;
    _notificationsChannel = null;
    _orders.clear();
    _notifications.clear();
    _currentUserId = null;
    _isConnected = false;
    notifyListeners();
  }

  /// Pull current orders + recent notifications via REST so the UI has a
  /// baseline before any realtime event arrives. Failures are logged only.
  Future<void> _hydrate(String userId) async {
    final supabase = SupabaseConfig.client;
    try {
      final orders = await supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      _orders.clear();
      for (final row in orders as List) {
        final m = row as Map<String, dynamic>;
        final id = m['id']?.toString();
        if (id != null) _orders[id] = m;
      }
    } catch (e) {
      debugPrint('RealtimeService: order hydrate failed: $e');
    }

    try {
      final notifs = await supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(50);
      _notifications
        ..clear()
        ..addAll(
          (notifs as List).map((e) => e as Map<String, dynamic>),
        );
    } catch (e) {
      debugPrint('RealtimeService: notification hydrate failed: $e');
    }
  }

  // ----- Postgres change handlers
  void _handleOrderChange(PostgresChangePayload payload) {
    final newRecord = payload.newRecord;
    final oldRecord = payload.oldRecord;

    if (payload.eventType == PostgresChangeEvent.delete) {
      final id = oldRecord['id']?.toString();
      if (id != null) _orders.remove(id);
    } else {
      final id = newRecord['id']?.toString();
      if (id != null) _orders[id] = Map<String, dynamic>.from(newRecord);
    }
    notifyListeners();
  }

  void _handlePaymentChange(PostgresChangePayload payload) {
    // Payment status often dictates order status; we just nudge listeners so
    // any payment-aware UI re-renders. Order rows update via their own channel.
    notifyListeners();
  }

  void _handleDeliveryChange(PostgresChangePayload payload) {
    notifyListeners();
  }

  void _handleNotificationInsert(PostgresChangePayload payload) {
    _notifications.insert(0, Map<String, dynamic>.from(payload.newRecord));
    if (_notifications.length > 100) {
      _notifications.removeRange(100, _notifications.length);
    }
    notifyListeners();
  }

  void _handleNotificationUpdate(PostgresChangePayload payload) {
    final updated = payload.newRecord;
    final id = updated['id']?.toString();
    if (id == null) return;
    final idx = _notifications.indexWhere((n) => n['id']?.toString() == id);
    if (idx != -1) {
      _notifications[idx] = Map<String, dynamic>.from(updated);
      notifyListeners();
    }
  }

  /// Mark a single notification as read. Optimistic update + server write.
  Future<void> markRead(String notificationId) async {
    final idx =
        _notifications.indexWhere((n) => n['id']?.toString() == notificationId);
    if (idx != -1) {
      _notifications[idx] = {
        ..._notifications[idx],
        'read_at': DateTime.now().toIso8601String(),
      };
      notifyListeners();
    }
    try {
      await SupabaseConfig.client
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);
    } catch (e) {
      debugPrint('RealtimeService: markRead failed: $e');
    }
  }

  /// Convenience: latest snapshot of a single order, or null.
  Map<String, dynamic>? orderById(String orderId) => _orders[orderId];
}
