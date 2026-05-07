import 'package:flutter/material.dart';
import 'supabase_config.dart';
import '../models/product.dart';

class ProductService extends ChangeNotifier {
  List<Product> _allProducts = [];
  List<Product> _featuredProducts = [];
  List<Category> _categories = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  // Cache for category-filtered products to avoid recomputing
  final Map<int, List<Product>> _categoryCache = {};

  List<Product> get allProducts => _allProducts;
  List<Product> get featuredProducts => _featuredProducts;
  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  List<Category> get topCategories {
    // Return all categories that actually contain products for browsing.
    // - Child categories (e.g. Vegetables, Fruits under Fresh Produce)
    // - Standalone parent categories that have products directly (e.g. Dry Items, Honey Bee, Legumes)
    // Exclude abstract parent categories that only serve as grouping (e.g. Fresh Produce, Meat and Poultry)

    final parentIds = _categories.map((c) => c.parentId).whereType<int>().toSet();

    final result = <Category>[];
    for (final cat in _categories) {
      if (cat.parentId != null) {
        // Child category - always show (e.g. Vegetables, Fruits, Local Beef)
        result.add(cat);
      } else if (!parentIds.contains(cat.id)) {
        // Standalone category with no children - show it (e.g. Dry Items, Honey Bee, Legumes)
        result.add(cat);
      }
      // Skip abstract parents like "Fresh Produce" and "Meat and Poultry" that have children
    }

    return result;
  }

  Future<void> initialize() async {
    if (_isInitialized && _allProducts.isNotEmpty) return;
    _isInitialized = false; // Reset in case of retry
    // Load categories and products in parallel for speed
    await Future.wait([loadCategories(), loadProducts()]);
    _isInitialized = _allProducts.isNotEmpty;
  }

  Future<void> loadCategories() async {
    try {
      final response = await SupabaseConfig.client
          .from('categories')
          .select()
          .order('name');

      _categories = (response as List)
          .map((json) => Category.fromJson(json as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await SupabaseConfig.client
          .from('products')
          .select()
          .order('name');

      _allProducts = (response as List)
          .map((json) => Product.fromJson(json as Map<String, dynamic>))
          .toList();

      _featuredProducts = _allProducts.where((p) => p.featured).toList();

      // Clear category cache when products are reloaded
      _categoryCache.clear();
    } catch (e) {
      _error = 'Failed to load products: $e';
      debugPrint('Error loading products: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  List<Product> getByCategory(int categoryId) {
    // Return from cache if available
    if (_categoryCache.containsKey(categoryId)) {
      return _categoryCache[categoryId]!;
    }

    // If the category is a parent (e.g. Meat & Poultry), include all children
    final childCatIds = _categories
        .where((c) => c.parentId == categoryId)
        .map((c) => c.id)
        .toSet();

    List<Product> result;
    if (childCatIds.isNotEmpty) {
      result = _allProducts
          .where((p) =>
              p.categoryId == categoryId || childCatIds.contains(p.categoryId))
          .toList();
    } else {
      result = _allProducts.where((p) => p.categoryId == categoryId).toList();
    }

    // Cache the result
    _categoryCache[categoryId] = result;
    return result;
  }

  Product? getById(int id) {
    try {
      return _allProducts.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Product> search(String query) {
    final q = query.toLowerCase();
    return _allProducts
        .where((p) => p.name.toLowerCase().contains(q))
        .toList();
  }

  Future<List<Review>> getReviews(int productId) async {
    try {
      final response = await SupabaseConfig.client
          .from('reviews')
          .select('*, users(name)')
          .eq('product_id', productId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Review.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading reviews: $e');
      return [];
    }
  }

  String categoryName(int catId) {
    try {
      return _categories.firstWhere((c) => c.id == catId).name;
    } catch (_) {
      return 'General';
    }
  }
}
