class Product {
  final int id;
  final String title;
  final String? description; // Made nullable
  final num price;
  final String category;
  final String? condition; // Made nullable
  final String? location; // Made nullable
  final String seller;
  final int? sellerId;
  final double? rating; // Made nullable
  final String? image; // Made nullable
  final DateTime? createdAt; // Timestamp when product was created
  final int sold; // 1 if sold, 0 if available

  Product({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    required this.category,
    this.condition,
    this.location,
    required this.seller,
    this.sellerId,
    this.rating,
    this.image,
    this.createdAt,
    this.sold = 0,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse numbers
    num parsePrice(dynamic price) {
      if (price is num) return price;
      if (price is String) return num.tryParse(price) ?? 0;
      return 0;
    }

    // Safely access nested seller name
    String getSellerName(dynamic seller) {
      if (seller is Map<String, dynamic>) {
        // Try 'name' first
        if (seller.containsKey('name')) {
          final name = seller['name'];
          if (name is String && name.isNotEmpty) return name;
        }
        // Try 'username' as fallback
        if (seller.containsKey('username')) {
          final username = seller['username'];
          if (username is String && username.isNotEmpty) return username;
        }
        // Try 'email' as last resort
        if (seller.containsKey('email')) {
          final email = seller['email'];
          if (email is String && email.isNotEmpty) {
            // Extract name before @ symbol
            return email.split('@').first;
          }
        }
      }
      // If seller is directly a string, return it
      if (seller is String && seller.isNotEmpty) return seller;
      print('DEBUG: Unable to parse seller name from: $seller');
      return 'Unknown Seller';
    }

    // Safely access nested seller id - try multiple possible field names
    int? getSellerId(dynamic seller) {
      if (seller is Map<String, dynamic>) {
        // Try 'id' first
        if (seller.containsKey('id')) {
          final val = seller['id'];
          if (val is int) return val;
          if (val is String) return int.tryParse(val);
        }
        // Try 'user_id' as fallback
        if (seller.containsKey('user_id')) {
          final val = seller['user_id'];
          if (val is int) return val;
          if (val is String) return int.tryParse(val);
        }
      }
      // Debug: print what we received
      print('DEBUG: seller object = $seller');
      // Fallback: use a default ID for testing
      return 1;
    }

    // Safely access the first image url from the images array
    String? getImageUrl(dynamic images) {
      if (images is List && images.isNotEmpty) {
        // Images are direct URL strings in the array
        final firstImage = images.first;
        if (firstImage is String) {
          return firstImage;
        }
      }
      return null;
    }

    // Parse created_at timestamp
    DateTime? parseCreatedAt(dynamic createdAt) {
      if (createdAt is String) {
        return DateTime.tryParse(createdAt);
      }
      return null;
    }

    return Product(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      price: parsePrice(json['price']),
      category: json['category'] is Map
          ? (json['category']['label'] ?? 'Others')
          : (json['category'] as String? ?? 'Others'),
      condition: json['condition'] as String?,
      location: json['location'] as String?,
      seller: getSellerName(json['seller']),
      sellerId: getSellerId(json['seller'] ?? json['user'] ?? {}),
      rating: json['rating'] != null
          ? double.tryParse(json['rating'].toString())
          : null,
      image: getImageUrl(json['images'] ?? json['imageUrls']),
      createdAt: parseCreatedAt(json['created_at']),
      sold: json['sold'] is int ? json['sold'] as int : 0,
    );
  }
}

class Category {
  final String label;
  final String icon;
  final String color;

  Category({
    required this.label,
    required this.icon,
    required this.color,
  });
}
