import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';

/// Compact product card matching the reference design:
/// - White rounded card with subtle border
/// - Image on top with white circle heart in upper-right
/// - Name, per-unit subtitle, rating row
/// - Orange UGX price + GREEN circular plus button
class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const ProductCard({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final inCart = cart.isInCart(product.id);
    final inWishlist = cart.isInWishlist(product.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            AspectRatio(
              aspectRatio: 1.05,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: _SafeProductImage(imageUrl: product.image),
                  ),
                  // Wishlist heart (white circle, top-right)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => cart.toggleWishlist(product.id),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          inWishlist
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 14,
                          color: inWishlist
                              ? Colors.red
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppTheme.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'per ${product.unit}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  if (product.rating > 0) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star,
                            size: 11, color: AppTheme.starYellow),
                        const SizedBox(width: 2),
                        Text(
                          '${product.rating.toStringAsFixed(1)} (${product.reviewCount})',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'UGX ${formatUGX(product.price)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppTheme.trafordOrange,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          cart.addToCart(product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('${product.name} added to cart'),
                              backgroundColor: AppTheme.growthGreen,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppTheme.growthGreen,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            inCart ? Icons.check : Icons.add,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A defensive wrapper around [CachedNetworkImage] that:
/// - Validates the URL string before handing it to the framework
/// - Persists images to disk so reopening the Shop tab is instant
/// - Decodes at a small raster size (memCacheWidth) so the grid is light on RAM
/// - Falls back to a placeholder for missing / broken images
class _SafeProductImage extends StatelessWidget {
  final String? imageUrl;

  const _SafeProductImage({this.imageUrl});

  static const _placeholderColor = Color(0xFFF3F4F6);

  Widget _placeholder() => Container(
        color: _placeholderColor,
        child: const Center(
          child: Icon(Icons.eco,
              size: 40, color: AppTheme.trafordOrange),
        ),
      );

  bool _isValidUrl(String? raw) {
    if (raw == null) return false;
    final s = raw.trim();
    if (s.isEmpty) return false;
    if (!(s.startsWith('http://') ||
        s.startsWith('https://') ||
        s.startsWith('data:'))) {
      return false;
    }
    final uri = Uri.tryParse(s);
    return uri != null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isValidUrl(imageUrl)) {
      return _placeholder();
    }

    return CachedNetworkImage(
      imageUrl: imageUrl!.trim(),
      fit: BoxFit.cover,
      // Each card is roughly 130px wide at 3 cols on a typical phone, but
      // we leave room for tablets. 300 keeps memory low without visibly
      // softening the image.
      memCacheWidth: 300,
      maxWidthDiskCache: 600,
      filterQuality: FilterQuality.low,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, __) => Container(
        color: _placeholderColor,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.trafordOrange,
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => _placeholder(),
    );
  }
}

String formatUGX(double price) {
  return price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}
