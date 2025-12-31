import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_colors.dart';
import '../../utils/models.dart';
import '../../widgets/logo_widget.dart';
import '../../widgets/product_card.dart';
import '../../widgets/bottom_nav.dart';
import '../product/search_screen.dart';
import '../messages/notifications_screen.dart';
import '../auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _baseUrl =
      'https://backend-for-app-main-hsw776.laravel.cloud/api';

  bool _isLoading = true;
  bool _requiresLogin = false;
  String? _selectedCategory;
  List<Product> _products = [];

  final List<Category> _categories = [
    Category(label: 'Textbooks', icon: 'book', color: '#87CEEB'),
    Category(label: 'Electronics', icon: 'laptop', color: '#87CEEB'),
    Category(label: 'Bikes', icon: 'bike', color: '#87CEEB'),
    Category(label: 'Room Decor', icon: 'lamp', color: '#87CEEB'),
    Category(label: 'Furniture', icon: 'chair', color: '#87CEEB'),
    Category(label: 'Others', icon: 'bag', color: '#87CEEB'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _requiresLogin = true;
          _products = [];
        });
      }
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/authenticated-products'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final List<dynamic> productList = responseData['data']['data'];

        // Load products and fetch owner names
        final List<Product> loadedProducts = [];
        for (var json in productList) {
          final product = Product.fromJson(json);
          // Fetch owner name from the new API (Public endpoint)
          try {
            final ownerResponse = await http.get(
              Uri.parse('$_baseUrl/products/${product.id}/owner'),
              headers: {
                'Accept': 'application/json',
              },
            );

            if (ownerResponse.statusCode == 200) {
              final ownerData = jsonDecode(ownerResponse.body);
              print(
                  'DEBUG: Owner API response for product ${product.id}: $ownerData');
              final ownerName = ownerData['data']['name'] as String?;
              print('DEBUG: Parsed owner name: $ownerName');
              // Create a new product with the fetched owner name
              final updatedProduct = Product(
                id: product.id,
                title: product.title,
                description: product.description,
                price: product.price,
                category: product.category,
                condition: product.condition,
                location: product.location,
                seller: ownerName ?? product.seller,
                sellerId: product.sellerId,
                rating: product.rating,
                image: product.image,
                createdAt: product.createdAt,
                sold: product.sold,
              );
              loadedProducts.add(updatedProduct);
            } else {
              print(
                  'DEBUG: Owner API failed with status ${ownerResponse.statusCode} for product ${product.id}');
              loadedProducts.add(product);
            }
          } catch (e) {
            print('DEBUG: Failed to fetch owner for product ${product.id}: $e');
            loadedProducts.add(product);
          }
        }

        setState(() {
          _products = loadedProducts;
          _isLoading = false;
          _requiresLogin = false;
        });
      } else {
        // Do not force logout; show error and allow manual retry
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load products. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching products: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  List<Product> get _filteredListings {
    if (_selectedCategory == null) return _products;
    return _products.where((p) => p.category == _selectedCategory).toList();
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchProducts();
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'book':
        return Icons.menu_book;
      case 'laptop':
        return Icons.laptop;
      case 'bike':
        return Icons.directions_bike;
      case 'lamp':
        return Icons.lightbulb;
      case 'chair':
        return Icons.chair;
      case 'bag':
        return Icons.shopping_bag;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 600;

    int crossAxisCount = 2;
    int categoryCrossAxisCount = 3;
    double childAspectRatio = 0.8;

    if (screenWidth > 1200) {
      crossAxisCount = 4;
      categoryCrossAxisCount = 6;
      childAspectRatio = 1.0;
    } else if (screenWidth > 800) {
      crossAxisCount = 3;
      categoryCrossAxisCount = 4;
      childAspectRatio = 0.9;
    }

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(isWeb ? 24 : 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: LogoWidget()),
                        IconButton(
                          onPressed: _handleRefresh,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primaryDark,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.8),
                            foregroundColor: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const NotificationsScreen(),
                              ),
                            );
                          },
                          icon: Stack(
                            children: [
                              const Icon(Icons.notifications),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.8),
                            foregroundColor: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: isWeb ? 600 : double.infinity),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SearchScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.search, color: AppColors.textLight),
                              SizedBox(width: 12),
                              Text(
                                'Search items...',
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isWeb ? 24 : 16),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: isWeb ? 1200 : double.infinity),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_requiresLogin) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Please log in to view products',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 40,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const LoginScreen(),
                                    ),
                                  );
                                },
                                child: const Text('Log In'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: categoryCrossAxisCount,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = _selectedCategory == category.label;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory =
                                  isSelected ? null : category.label;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  isSelected ? AppColors.primary : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.2)
                                        : AppColors.primary.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _getCategoryIcon(category.icon),
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.primary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  category.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textDark,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedCategory ?? 'Featured Listings',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_selectedCategory != null)
                          TextButton(
                            onPressed: () {
                              setState(() => _selectedCategory = null);
                            },
                            child: const Text(
                              'View All',
                              style: TextStyle(color: AppColors.primaryDark),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    !_requiresLogin && _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : !_requiresLogin && _filteredListings.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Text('No items found.'),
                                ),
                              )
                            : !_requiresLogin
                                ? GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                      childAspectRatio: childAspectRatio,
                                    ),
                                    itemCount: _filteredListings.length,
                                    itemBuilder: (context, index) {
                                      return ProductCard(
                                          product: _filteredListings[index]);
                                    },
                                  )
                                : const SizedBox.shrink(),

                    const SizedBox(height: 24),
                    SizedBox(height: isWeb ? 24 : 100), // Bottom nav padding
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(),
    );
  }
}
