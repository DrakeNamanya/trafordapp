import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agro_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'agro_checkout_screen.dart';
import 'staff_login_screen.dart';

/// Staff-only Agro Inputs shop.
/// Visible only when AuthService.canShopAgro == true.
/// Talks to /api/public/agro-products with a Supabase JWT.
class AgroShopScreen extends StatefulWidget {
  const AgroShopScreen({super.key});

  @override
  State<AgroShopScreen> createState() => _AgroShopScreenState();
}

class _AgroShopScreenState extends State<AgroShopScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthService>();
    final agro = context.read<AgroService>();

    // Sync the JWT into ApiClient so /agro-products has Authorization header
    ApiClient.bearerToken = auth.accessToken;
    await agro.loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final agro = context.watch<AgroService>();

    if (!auth.canShopAgro) {
      return _buildUnauthorized();
    }
    if (auth.accessToken == null) {
      return _buildSignInRequired();
    }

    final filtered = _searchQuery.isEmpty
        ? agro.products
        : agro.products
            .where(
                (p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(),
          if (agro.cartCount > 0) _buildCartBanner(agro),
          Expanded(
            child: agro.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.trafordOrange))
                : agro.error != null
                    ? _buildError(agro.error!)
                    : filtered.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: AppTheme.trafordOrange,
                            onRefresh: () async {
                              ApiClient.bearerToken = auth.accessToken;
                              await agro.loadProducts();
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final p = filtered[i];
                                final qty = agro.cart[p.id] ?? 0;
                                return _buildProductRow(p, qty, agro);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  // -------------------- HEADER --------------------
  Widget _buildHeader() {
    return Container(
      color: AppTheme.trafordOrange,
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.agriculture, color: Colors.white, size: 26),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Agro Inputs',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Staff-only catalogue • orders are reviewed against the agro approval threshold',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: const InputDecoration(
                hintText: 'Search seeds, fertilizers, tools...',
                prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- CART BANNER --------------------
  Widget _buildCartBanner(AgroService agro) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const AgroCheckoutScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.trafordOrange.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppTheme.trafordOrange.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            const Icon(Icons.shopping_basket,
                color: AppTheme.trafordOrange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${agro.cartCount} item(s) in agro cart  •  UGX ${_fmt(agro.cartSubtotal())}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppTheme.trafordOrange),
          ],
        ),
      ),
    );
  }

  // -------------------- PRODUCT ROW --------------------
  Widget _buildProductRow(p, int qty, AgroService agro) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: p.image != null
                ? CachedNetworkImage(
                    imageUrl: p.image!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    memCacheWidth: 200,
                    filterQuality: FilterQuality.low,
                    errorWidget: (_, __, ___) => _imgPlaceholder(),
                    placeholder: (_, __) => _imgPlaceholder(),
                  )
                : _imgPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('UGX ${_fmt(p.price)} / ${p.unit}',
                    style: const TextStyle(
                        color: AppTheme.trafordOrange,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (qty == 0)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.trafordOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () => agro.addToCart(p.id),
              child: const Text('Add'),
            )
          else
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline,
                      color: AppTheme.trafordOrange),
                  onPressed: () =>
                      agro.setQuantity(p.id, qty - 1),
                ),
                Text('$qty',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                IconButton(
                  icon: const Icon(Icons.add_circle,
                      color: AppTheme.trafordOrange),
                  onPressed: () =>
                      agro.setQuantity(p.id, qty + 1),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 64,
        height: 64,
        color: const Color(0xFFF3F4F6),
        child: const Icon(Icons.agriculture, color: Color(0xFF9CA3AF)),
      );

  // -------------------- STATES --------------------
  Widget _buildUnauthorized() => Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('Staff Access Only',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                  'The Agro Inputs shop is only available to field staff. '
                  'Please contact the director if you should have access.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildSignInRequired() => Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                const Text('Sign in required',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                  'Sign in with the email and temporary password from your director invitation email to access agro inputs.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StaffLoginScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.agriculture),
                  label: const Text('Staff Sign In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.growthGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildError(String err) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 56, color: Colors.red),
              const SizedBox(height: 12),
              Text(err,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _bootstrap,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 56, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('No agro products found',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  String _fmt(num n) {
    final s = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
