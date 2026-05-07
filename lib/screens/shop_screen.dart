import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';
import '../screens/product_detail_screen.dart';

/// Shop screen redesigned to match the reference design:
/// - Orange header with "Shop" title and filter icon on the right
/// - White search bar inside the orange header
/// - Horizontal pill-style category chips (selected = orange filled)
/// - "X products" + "Sort by: <label>" row
/// - 3-column product grid using the compact ProductCard
class ShopScreen extends StatefulWidget {
  final void Function(int)? onNavigate;
  final int? initialCategoryId;
  final bool initialSearch;

  const ShopScreen({
    super.key,
    this.onNavigate,
    this.initialCategoryId,
    this.initialSearch = false,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int? _selectedCategoryId;
  String _searchQuery = '';
  String _sortBy = 'default';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialCategoryId;
    if (widget.initialSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  List<Product> _getFilteredProducts(ProductService productService) {
    List<Product> products;
    if (_selectedCategoryId != null) {
      products = productService.getByCategory(_selectedCategoryId!);
    } else {
      products = List.from(productService.allProducts);
    }

    if (_searchQuery.isNotEmpty) {
      products = products
          .where((p) =>
              p.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    switch (_sortBy) {
      case 'price-asc':
        products.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'price-desc':
        products.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'rating':
        products.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'popularity':
        products.sort((a, b) => b.reviewCount.compareTo(a.reviewCount));
        break;
    }

    return products;
  }

  @override
  Widget build(BuildContext context) {
    final productService = context.watch<ProductService>();
    final products = _getFilteredProducts(productService);
    final topCategories = productService.topCategories;
    final isSubPage =
        widget.initialCategoryId != null || widget.initialSearch;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Orange header with title + search
          _buildOrangeHeader(context, isSubPage, topCategories),

          const SizedBox(height: 12),

          // Category chips
          _buildCategoryChips(topCategories),

          const SizedBox(height: 8),

          // Results info + Sort
          _buildResultsRow(products.length),

          // Product grid
          Expanded(
            child: productService.isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.trafordOrange))
                : products.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppTheme.trafordOrange,
                        onRefresh: () async {
                          await productService.loadProducts();
                        },
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              12, 8, 12, 16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.62,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return ProductCard(
                              product: product,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProductDetailScreen(
                                        product: product),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // -------------------- ORANGE HEADER --------------------
  Widget _buildOrangeHeader(BuildContext context, bool isSubPage,
      List<Category> topCategories) {
    return Container(
      color: AppTheme.trafordOrange,
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isSubPage)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.arrow_back,
                        color: Colors.white, size: 24),
                  ),
                ),
              const Expanded(
                child: Text(
                  'Shop',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showFilterSheet(topCategories),
                child: const Icon(Icons.filter_alt_outlined,
                    color: Colors.white, size: 26),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // White search bar inside orange area
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(
                  fontSize: 14, color: AppTheme.textDark),
              decoration: InputDecoration(
                hintText: 'Search for fresh products...',
                hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(Icons.search,
                    color: Color(0xFF9CA3AF), size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close,
                            color: Color(0xFF9CA3AF), size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- CATEGORY CHIPS --------------------
  Widget _buildCategoryChips(List<Category> topCategories) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _chip(null, 'All'),
          ...topCategories.map((cat) => _chip(cat.id, cat.name)),
        ],
      ),
    );
  }

  Widget _chip(int? id, String label) {
    final selected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategoryId = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.trafordOrange : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? AppTheme.trafordOrange
                  : const Color(0xFFE5E7EB),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textDark,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // -------------------- RESULTS ROW --------------------
  Widget _buildResultsRow(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$count products',
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 13,
            ),
          ),
          GestureDetector(
            onTap: _showSortSheet,
            child: Row(
              children: [
                const Text(
                  'Sort by: ',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _sortLabel,
                  style: const TextStyle(
                    color: AppTheme.trafordOrange,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- EMPTY STATE --------------------
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text(
            'No products found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try a different search or category',
            style:
                TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedCategoryId = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.trafordOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }

  String get _sortLabel {
    switch (_sortBy) {
      case 'price-asc':
        return 'Price: Low';
      case 'price-desc':
        return 'Price: High';
      case 'rating':
        return 'Rating';
      case 'popularity':
        return 'Popular';
      default:
        return 'Default';
    }
  }

  // -------------------- SORT SHEET --------------------
  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sort By',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            ...[
              ('default', 'Default'),
              ('popularity', 'Popularity'),
              ('rating', 'Rating'),
              ('price-asc', 'Price: Low to High'),
              ('price-desc', 'Price: High to Low'),
            ].map(
              (opt) => ListTile(
                title: Text(opt.$2),
                trailing: _sortBy == opt.$1
                    ? const Icon(Icons.check,
                        color: AppTheme.trafordOrange)
                    : null,
                onTap: () {
                  setState(() => _sortBy = opt.$1);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------- FILTER SHEET --------------------
  void _showFilterSheet(List<Category> topCategories) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter by Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCategoryId = null;
                        _searchQuery = '';
                        _searchController.clear();
                        _sortBy = 'default';
                      });
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Clear All',
                      style: TextStyle(
                        color: AppTheme.trafordOrange,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    ListTile(
                      leading: const Text('🛒',
                          style: TextStyle(fontSize: 22)),
                      title: const Text('All Products'),
                      trailing: _selectedCategoryId == null
                          ? const Icon(Icons.check,
                              color: AppTheme.trafordOrange)
                          : null,
                      onTap: () {
                        setState(() => _selectedCategoryId = null);
                        Navigator.pop(context);
                      },
                    ),
                    ...topCategories.map(
                      (cat) => ListTile(
                        leading: Text(cat.emoji,
                            style: const TextStyle(fontSize: 22)),
                        title: Text(cat.name),
                        trailing: _selectedCategoryId == cat.id
                            ? const Icon(Icons.check,
                                color: AppTheme.trafordOrange)
                            : null,
                        onTap: () {
                          setState(() => _selectedCategoryId = cat.id);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
