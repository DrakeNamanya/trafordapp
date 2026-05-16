import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agro_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/delivery_profile_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/order_service.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'become_supplier_screen.dart';
import 'login_screen.dart';
import 'staff_login_screen.dart';
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
    final deliveryProfile = context.watch<DeliveryProfileService>();
    final hasSavedDelivery = (deliveryProfile.fullName?.isNotEmpty ?? false) ||
        (deliveryProfile.phone?.isNotEmpty ?? false) ||
        (deliveryProfile.deliveryAddress?.isNotEmpty ?? false);

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
                  hasSavedDelivery
                      ? 'You are shopping as a guest'
                      : 'Shop as a guest — or create an account',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
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

          // Saved delivery info (if any)
          if (hasSavedDelivery)
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
                    Row(
                      children: [
                        const Icon(Icons.bookmark,
                            color: AppTheme.trafordOrange, size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Saved Delivery Info',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              _confirmClearDeliveryProfile(context),
                          child: const Text(
                            'Clear',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'We use this to auto-fill your next checkout on this device.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const Divider(height: 20),
                    if ((deliveryProfile.fullName ?? '').isNotEmpty)
                      _profileRow(
                          Icons.person, 'Name', deliveryProfile.fullName!),
                    if ((deliveryProfile.phone ?? '').isNotEmpty)
                      _profileRow(
                          Icons.phone, 'Phone', deliveryProfile.phone!),
                    if ((deliveryProfile.email ?? '').isNotEmpty)
                      _profileRow(
                          Icons.email, 'Email', deliveryProfile.email!),
                    if ((deliveryProfile.deliveryAddress ?? '').isNotEmpty)
                      _profileRow(Icons.location_on, 'Address',
                          deliveryProfile.deliveryAddress!),
                  ],
                ),
              ),
            ),

          if (hasSavedDelivery) const SizedBox(height: 16),

          // Guest vs Account comparison
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
                    'Guest checkout vs Creating an account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'You can shop either way — here\'s what changes.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 16),
                  _comparisonCard(
                    icon: Icons.flash_on,
                    title: 'Guest checkout',
                    subtitle: 'Just enter your info at checkout',
                    bullets: const [
                      ('check', 'Place orders right away, no signup'),
                      ('check',
                          'Your delivery details auto-fill next time on this phone'),
                      ('check', 'Track orders by their TFF number on this device'),
                      ('close',
                          'Order history is on this phone only — not on other devices'),
                      ('close', 'No push notifications when status changes'),
                    ],
                    accent: AppTheme.trafordOrange,
                  ),
                  const SizedBox(height: 12),
                  _comparisonCard(
                    icon: Icons.verified_user,
                    title: 'Create an account',
                    subtitle: 'Sign in with phone + password',
                    bullets: const [
                      ('check',
                          'Your orders follow you on any device you sign in on'),
                      ('check', 'Push notifications when admin updates status'),
                      ('check', 'Save full profile (location, NIN, etc.)'),
                      ('check', 'Wishlist sync across devices'),
                    ],
                    accent: AppTheme.growthGreen,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.account_circle_outlined),
                      label: const Text(
                        'Sign In / Create Account',
                        style: TextStyle(fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Staff: Agro Inputs Shop discovery card (Issue 3)
          // NB: this card opens the DEDICATED staff login (email + temp
          // password from the director-invitation email — Resend) rather
          // than the customer phone-based LoginScreen. Staff accounts are
          // invited, not self-registered, so the screen also has no
          // "Create Account" button.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StaffLoginScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: AppTheme.growthGreen, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.softLeaf,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.agriculture,
                            color: AppTheme.growthGreen, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Staff: Agro Inputs Shop',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.growthGreen,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Field staff & admins can sign in here to access the Agro tab (seeds, fertilizers, tools).',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppTheme.growthGreen),
                    ],
                  ),
                ),
              ),
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

  Widget _comparisonCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<(String, String)> bullets,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: accent,
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
            ],
          ),
          const SizedBox(height: 10),
          ...bullets.map((b) {
            final isCheck = b.$1 == 'check';
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isCheck ? Icons.check_circle : Icons.remove_circle_outline,
                    size: 16,
                    color: isCheck ? AppTheme.growthGreen : Colors.red.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      b.$2,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _confirmClearDeliveryProfile(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear saved delivery info?'),
        content: const Text(
          'Your next checkout will start with empty fields. This only affects this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final dp = Provider.of<DeliveryProfileService>(context,
                  listen: false);
              await dp.clear();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Saved delivery info cleared'),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
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

          // Become Our Supplier card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BecomeSupplierScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: AppTheme.growthGreen, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.softLeaf,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.agriculture,
                            color: AppTheme.growthGreen, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Become Our Supplier',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.growthGreen,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Grow or produce something we sell? Tell us what, how much, and how often — we will reach out.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppTheme.growthGreen),
                    ],
                  ),
                ),
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
            onPressed: () async {
              // Grab all the services we need to scrub BEFORE we close the
              // dialog (otherwise the context becomes invalid for reads).
              final orderService =
                  Provider.of<OrderService>(context, listen: false);
              final agroService =
                  Provider.of<AgroService>(context, listen: false);
              final notifService =
                  Provider.of<NotificationService>(context, listen: false);

              Navigator.pop(ctx);

              // 1) End the Supabase session.
              await auth.logout();

              // 2) Clear every per-user cache so the next user (or the
              //    same user signing back in) doesn't see the previous
              //    session's data. This was the bug behind:
              //      - "orders tab still showed customer orders after I
              //         logged in as field staff"
              //      - "agro cart was hidden after I switched accounts"
              await cart.resetOnLogout();
              await orderService.clearLocalCache();
              agroService.resetOnLogout();
              notifService.clear();
              // Drop any bearer token stuck on ApiClient so staff endpoints
              // don't keep returning data for the previous session.
              ApiClient.bearerToken = null;

              if (!context.mounted) return;
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
