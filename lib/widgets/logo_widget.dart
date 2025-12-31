import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';

class LogoWidget extends StatelessWidget {
  final double size;
  final bool showText;

  const LogoWidget({
    super.key,
    this.size = 64,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08), // lighter shadow
                blurRadius: 8,
                spreadRadius: 0.5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.2),
            child: Image.asset(
              'assets/images/zhengzhou_logo.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Campus Pre-owned',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Buy and Sell on Campus',
                  style: TextStyle(
                    color: AppColors.textMedium,
                    fontSize: size * 0.17,
                    height: 1.3,
                  ),
                ),
                Text(
                  'Save Money • Save Planet',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: size * 0.15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    const String baseUrl =
                        'https://backend-for-app-main-hsw776.laravel.cloud';
                    const url = '$baseUrl/admin/login';
                    try {
                      await launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      // ignore: use_build_context_synchronously
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Could not open admin access page.')),
                      );
                    }
                  },
                  child: const Text('Admin Access'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
