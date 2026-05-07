import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import '../screens/shop_screen.dart';
import '../screens/product_detail_screen.dart';

/// Home screen redesigned to match the reference design:
/// - Minimal white header (Taford logo + orange search icon)
/// - Light-green hero card with split layout (text left, produce right) + dot indicator
/// - White rounded features bar (3 columns, green icons + subtitles)
/// - Shop by Category: light-green rounded square tiles with green icon + label
/// - Featured Products: compact horizontal strip
/// - Light-green "Eat Fresh, Stay Healthy" promo banner with green Explore More button
class HomeScreen extends StatefulWidget {
  final void Function(int)? onNavigate;

  const HomeScreen({super.key, this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Hero carousel state
  final PageController _heroController = PageController();
  Timer? _heroTimer;
  int _heroIndex = 0;

  static const _softMint = Color(0xFFE8F3E8); // Hero / promo background
  static const _softMint2 = Color(0xFFEAF6E9); // Category tile background
  static const _border = Color(0xFFE5E7EB);

  final List<_HeroSlide> _slides = const [
    _HeroSlide(
      headlineStart: 'Fresh from\n',
      headlineGreen: 'local farms',
      subtitle: 'Natural. Healthy.\nAlways Fresh.',
      image:
          'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=600&q=80',
    ),
    _HeroSlide(
      headlineStart: 'Hand-picked\n',
      headlineGreen: 'organic veggies',
      subtitle: 'Straight from\nfarm to your kitchen.',
      image:
          'https://images.unsplash.com/photo-1610348725531-843dff563e2c?auto=format&fit=crop&w=600&q=80',
    ),
    _HeroSlide(
      headlineStart: 'Daily deals on\n',
      headlineGreen: 'fresh produce',
      subtitle: 'Save big on the\nfreshest picks.',
      image:
          'https://images.unsplash.com/photo-1506617420156-8e4536971650?auto=format&fit=crop&w=600&q=80',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _heroTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_heroController.hasClients) return;
      final next = (_heroIndex + 1) % _slides.length;
      _heroController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productService = context.watch<ProductService>();
    final featured = productService.featuredProducts.isNotEmpty
        ? productService.featuredProducts.take(8).toList()
        : productService.allProducts.take(8).toList();
    final cats = productService.topCategories;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.trafordOrange,
          onRefresh: () async {
            await productService.loadProducts();
            await productService.loadCategories();
          },
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildHeader(context),
              const SizedBox(height: 8),
              _buildHero(),
              const SizedBox(height: 16),
              _buildFeaturesBar(),
              const SizedBox(height: 20),
              _buildSectionHeader(
                'Shop by Category',
                actionLabel: 'See All',
                onAction: () => widget.onNavigate?.call(1),
              ),
              const SizedBox(height: 10),
              _buildCategoriesRow(context, cats, productService.isLoading),
              const SizedBox(height: 18),
              _buildSectionHeader(
                'Featured Products',
                actionLabel: 'View All',
                onAction: () => widget.onNavigate?.call(1),
              ),
              const SizedBox(height: 10),
              _buildFeaturedStrip(productService, featured),
              const SizedBox(height: 18),
              _buildPromoBanner(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------- HEADER --------------------
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          // Taford logo
          Image.asset(
            'assets/images/traford_logo.png',
            height: 32,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Row(
              children: const [
                Icon(Icons.eco,
                    color: AppTheme.growthGreen, size: 22),
                SizedBox(width: 4),
                Text(
                  'Taford',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.trafordOrange,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopScreen(
                    onNavigate: widget.onNavigate,
                    initialSearch: true,
                  ),
                ),
              );
            },
            child: const Icon(Icons.search,
                color: AppTheme.trafordOrange, size: 26),
          ),
        ],
      ),
    );
  }

