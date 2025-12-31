import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Message {
  final String id;
  final int senderId;
  final int receiverId;
  final String body;
  final String status;
  final DateTime? createdAt;
  final String? senderName;
  final String? receiverName;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.body,
    required this.status,
    this.createdAt,
    this.senderName,
    this.receiverName,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    DateTime? created;
    final createdRaw = json['created_at'] ?? json['createdAt'];
    if (createdRaw is String) {
      try {
        created = DateTime.tryParse(createdRaw);
      } catch (_) {}
    }

    int intFrom(dynamic raw) {
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    final sender = json['sender'] as Map<String, dynamic>?;
    final receiver = json['receiver'] as Map<String, dynamic>?;

    return Message(
      id: json['id']?.toString() ?? '',
      senderId: intFrom(json['sender_id'] ?? json['senderId']),
      receiverId: intFrom(json['receiver_id'] ?? json['receiverId']),
      body: (json['body'] ?? json['text'] ?? '').toString(),
      status: (json['status'] ?? 'sent').toString(),
      createdAt: created,
      senderName: sender != null ? sender['name'] as String? : null,
      receiverName: receiver != null ? receiver['name'] as String? : null,
    );
  }
}

class MessagesApi {
  static const String _baseUrl =
      'https://backend-for-app-main-hsw776.laravel.cloud/api';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<List<Message>> fetchMessages(int participantId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_baseUrl/messages?participant_id=$participantId');

    final response = await http.get(uri, headers: headers);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch messages');
    }

    final decoded = jsonDecode(response.body);
    final data = decoded['data'] ?? decoded;
    if (data is List) {
      return data.map<Message>((e) => Message.fromJson(e)).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map<Message>((e) => Message.fromJson(e))
          .toList();
    }
    return [];
  }

  // Fetch all messages for the authenticated user (no participant filter)
  static Future<List<Message>> fetchAllMessages() async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_baseUrl/messages');

    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch messages');
    }

    final decoded = jsonDecode(response.body);
    final data = decoded['data'] ?? decoded;
    if (data is List) {
      return data.map<Message>((e) => Message.fromJson(e)).toList();
    }
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map<Message>((e) => Message.fromJson(e))
          .toList();
    }
    return [];
  }

  // Get current authenticated user's id (used to determine conversation counterpart)
  static Future<int> getMyUserId() async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_baseUrl/auth/me');
    final response = await http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load profile');
    }
    final decoded = jsonDecode(response.body);
    final user = decoded['data']?['user'] ?? decoded['user'];
    final rawId = user?['id'];
    if (rawId is int) return rawId;
    return int.tryParse(rawId?.toString() ?? '') ?? 0;
  }

  static Future<Message> sendMessage({
    required int receiverId,
    required String body,
    String status = 'sent',
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_baseUrl/messages');
    final payload = {
      'receiver_id': receiverId,
      'body': body,
      'status': status,
    };

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to send message');
    }

    final decoded = jsonDecode(response.body);
    final data = decoded['data'] ?? decoded;
    return Message.fromJson(data as Map<String, dynamic>);
  }

  // Wishlist operations
  static Future<bool> checkWishlist(int productId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_baseUrl/wishlist/check/$productId');

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded['in_wishlist'] == true;
    }
    return false;
  }

  static Future<void> addToWishlist(int productId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_baseUrl/wishlist');
    final payload = {'product_id': productId};

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception('Failed to add to wishlist');
    }
  }

  static Future<void> removeFromWishlist(int productId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_baseUrl/wishlist/$productId');

    final response = await http.delete(uri, headers: headers);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to remove from wishlist');
    }
  }

  // Delete product
  static Future<Map<String, dynamic>> deleteProduct(int productId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_baseUrl/products/$productId/delete');

    final response = await http.delete(uri, headers: headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded;
    } else if (response.statusCode == 403) {
      throw Exception('Unauthorized. You can only delete your own products');
    } else if (response.statusCode == 404) {
      throw Exception('Product not found');
    } else {
      throw Exception('Failed to delete product');
    }
  }

  // Mark product as sold
  static Future<Map<String, dynamic>> markProductAsSold(
      int productId, int? buyerUserId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('$_baseUrl/sells');

    final payload = {
      'product_id': productId,
      if (buyerUserId != null) 'buyer_user_id': buyerUserId,
    };

    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      return decoded['data'] ?? decoded;
    } else {
      final decoded = jsonDecode(response.body);
      final message = decoded['message'] ?? 'Failed to mark product as sold';
      throw Exception(message);
    }
  }
}
