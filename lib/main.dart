import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/supabase_config.dart';
import 'services/cart_service.dart';
import 'services/order_service.dart';
import 'services/product_service.dart';
import 'services/auth_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/realtime_service.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();

  // Auto-manage Realtime subscriptions on every auth state change.
  SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
    final user = data.session?.user;
    if (user != null) {
      RealtimeService.instance.start(userId: user.id);
    } else {
      RealtimeService.instance.stop();
    }
  });

  runApp(const TrafordApp());
}

class TrafordApp extends StatelessWidget {
  const TrafordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ProductService()),
        ChangeNotifierProvider(create: (_) => CartService()),
        ChangeNotifierProvider(create: (_) => OrderService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider.value(value: RealtimeService.instance),
      ],
      child: MaterialApp(
        title: 'Traford Farm Fresh',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const AppInitializer(),
      ),
    );
  }
}

/// Handles data initialization before showing the main app
/// Optimized for FAST loading - products show immediately,
/// secondary services load in background
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final productService =
          Provider.of<ProductService>(context, listen: false);
      final locationService =
          Provider.of<LocationService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      // === PHASE 1: Load critical data in PARALLEL for speed ===
      // Products + categories + auth + location all load simultaneously
      final results = await Future.wait([
        productService.initialize().then((_) => true).catchError((_) => false),
        authService.initialize().then((_) => true).catchError((_) => false),
        locationService.loadAll().then((_) => true).catchError((_) => false),
      ]);

      // Check if product loading succeeded
      final productsLoaded = results[0];
      if (!productsLoaded && productService.allProducts.isEmpty) {
        // Retry once if products failed
        try {
          await productService.initialize();
        } catch (_) {}
      }

      // Auto-login as guest if not logged in (for browsing)
      if (!authService.isLoggedIn) {
        try {
          await authService.autoLoginGuest();
        } catch (_) {}
      }

      // Show the app immediately - don't wait for secondary services
      if (mounted) {
        setState(() => _isReady = true);
      }

      // === PHASE 2: Load secondary services in BACKGROUND (non-blocking) ===
      if (authService.userId != null && mounted) {
        final cartService =
            Provider.of<CartService>(context, listen: false);
        cartService.setUserId(authService.userId!);

        // Fire-and-forget: load orders and notifications in background
        _loadSecondaryServicesInBackground(authService.userId!);
      }

      // === PHASE 3: Start Supabase Realtime subscriptions ===
      // Only when a real Supabase Auth user is signed in (UUID).
      // Legacy guest sessions skip this and will reconnect after a real sign-in.
      _startRealtimeIfPossible();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to connect to server. Please check your internet connection.');
      }
    }
  }

  /// Non-blocking background loader for orders/notifications
  void _loadSecondaryServicesInBackground(int userId) {
    // Orders
    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      orderService.loadOrders(userId).catchError((_) {});
    } catch (_) {}

    // Notifications (may fail due to UUID column - that's OK)
    try {
      final notifService =
          Provider.of<NotificationService>(context, listen: false);
      notifService.loadNotifications(userId).catchError((_) {});
    } catch (_) {}
  }

  /// Start Realtime subscriptions if a Supabase Auth UUID is available.
  /// Falls back to no-op for legacy phone/guest sessions.
  void _startRealtimeIfPossible() {
    try {
      final authUser = SupabaseConfig.client.auth.currentUser;
      if (authUser != null) {
        RealtimeService.instance.start(userId: authUser.id);
      }
    } catch (e) {
      debugPrint('Realtime start skipped: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Connection Error',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _isReady = false;
                    });
                    _initializeApp();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isReady) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/traford_logo.png',
                height: 80,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              const Text(
                'Traford Farm Fresh',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.trafordOrange,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppTheme.trafordOrange,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Loading fresh products...',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return const MainShell();
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // Pre-built screens list for instant tab switching (no rebuilds)
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(onNavigate: _onNavigate),
      ShopScreen(onNavigate: _onNavigate),
      CartScreen(onNavigate: _onNavigate),
      OrdersScreen(onNavigate: _onNavigate),
      ProfileScreen(onNavigate: _onNavigate),
    ];
  }

  void _onNavigate(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final notifService = context.watch<NotificationService>();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onNavigate,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.store_outlined),
            activeIcon: Icon(Icons.store),
            label: 'Shop',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: cart.itemCount > 0,
              label: Text(
                '${cart.itemCount}',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              backgroundColor: Colors.red,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: cart.itemCount > 0,
              label: Text(
                '${cart.itemCount}',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              backgroundColor: Colors.red,
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: notifService.unreadCount > 0,
              label: Text(
                '${notifService.unreadCount}',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              backgroundColor: AppTheme.trafordOrange,
              child: const Icon(Icons.receipt_long_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: notifService.unreadCount > 0,
              label: Text(
                '${notifService.unreadCount}',
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              backgroundColor: AppTheme.trafordOrange,
              child: const Icon(Icons.receipt_long),
            ),
            label: 'Orders',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
