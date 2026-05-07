import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatelessWidget {
  final void Function(int)? onNavigate;

  const ProfileScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final cart = context.watch<CartService>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.trafordOrange,
        title: const Text('Profile'),
        actions: [
          if (auth.isLoggedIn && auth.hasProfile)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Logout',
              onPressed: () => _confirmLogout(context, auth, cart),
            ),
        ],
      ),
      body: auth.hasProfile
          ? _buildLoggedInProfile(context, auth, cart)
          : _buildNotLoggedIn(context, cart),
    );
  }

  Widget _buildNotLoggedIn(BuildContext context, CartService cart) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.trafordOrange, AppTheme.growthGreen],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.person_outline,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Welcome to Traford',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign in to manage your orders and profile',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Login / Register buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.account_circle_outlined,
                          size: 56, color: AppTheme.trafordOrange),
                      const SizedBox(height: 16),
                      const Text(
                        'Create Your Account',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in or create an account to:\n'
                        '- Place orders for fresh farm products\n'
                        '- Track your deliveries\n'
                        '- Get notifications on order status\n'
                        '- Save your delivery address',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Sign In / Create Account',
                              style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Quick Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _statCard(
                  icon: Icons.shopping_cart,
                  label: 'Cart Items',
                  value: '${cart.itemCount}',
                ),
                const SizedBox(width: 12),
                _statCard(
                  icon: Icons.favorite,
                  label: 'Wishlist',
                  value: '${cart.wishlistCount}',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Contact Info
          _contactCard(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLoggedInProfile(
      BuildContext context, AuthService auth, CartService cart) {
    final profile = auth.profile;
    final locService = context.watch<LocationService>();
    final notifService = context.watch<NotificationService>();

    final fullName = profile?['full_name'] ?? 'Customer';
    final phone = profile?['phone'] ?? '';
    final email = profile?['email'] ?? '';
    final dob = profile?['date_of_birth'] ?? '';

    // Resolve location names from Supabase IDs using LocationService
    final districtId = profile?['district_id'] as int?;
    final subcountyId = profile?['subcounty_id'] as int?;
    final parishId = profile?['parish_id'] as int?;

    final districtName = locService.districtName(districtId) ??
        (profile?['city'] as String? ?? '');
    final subcountyName = locService.subcountyName(subcountyId) ?? '';
    final parishName = locService.parishName(parishId) ?? '';

    final nin = profile?['nin'] ?? '';

    return SingleChildScrollView(
      child: Column(
        children: [
          // Profile Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.trafordOrange, AppTheme.growthGreen],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    fullName.isNotEmpty
                        ? fullName[0].toUpperCase()
                        : 'C',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  fullName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Quick Stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _statCard(
                  icon: Icons.shopping_cart,
                  label: 'Cart Items',
                  value: '${cart.itemCount}',
                ),
                const SizedBox(width: 12),
                _statCard(
                  icon: Icons.favorite,
                  label: 'Wishlist',
                  value: '${cart.wishlistCount}',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Profile Details Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Profile Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _profileRow(Icons.person, 'Full Name', fullName),
                  if (email.isNotEmpty)
                    _profileRow(Icons.email, 'Email', email),
                  if (phone.isNotEmpty)
                    _profileRow(Icons.phone, 'Phone', phone),
                  if (dob != null && dob.toString().isNotEmpty)
                    _profileRow(Icons.cake, 'Date of Birth', dob.toString()),
                  if (districtName.isNotEmpty) ...[
                    const Divider(height: 16),
                    const Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _profileRow(Icons.map, 'District', districtName),
                    if (subcountyName.isNotEmpty)
                      _profileRow(
                          Icons.location_city, 'Subcounty', subcountyName),
                    if (parishName.isNotEmpty)
                      _profileRow(Icons.home, 'Parish/Village', parishName),
                  ],
                  if (nin != null && nin.toString().isNotEmpty) ...[
                    const Divider(height: 16),
                    _profileRow(Icons.badge, 'NIN', nin.toString()),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Menu Items
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _menuItem(
                  context,
                  icon: Icons.receipt_long,
                  title: 'My Orders',
                  subtitle: 'Track your order history',
                  onTap: () => onNavigate?.call(3),
                ),
                _menuItem(
                  context,
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  subtitle:
                      '${notifService.unreadCount} unread notifications',
                  badge: notifService.unreadCount,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
                _menuItem(
                  context,
                  icon: Icons.favorite_border,
                  title: 'Wishlist',
                  subtitle: '${cart.wishlistCount} saved items',
                  onTap: () => onNavigate?.call(1),
                ),
                _menuItem(
                  context,
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  subtitle: 'FAQ, contact us',
                  onTap: () {},
                ),
                _menuItem(
                  context,
                  icon: Icons.info_outline,
                  title: 'About Traford',
                  subtitle: 'Our mission and story',
                  onTap: () => _showAboutDialog(context),
                ),
              ],
            ),
          ),

          // Contact Info
          _contactCard(),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.trafordOrange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textMuted)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.softLeaf,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Text(
            'Need Help?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.growthGreen,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Contact us for any questions',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.email, size: 16, color: AppTheme.trafordOrange),
              SizedBox(width: 6),
              Text(
                'sales@trafordfarmfresh.com',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.growthGreen,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone, size: 16, color: AppTheme.trafordOrange),
              SizedBox(width: 6),
              Text(
                '+256 764 201 606',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.growthGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.trafordOrange, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.softLeaf,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      Icon(icon, color: AppTheme.trafordOrange, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badge > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.trafordOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                const Icon(Icons.chevron_right, color: AppTheme.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLogout(
      BuildContext context, AuthService auth, CartService cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              auth.logout();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Logged out successfully'),
                  backgroundColor: AppTheme.trafordOrange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '\u{1F33E} Traford Farm Fresh',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'An e-commerce platform that directly buys fresh agriculture produce from smallholder farmers and distributes them to customers in Uganda and beyond.\n\nOur mission is to provide quality, freshness, and sustainability while supporting fair trade for smallholder farmers.\n\nKikaaya, Kyebando, Kawempe, Kampala, Uganda',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
