import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_colors.dart';
import '../../utils/models.dart';
import '../../utils/messages_api.dart';
import '../../widgets/product_card.dart';
import '../auth/login_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  static const String _baseUrl =
      'https://backend-for-app-main-hsw776.laravel.cloud/api';

  bool _isLoading = true;
  List<Product> _wishlist = [];
  bool _requiresLogin = false;

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
  }

  Future<void> _fetchWishlist() async {
    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (mounted) {
        setState(() {
          _requiresLogin = true;
          _isLoading = false;
          _wishlist = [];
        });
      }
      return;
    }

    try {
      // Fetch all authenticated products, then filter by wishlist check
      final response = await http.get(
        Uri.parse('$_baseUrl/authenticated-products'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode != 200) {
        throw Exception('Failed to load products (${response.statusCode})');
      }

      final responseData = jsonDecode(response.body);
      final List<dynamic> productList = responseData['data']['data'];

      final List<Product> wishlistedProducts = [];

      // Check each product against wishlist endpoint
      for (final item in productList) {
        final product = Product.fromJson(item);
        try {
          final inWishlist = await MessagesApi.checkWishlist(product.id);
          if (inWishlist) {
            String? ownerName;
            try {
              final ownerResponse = await http.get(
                Uri.parse('$_baseUrl/products/${product.id}/owner'),
                headers: {
                  'Accept': 'application/json',
                },
              );

              if (ownerResponse.statusCode == 200) {
                final ownerData = jsonDecode(ownerResponse.body);
                ownerName = ownerData['data']?['name'] as String?;
              }
            } catch (e) {
              print(
                  'DEBUG: Failed to fetch owner for wishlist product ${product.id}: $e');
            }

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

            wishlistedProducts.add(updatedProduct);
          }
        } catch (e) {
          // If a single check fails, continue; surface a snack later
          print('DEBUG: wishlist check failed for product ${product.id}: $e');
        }
      }

      if (mounted) {
        setState(() {
          _wishlist = wishlistedProducts;
          _isLoading = false;
          _requiresLogin = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading wishlist: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleRefresh() async {
    await _fetchWishlist();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _handleRefresh,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _requiresLogin
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Please log in to view your wishlist'),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LoginScreen(),
                        ),
                      );
                    },
                    child: const Text('Log In'),
                  ),
                ],
              ),
            )
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _wishlist.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text('Your wishlist is empty.'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _handleRefresh,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: _wishlist.length,
                        itemBuilder: (context, index) {
                          return ProductCard(product: _wishlist[index]);
                        },
                      ),
                    ),
    );
  }
}
