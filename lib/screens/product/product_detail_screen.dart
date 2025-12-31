import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/app_colors.dart';
import '../../utils/models.dart';
import '../../utils/messages_api.dart';
import '../auth/login_screen.dart';
import '../messages/messages_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static const String _baseUrl =
      'https://backend-for-app-main-hsw776.laravel.cloud/api';

  Product? _product;
  Map<String, dynamic>? _owner;
  int? _currentUserId;
  bool _isLoading = true;
  bool _isWishlisted = false;

  @override
  void initState() {
    super.initState();
    _fetchProductDetails();
  }

  Future<int?> _getCurrentUserId() async {
    try {
      return await MessagesApi.getMyUserId();
    } catch (e) {
      print('DEBUG: Failed to get current user ID: $e');
      return null;
    }
  }

  Future<void> _checkWishlistStatus() async {
    if (_product == null) return;
    try {
      final status = await MessagesApi.checkWishlist(_product!.id);
      if (mounted) {
        setState(() => _isWishlisted = status);
      }
    } catch (e) {
      print('DEBUG: Failed to check wishlist status: $e');
    }
  }

  Future<void> _fetchProductDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
      return;
    }

    try {
      // Get current user ID first
      final userId = await _getCurrentUserId();

      // Fetch product details
      final response = await http.get(
        Uri.parse('$_baseUrl/products/${widget.productId}'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('DEBUG: Full product response = $responseData');

        // Check if response has 'data' wrapper
        final data = responseData['data'];
        print('DEBUG: Data wrapper = $data');

        if (data != null) {
          // Handle wrapped { data: { product: {...}, owner: {...} } } structure
          final productData = data['product'] ?? data;
          final ownerData = data['owner'];

          print('DEBUG: Product data = $productData');
          print('DEBUG: Owner data = $ownerData');
          print('DEBUG: Owner name = ${ownerData?['name']}');

          setState(() {
            _product = Product.fromJson(productData);
            _owner = ownerData;
            _currentUserId = userId;
            _isLoading = false;
          });
          _checkWishlistStatus();
        } else {
          // Direct product response (no wrapper)
          print('DEBUG: Direct product response = $responseData');
          setState(() {
            _product = Product.fromJson(responseData);
            _owner = null;
            _currentUserId = userId;
            _isLoading = false;
          });
          _checkWishlistStatus();
        }
      } else {
        print('ERROR: Status code = ${response.statusCode}');
        print('ERROR: Response body = ${response.body}');
        throw Exception(
            'Failed to load product details: ${response.statusCode}');
      }
    } catch (e) {
      print('ERROR: Exception in _fetchProductDetails = $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching product: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'Recently posted';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()} weeks ago';
    } else {
      return '${(difference.inDays / 30).floor()} months ago';
    }
  }

  bool _isOwnProduct() {
    if (_product == null || _currentUserId == null) return false;
    final sellerId = _owner?['id'] ?? _product?.sellerId;
    return sellerId != null && sellerId == _currentUserId;
  }

  @override
  Widget build(BuildContext context) {
    // Early return for loading state
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Early return for null product
    if (_product == null) {
      return const Scaffold(
        body: Center(child: Text('Product not found.')),
      );
    }

    // Safe reference to product from this point onwards
    final product = _product!;
    final isSold = product.sold == 1;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: product.image != null
                  ? CachedNetworkImage(
                      imageUrl: product.image!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.image_not_supported,
                          size: 64,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: Colors.grey,
                      ),
                    ),
            ),
            actions: [
              IconButton(
                onPressed: () async {
                  try {
                    if (_isWishlisted) {
                      await MessagesApi.removeFromWishlist(product.id);
                    } else {
                      await MessagesApi.addToWishlist(product.id);
                    }

                    if (mounted) {
                      setState(() => _isWishlisted = !_isWishlisted);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            _isWishlisted
                                ? 'Added to wishlist'
                                : 'Removed from wishlist',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                },
                icon: Icon(
                  _isWishlisted ? Icons.favorite : Icons.favorite_border,
                  color: _isWishlisted ? Colors.red : Colors.white,
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¥${product.price.toInt()}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            (_owner?['name'] ?? 'U').toString().isNotEmpty
                                ? (_owner?['name'] ?? 'U')
                                    .toString()[0]
                                    .toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _owner?['name'] ?? 'Unknown Seller',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    product.rating != null
                                        ? '${product.rating} rating'
                                        : 'No rating',
                                    style: const TextStyle(
                                      color: AppColors.textMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSold ? Colors.red : AppColors.success,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            isSold ? 'Sold Out' : 'Available',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description ?? 'No description available.',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textMedium,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Category', product.category),
                  _buildDetailRow('Condition', product.condition ?? 'N/A'),
                  _buildDetailRow('Posted', _getTimeAgo(product.createdAt)),
                  _buildDetailRow('Location', 'Zhengzhou University'),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isOwnProduct()
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Mark as Sold'),
                              content: const Text(
                                  'Are you sure you want to mark this product as sold?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'Mark Sold',
                                    style: TextStyle(color: Colors.orange),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && mounted) {
                            try {
                              await MessagesApi.markProductAsSold(
                                  product.id, null);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Product marked as sold successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.of(context).pop();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.orange),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Mark Sold',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Product'),
                              content: const Text(
                                  'Are you sure you want to delete this product? This action cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && mounted) {
                            try {
                              await MessagesApi.deleteProduct(product.id);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Product deleted successfully'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                Navigator.of(context).pop();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSold
                            ? null
                            : () {
                                final receiverId =
                                    _owner?['id'] ?? product.sellerId;
                                print(
                                    'DEBUG: Messaging with receiver ID = $receiverId');
                                if (receiverId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Seller not available for messaging'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                  return;
                                }
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => MessagesScreen(
                                      initialReceiverId: receiverId,
                                      initialReceiverName:
                                          _owner?['name'] as String?,
                                      initialProductId: product.id,
                                    ),
                                  ),
                                );
                              },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isSold ? Colors.grey : AppColors.primary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          'Message Seller',
                          style: TextStyle(
                            color: isSold ? Colors.grey : AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSold
                            ? null
                            : () async {
                                final receiverId =
                                    _owner?['id'] ?? product.sellerId;
                                if (receiverId == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Seller not available'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                  return;
                                }

                                final payload = {
                                  'product_id': product.id,
                                  'title': product.title,
                                  'price': product.price,
                                  'image': product.image,
                                  'note': 'I want to buy this product.'
                                };
                                final body =
                                    'BUY_REQUEST: ${jsonEncode(payload)}';

                                try {
                                  await MessagesApi.sendMessage(
                                    receiverId: receiverId,
                                    body: body,
                                    status: 'sent',
                                  );
                                  if (!mounted) return;
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => MessagesScreen(
                                        initialReceiverId: receiverId,
                                        initialReceiverName:
                                            _owner?['name'] as String?,
                                        initialProductId: product.id,
                                      ),
                                    ),
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Failed to send message: $e'),
                                      backgroundColor: AppColors.error,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isSold ? Colors.grey : AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(
                          isSold ? 'Sold Out' : 'Buy Now',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMedium,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
