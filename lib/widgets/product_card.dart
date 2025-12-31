import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/app_colors.dart';
import '../utils/models.dart';
import '../utils/messages_api.dart';
import '../screens/product/product_detail_screen.dart';

class ProductCard extends StatefulWidget {
  final Product product;

  const ProductCard({
    super.key,
    required this.product,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isWishlisted = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkWishlistStatus();
  }

  Future<void> _checkWishlistStatus() async {
    try {
      final status = await MessagesApi.checkWishlist(widget.product.id);
      if (mounted) {
        setState(() => _isWishlisted = status);
      }
    } catch (e) {
      print('DEBUG: Failed to check wishlist status: $e');
    }
  }

  void _toggleWishlist() async {
    setState(() => _isLoading = true);
    try {
      if (_isWishlisted) {
        await MessagesApi.removeFromWishlist(widget.product.id);
      } else {
        await MessagesApi.addToWishlist(widget.product.id);
      }

      if (mounted) {
        setState(() {
          _isWishlisted = !_isWishlisted;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isWishlisted ? 'Added to wishlist' : 'Removed from wishlist',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug print for testing image URL
    print('Product image URL: [32m${widget.product.image}[0m');
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                ProductDetailScreen(productId: widget.product.id),
          ),
        );
      },
      child: Container(
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
          mainAxisSize: MainAxisSize.min, // Prevents stretching
          children: [
            // Image Section - Stable aspect ratio for consistent cropping
            AspectRatio(
              aspectRatio: 1.2, // wider than square to better fit card
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: SizedBox.expand(
                      child: CachedNetworkImage(
                        imageUrl: widget.product.image ??
                            'https://via.placeholder.com/150',
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 200),
                        memCacheHeight: 800,
                        memCacheWidth: 800,
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
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Wishlist button
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: _toggleWishlist,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isWishlisted
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 16,
                          color: _isWishlisted ? Colors.red : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  // Available badge
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: widget.product.sold == 1
                            ? Colors.red
                            : AppColors.success,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.product.sold == 1 ? 'Sold Out' : 'Available',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content Section - Compact layout
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    widget.product.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textDark,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Price
                  Text(
                    '¥${widget.product.price.toInt()}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Seller and Rating
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.product.seller,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMedium,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.star,
                        size: 12,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        widget.product.rating?.toStringAsFixed(1) ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMedium,
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
