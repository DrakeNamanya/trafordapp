import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/product_service.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  List<Review> _reviews = [];
  bool _loadingReviews = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final productService =
        Provider.of<ProductService>(context, listen: false);
    final reviews = await productService.getReviews(widget.product.id);
    if (mounted) {
      setState(() {
        _reviews = reviews;
        _loadingReviews = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final productService = context.watch<ProductService>();
    final product = widget.product;
    final inWishlist = cart.isInWishlist(product.id);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Image Header
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppTheme.trafordOrange,
            leading: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.white,
                radius: 18,
                child:
                    Icon(Icons.arrow_back, color: AppTheme.textDark, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 18,
                  child: Icon(
                    inWishlist ? Icons.favorite : Icons.favorite_border,
                    color: inWishlist ? Colors.red : AppTheme.textMuted,
                    size: 20,
                  ),
                ),
                onPressed: () => cart.toggleWishlist(product.id),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: const Color(0xFFF3F4F6),
                child: product.image != null
                    ? CachedNetworkImage(
                        imageUrl: product.image!,
                        fit: BoxFit.cover,
                        memCacheWidth: 800,
                        fadeInDuration:
                            const Duration(milliseconds: 150),
                        errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.eco,
                              size: 80, color: AppTheme.trafordOrange),
                        ),
                        placeholder: (_, __) => const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.trafordOrange,
                            ),
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(Icons.eco,
                            size: 80, color: AppTheme.trafordOrange),
                      ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              transform: Matrix4.translationValues(0, -20, 0),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Featured Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                      if (product.featured)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.softLeaf,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Featured',
                            style: TextStyle(
                              color: AppTheme.growthGreen,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Rating
                  if (product.rating > 0)
                    Row(
                      children: [
                        ...List.generate(5, (i) {
                          return Icon(
                            i < product.rating.round()
                                ? Icons.star
                                : Icons.star_border,
                            size: 20,
                            color: i < product.rating.round()
                                ? AppTheme.starYellow
                                : Colors.grey[300],
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          '${product.rating.toStringAsFixed(1)} (${product.reviewCount} reviews)',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Price
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'UGX ${formatUGX(product.price)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.trafordOrange,
                        ),
                      ),
                      if (product.hasDiscount) ...[
                        const SizedBox(width: 12),
                        Text(
                          'UGX ${formatUGX(product.originalPrice!)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppTheme.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Product Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.bgGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _infoRow('Unit', product.unit),
                        const Divider(height: 20),
                        _infoRow(
                          'Stock',
                          product.inStock
                              ? '${product.stock} available'
                              : 'Out of stock',
                          valueColor: product.inStock
                              ? AppTheme.trafordOrange
                              : Colors.red,
                        ),
                        const Divider(height: 20),
                        _infoRow('Category',
                            productService.categoryName(product.categoryId)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Description
                  if (product.description != null) ...[
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      product.description!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Quantity Selector
                  const Text(
                    'Quantity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.cardBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                        ),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            '$_quantity',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => setState(() => _quantity++),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Reviews
                  if (_loadingReviews)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_reviews.isNotEmpty) ...[
                    Text(
                      'Customer Reviews (${_reviews.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._reviews.map((review) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.bgGray,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    review.userName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Row(
                                    children: List.generate(
                                      5,
                                      (i) => Icon(
                                        i < review.rating
                                            ? Icons.star
                                            : Icons.star_border,
                                        size: 14,
                                        color: i < review.rating
                                            ? AppTheme.starYellow
                                            : Colors.grey[300],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (review.title != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  review.title!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              if (review.comment != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  review.comment!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textMuted,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        )),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom Add to Cart Bar
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total',
                      style:
                          TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    Text(
                      'UGX ${formatUGX(product.price * _quantity)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.trafordOrange,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: product.inStock
                      ? () {
                          cart.addToCart(product, quantity: _quantity);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('${product.name} added to cart'),
                              backgroundColor: AppTheme.trafordOrange,
                              behavior: SnackBarBehavior.floating,
                              action: SnackBarAction(
                                label: 'VIEW CART',
                                textColor: Colors.white,
                                onPressed: () => Navigator.pop(context),
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: const Text('Add to Cart'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppTheme.textDark,
          ),
        ),
      ],
    );
  }
}
