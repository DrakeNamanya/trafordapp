class Product {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final int categoryId;
  final double price;
  final double? originalPrice;
  final String? image;
  final int stock;
  final bool featured;
  final double rating;
  final int reviewCount;
  final String unit;

  const Product({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    required this.categoryId,
    required this.price,
    this.originalPrice,
    this.image,
    this.stock = 50,
    this.featured = false,
    this.rating = 0,
    this.reviewCount = 0,
    this.unit = 'piece',
  });

  bool get inStock => stock > 0;
  bool get hasDiscount => originalPrice != null && originalPrice! > price;
  double get discountPercent =>
      hasDiscount ? ((originalPrice! - price) / originalPrice! * 100) : 0;

  factory Product.fromJson(Map<String, dynamic> json) {
    // Accept BOTH the legacy schema (image, featured) and the new public
    // API schema (image_url, is_featured) so we work with either backend.
    return Product(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Product',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      categoryId: json['category_id'] as int? ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      image: (json['image_url'] as String?) ?? (json['image'] as String?),
      stock: json['stock'] as int? ?? 50,
      featured:
          (json['is_featured'] as bool?) ?? (json['featured'] as bool?) ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      unit: json['unit'] as String? ?? 'piece',
    );
  }

  /// Serialise the product to a JSON-safe map. Used by CartService to persist
  /// the cart locally via SharedPreferences (works for both guest and
  /// signed-in users).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'description': description,
        'category_id': categoryId,
        'price': price,
        'original_price': originalPrice,
        'image': image,
        'stock': stock,
        'featured': featured,
        'rating': rating,
        'review_count': reviewCount,
        'unit': unit,
      };
}

class Category {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final int? parentId;
  final String? image;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.parentId,
    this.image,
  });

  String get emoji {
    final s = slug.toLowerCase();
    if (s.contains('vegetable')) return '\u{1F96C}';
    if (s.contains('fruit')) return '\u{1F34E}';
    if (s.contains('honey') || s.contains('bee')) return '\u{1F36F}';
    if (s.contains('legume') || s.contains('nut')) return '\u{1F95C}';
    if (s.contains('dry')) return '\u{1F33E}';
    if (s.contains('meat') || s.contains('poultry')) return '\u{1F357}';
    if (s.contains('beef')) return '\u{1F969}';
    if (s.contains('chicken')) return '\u{1F414}';
    if (s.contains('goat')) return '\u{1F410}';
    if (s.contains('fresh') || s.contains('produce')) return '\u{1F33E}';
    return '\u{1F33F}';
  }

  /// Photo URL to render in place of the emoji icon on the Shop-by-Category
  /// tiles. We prefer the backend-supplied [image] when present, otherwise
  /// fall back to a curated Unsplash thumbnail keyed by slug/name keywords.
  /// Returns null when no image can be inferred — caller should render the
  /// emoji fallback in that case.
  String? get displayImage {
    final remote = image?.trim();
    if (remote != null && remote.isNotEmpty) return remote;
    final s = (slug.isNotEmpty ? slug : name).toLowerCase();
    // Unsplash CDN with size + quality hints — keeps each thumb under 25KB.
    const w = 'auto=format&fit=crop&w=240&q=70';
    if (s.contains('vegetable')) {
      return 'https://images.unsplash.com/photo-1540420773420-3366772f4999?$w';
    }
    if (s.contains('fruit')) {
      return 'https://images.unsplash.com/photo-1610832958506-aa56368176cf?$w';
    }
    if (s.contains('spice') || s.contains('herb')) {
      return 'https://images.unsplash.com/photo-1505253758473-96b7015fcd40?$w';
    }
    if (s.contains('staple') || s.contains('tuber') ||
        s.contains('potato') || s.contains('matooke')) {
      return 'https://images.unsplash.com/photo-1518977676601-b53f82aba655?$w';
    }
    if (s.contains('cereal') || s.contains('legume') ||
        s.contains('bean') || s.contains('grain')) {
      return 'https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?$w';
    }
    if (s.contains('meat') || s.contains('beef') ||
        s.contains('poultry') || s.contains('chicken') ||
        s.contains('goat')) {
      return 'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?$w';
    }
    if (s.contains('honey') || s.contains('bee') || s.contains('egg')) {
      return 'https://images.unsplash.com/photo-1587049352846-4a222e784d38?$w';
    }
    if (s.contains('nut')) {
      return 'https://images.unsplash.com/photo-1599599810769-bcde5a160d32?$w';
    }
    if (s.contains('seed')) {
      return 'https://images.unsplash.com/photo-1574323347407-f5e1ad6d020b?$w';
    }
    if (s.contains('fertili')) {
      return 'https://images.unsplash.com/photo-1592978603886-1f8b1c4a9fb9?$w';
    }
    if (s.contains('tool')) {
      return 'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?$w';
    }
    if (s.contains('dry')) {
      return 'https://images.unsplash.com/photo-1612257999756-d3d3e9b53d4b?$w';
    }
    return null;
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      parentId: json['parent_id'] as int?,
      image: (json['image_url'] as String?) ?? (json['image'] as String?),
    );
  }
}

