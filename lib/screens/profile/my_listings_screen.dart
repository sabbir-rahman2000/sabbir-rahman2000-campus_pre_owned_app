import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_colors.dart';
import '../../utils/models.dart';
import '../auth/login_screen.dart';
import '../../widgets/product_card.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  static const String _baseUrl =
      'https://backend-for-app-main-hsw776.laravel.cloud/api';

  List<Product> _products = [];
  bool _isLoading = true;
  int? _userId;

  @override
  void initState() {
    super.initState();
    _fetchUserIdAndProducts();
  }

  Future<void> _fetchUserIdAndProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
      return;
    }

    try {
      // First get user ID from /auth/me
      final meResponse = await http.get(
        Uri.parse('$_baseUrl/auth/me'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (meResponse.statusCode == 200) {
        final meData = jsonDecode(meResponse.body);
        final userId = meData['data']?['user']?['id'];
        print('DEBUG: User ID = $userId');

        if (userId != null) {
          setState(() => _userId = userId);
          await _fetchProducts(userId, token);
        }
      } else {
        throw Exception('Failed to fetch user info');
      }
    } catch (e) {
      print('ERROR: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _fetchProducts(int userId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$userId/products'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('DEBUG: Response status = ${response.statusCode}');
      print('DEBUG: Response body = ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final data = responseData['data'];

        // Handle paginated response: { data: { current_page, data: [...] } }
        List<dynamic> productsList = [];
        if (data is Map && data['data'] is List) {
          productsList = data['data'];
        } else if (data is List) {
          productsList = data;
        }

        print('DEBUG: Found ${productsList.length} products');

        final products = productsList
            .map((p) => Product.fromJson(p as Map<String, dynamic>))
            .toList();

        setState(() {
          _products = products;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to fetch products: ${response.statusCode}');
      }
    } catch (e) {
      print('ERROR: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listings'),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'You have no active listings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Start selling by adding a new product',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    return ProductCard(product: _products[index]);
                  },
                ),
    );
  }
}
