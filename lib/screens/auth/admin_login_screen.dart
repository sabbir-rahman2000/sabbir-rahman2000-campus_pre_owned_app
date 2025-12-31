import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Login'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            const String url =
                'https://backend-for-app-main-hsw776.laravel.cloud/admin/login';
            try {
              await launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Could not open admin access page.'),
                ),
              );
            }
          },
          child: const Text('Go to Admin Login'),
        ),
      ),
    );
  }
}