class CartItem {
  final int id; // cart_items.id from Supabase
  final int productId;
  final Product product;
  int quantity;

  CartItem({
    required this.id,
    required this.productId,
    required this.product,
    this.quantity = 1,
  });

  double get subtotal => product.price * quantity;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final productData = json['products'] as Map<String, dynamic>? ?? {};
    return CartItem(
      id: json['id'] as int,
      productId: json['product_id'] as int,
      product: Product(
        id: productData['id'] as int? ?? json['product_id'] as int,
        name: productData['name'] as String? ?? 'Product',
        slug: productData['slug'] as String? ?? '',
        price: (productData['price'] as num?)?.toDouble() ?? 0,
        image: productData['image'] as String?,
        stock: productData['stock'] as int? ?? 100,
        unit: productData['unit'] as String? ?? 'piece',
        categoryId: productData['category_id'] as int? ?? 0,
        featured: productData['featured'] as bool? ?? false,
        rating: (productData['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: productData['review_count'] as int? ?? 0,
      ),
      quantity: json['quantity'] as int? ?? 1,
    );
  }

  /// Local-cart serialisation: stores the full product snapshot so the cart
  /// survives an app restart even when offline / not signed in.
  Map<String, dynamic> toLocalJson() => {
        'id': id,
        'product_id': productId,
        'quantity': quantity,
        'product': product.toJson(),
      };

  /// Inverse of [toLocalJson].
  factory CartItem.fromLocalJson(Map<String, dynamic> json) {
    final p = json['product'] as Map<String, dynamic>? ?? {};
    return CartItem(
      id: json['id'] as int? ?? 0,
      productId: json['product_id'] as int,
      product: Product.fromJson(p),
      quantity: json['quantity'] as int? ?? 1,
    );
  }
}

class Order {
  final int id;
  final String orderNumber;
  String status;
  final double subtotal;
  final double tax;
  final double total;
  final String? shippingAddress;
  final String? shippingCity;
  final String? shippingPhone;
  final String? paymentMethod;
  String paymentStatus;
  final DateTime createdAt;
  List<OrderItem> items;

  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.subtotal,
    required this.tax,
    required this.total,
    this.shippingAddress,
    this.shippingCity,
    this.shippingPhone,
    this.paymentMethod,
    this.paymentStatus = 'pending',
    required this.createdAt,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as int,
      orderNumber: json['order_number'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      shippingAddress: json['shipping_address'] as String?,
      shippingCity: json['shipping_city'] as String?,
      shippingPhone: json['shipping_phone'] as String?,
      paymentMethod: json['payment_method'] as String?,
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Serializer for local cache (SharedPreferences). The public guest-checkout
  /// API returns numeric or string ids — keep them as-is.
  Map<String, dynamic> toLocalJson() => {
        'id': id,
        'order_number': orderNumber,
        'status': status,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'shipping_address': shippingAddress,
        'shipping_city': shippingCity,
        'shipping_phone': shippingPhone,
        'payment_method': paymentMethod,
        'payment_status': paymentStatus,
        'created_at': createdAt.toIso8601String(),
        'items': items.map((it) => it.toLocalJson()).toList(),
      };

  /// Deserializer for orders cached locally (and persisted to SharedPreferences).
  factory Order.fromLocalJson(Map<String, dynamic> json) {
    final items = (json['items'] as List?)
            ?.map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        const <OrderItem>[];
    return Order(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      orderNumber: json['order_number'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      shippingAddress: json['shipping_address'] as String?,
      shippingCity: json['shipping_city'] as String?,
      shippingPhone: json['shipping_phone'] as String?,
      paymentMethod: json['payment_method'] as String?,
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      items: items,
    );
  }
}

class OrderItem {
  final String productName;
  final int quantity;
  final double price;

  const OrderItem({
    required this.productName,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productName: json['product_name'] as String? ?? 'Product',
      quantity: json['quantity'] as int? ?? 1,
      // Public guest-checkout returns `unit_price`; legacy schema uses `price`.
      price: (json['price'] as num?)?.toDouble() ??
          (json['unit_price'] as num?)?.toDouble() ??
          0,
    );
  }

  Map<String, dynamic> toLocalJson() => {
        'product_name': productName,
        'quantity': quantity,
        'price': price,
      };
}

class Review {
  final int id;
  final String? title;
  final String? comment;
  final int rating;
  final String userName;
  final DateTime createdAt;

  const Review({
    required this.id,
    this.title,
    this.comment,
    required this.rating,
    required this.userName,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final userData = json['users'] as Map<String, dynamic>?;
    return Review(
      id: json['id'] as int,
      title: json['title'] as String?,
      comment: json['comment'] as String?,
      rating: json['rating'] as int? ?? 0,
      userName: userData?['name'] as String? ?? 'Anonymous',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class AppUser {
  final int id;
  final String email;
  final String? name;
  final String? phone;
  final String? address;
  final String? city;
  final String country;
  final String role;

  const AppUser({
    required this.id,
    required this.email,
    this.name,
    this.phone,
    this.address,
    this.city,
    this.country = 'Uganda',
    this.role = 'user',
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String? ?? 'Uganda',
      role: json['role'] as String? ?? 'user',
    );
  }
}
