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
    return Product(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Product',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      categoryId: json['category_id'] as int? ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      image: json['image'] as String?,
      stock: json['stock'] as int? ?? 50,
      featured: json['featured'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      unit: json['unit'] as String? ?? 'piece',
    );
  }
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

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      description: json['description'] as String?,
      parentId: json['parent_id'] as int?,
      image: json['image'] as String?,
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
}

class Order {
  final int id;
  final String orderNumber;
  final String status;
  final double subtotal;
  final double tax;
  final double total;
  final String? shippingAddress;
  final String? shippingCity;
  final String? shippingPhone;
  final String? paymentMethod;
  final String paymentStatus;
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
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }
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