  // -------------------- HERO --------------------
  Widget _buildHero() {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PageView.builder(
              controller: _heroController,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _heroIndex = i),
              itemBuilder: (context, index) =>
                  _heroCard(_slides[index]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Dot indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (i) {
            final active = i == _heroIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.trafordOrange
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _heroCard(_HeroSlide slide) {
    return Container(
      decoration: BoxDecoration(
        color: _softMint,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // Text side
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 8, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textDark,
                        height: 1.15,
                      ),
                      children: [
                        TextSpan(text: slide.headlineStart),
                        TextSpan(
                          text: slide.headlineGreen,
                          style: const TextStyle(
                              color: AppTheme.growthGreen),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    slide.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => widget.onNavigate?.call(1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.trafordOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('Shop Now'),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Image side
          Expanded(
            flex: 4,
            child: SizedBox(
              height: double.infinity,
              child: Image.network(
                slide.image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: _softMint,
                  child: const Center(
                    child: Text('🥬',
                        style: TextStyle(fontSize: 60)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- FEATURES BAR --------------------
  Widget _buildFeaturesBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          _featureItem(Icons.eco, '100% Organic', 'Clean & Safe'),
          _featureDivider(),
          _featureItem(
              Icons.local_shipping, 'Fast Delivery', 'At your door'),
          _featureDivider(),
          _featureItem(
              Icons.handshake, 'Fair Trade', 'Ethical sourcing'),
        ],
      ),
    );
  }

  Widget _featureDivider() {
    return Container(
      width: 1,
      height: 36,
      color: _border,
    );
  }

  Widget _featureItem(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppTheme.growthGreen, size: 22),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // -------------------- SECTION HEADER --------------------
  Widget _buildSectionHeader(String title,
      {String? actionLabel, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.textDark,
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.trafordOrange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // -------------------- CATEGORIES --------------------
  Widget _buildCategoriesRow(
      BuildContext context, List cats, bool isLoading) {
    if (isLoading && cats.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: CircularProgressIndicator(
              color: AppTheme.trafordOrange),
        ),
      );
    }

    if (cats.isEmpty) {
      return SizedBox(
        height: 100,
        child: Center(
          child: TextButton.icon(
            onPressed: () =>
                context.read<ProductService>().initialize(),
            icon: const Icon(Icons.refresh,
                color: AppTheme.trafordOrange),
            label: const Text(
              'Tap to reload categories',
              style: TextStyle(color: AppTheme.trafordOrange),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: cats.length,
        itemBuilder: (context, index) {
          final cat = cats[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopScreen(
                    onNavigate: widget.onNavigate,
                    initialCategoryId: cat.id,
                  ),
                ),
              );
            },
            child: Container(
              width: 70,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _softMint2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        cat.emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.name,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textDark,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------- FEATURED STRIP --------------------
  Widget _buildFeaturedStrip(
      ProductService productService, List featured) {
    if (productService.isLoading && featured.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(
              color: AppTheme.trafordOrange),
        ),
      );
    }

    if (featured.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('No products yet',
                  style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => productService.loadProducts(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: featured.length,
        itemBuilder: (context, index) {
          final product = featured[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              width: 110,
              child: ProductCard(
                product: product,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ProductDetailScreen(product: product),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------- PROMO BANNER --------------------
  Widget _buildPromoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
      decoration: BoxDecoration(
        color: _softMint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Eat Fresh,\nStay Healthy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Handpicked quality\nproduce for your family.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => widget.onNavigate?.call(1),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.growthGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Explore More',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 130,
              child: Image.network(
                'https://images.unsplash.com/photo-1610348725531-843dff563e2c?auto=format&fit=crop&w=400&q=80',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('🥕🍇🍌',
                      style: TextStyle(fontSize: 40)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroSlide {
  final String headlineStart;
  final String headlineGreen;
  final String subtitle;
  final String image;

  const _HeroSlide({
    required this.headlineStart,
    required this.headlineGreen,
    required this.subtitle,
    required this.image,
  });
}
