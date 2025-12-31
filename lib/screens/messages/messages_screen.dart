import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/app_colors.dart';
import '../../widgets/bottom_nav.dart';
import '../../utils/messages_api.dart';
import '../auth/login_screen.dart';
import '../product/product_detail_screen.dart';

class MessagesScreen extends StatefulWidget {
  final int? initialReceiverId;
  final int? initialProductId;
  final String? initialReceiverName;
  const MessagesScreen(
      {super.key,
      this.initialReceiverId,
      this.initialProductId,
      this.initialReceiverName});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _participantController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isSending = false;
  bool _requiresLogin = false;
  List<Message> _messages = [];
  int? _activeReceiverId;
  String? _activeReceiverName;
  int? _myUserId;
  List<_ConversationSummary> _conversations = [];

  @override
  void dispose() {
    _participantController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Load my user id for conversation grouping, then load conversations
    if (widget.initialReceiverId != null) {
      _participantController.text = widget.initialReceiverId!.toString();
      _activeReceiverId = widget.initialReceiverId;
      _activeReceiverName = widget.initialReceiverName;
      Future.microtask(_loadConversation);
    } else {
      // Load user id first, then show all conversations
      Future.microtask(_initConversationList);
    }
  }

  Future<void> _initConversationList() async {
    try {
      final id = await MessagesApi.getMyUserId();
      if (!mounted) return;
      setState(() => _myUserId = id);
      if (!mounted) return;
      await _loadConversations();
    } catch (e) {
      print('DEBUG: Error loading user ID: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMyUser() async {
    try {
      final id = await MessagesApi.getMyUserId();
      if (!mounted) return;
      setState(() => _myUserId = id);
    } catch (e) {
      print('DEBUG: Error loading user ID: $e');
    }
  }

  Future<void> _showLoadDialog() async {
    final controller = TextEditingController(text: _participantController.text);
    final id = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Load conversation'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Receiver ID',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = int.tryParse(controller.text.trim());
                Navigator.of(context).pop(val);
              },
              child: const Text('Load'),
            ),
          ],
        );
      },
    );

    if (id != null) {
      _participantController.text = id.toString();
      _activeReceiverId = id;
      _activeReceiverName = null;
      await _loadConversation();
    }
  }

  Future<void> _loadConversation() async {
    if (_activeReceiverId == null) {
      final raw = _participantController.text.trim();
      final id = int.tryParse(raw);
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid receiver ID'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      _activeReceiverId = id;
    }

    setState(() => _isLoading = true);
    try {
      final msgs = await MessagesApi.fetchMessages(_activeReceiverId!);
      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _isLoading = false;
        _requiresLogin = false;
      });
      // Do not auto-scroll on initial load to avoid jumping
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = e.toString().toLowerCase().contains('not authenticated')
          ? 'Please log in to view messages'
          : 'Failed to load messages';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
      if (e.toString().toLowerCase().contains('not authenticated')) {
        setState(() => _requiresLogin = true);
      }
    }
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final msgs = await MessagesApi.fetchAllMessages();
      print('DEBUG: Fetched ${msgs.length} messages');
      final myId = _myUserId;
      print('DEBUG: My user ID = $myId');

      // Group by counterpart id and compute last message
      final Map<int, _ConversationSummary> map = {};
      for (final m in msgs) {
        print(
            'DEBUG: Message - sender=${m.senderId}, receiver=${m.receiverId}, body=${m.body}');
        final counterpartId =
            (myId != null && m.senderId == myId) ? m.receiverId : m.senderId;
        final counterpartName = (myId != null && m.senderId == myId)
            ? (m.receiverName ?? 'User $counterpartId')
            : (m.senderName ?? 'User $counterpartId');
        final created = m.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

        final existing = map[counterpartId];
        // Preview text: handle buy requests
        String preview = m.body;
        if (m.body.startsWith('BUY_REQUEST:')) {
          try {
            final jsonPart = m.body.substring('BUY_REQUEST:'.length).trim();
            final data = jsonDecode(jsonPart) as Map<String, dynamic>;
            final t = (data['title'] ?? '') as String;
            preview = t.isNotEmpty ? 'Buy request: $t' : 'Buy request';
          } catch (_) {}
        }

        if (existing == null || created.isAfter(existing.lastTime)) {
          map[counterpartId] = _ConversationSummary(
            participantId: counterpartId,
            participantName: counterpartName,
            lastText: preview,
            lastTime: created,
          );
        }
      }

      final list = map.values.toList()
        ..sort((a, b) => b.lastTime.compareTo(a.lastTime));

      print('DEBUG: Grouped into ${list.length} conversations');

      if (!mounted) return;
      setState(() {
        _conversations = list;
        _isLoading = false;
        _requiresLogin = false;
      });
    } catch (e) {
      print('DEBUG: Error loading conversations: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      final msg = e.toString().toLowerCase().contains('not authenticated')
          ? 'Please log in to view messages'
          : 'Failed to load conversations';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
      if (e.toString().toLowerCase().contains('not authenticated')) {
        setState(() => _requiresLogin = true);
      }
    }
  }

  void _scrollToBottom() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Type a message first'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_activeReceiverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No receiver selected'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      final msg = await MessagesApi.sendMessage(
        receiverId: _activeReceiverId!,
        body: text,
        status: 'sent',
      );

      if (!mounted) return;
      setState(() {
        _messages = [..._messages, msg];
        _isSending = false;
        _requiresLogin = false;
      });
      _scrollToBottom();
      _messageController.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      final msg = e.toString().toLowerCase().contains('not authenticated')
          ? 'Please log in to send messages'
          : 'Failed to send message';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
      if (e.toString().toLowerCase().contains('not authenticated')) {
        setState(() => _requiresLogin = true);
      }
    }
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final isKeyboardOpen = viewInsets.bottom > 0;
    final sortedMessages = [..._messages]..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _activeReceiverId != null
                  ? (_activeReceiverName != null
                      ? 'Chat with $_activeReceiverName'
                      : 'Chat with User $_activeReceiverId')
                  : 'Messages',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (_activeReceiverId != null)
              Text(
                'Tap search to change',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        leading: _activeReceiverId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.primary),
                onPressed: () {
                  setState(() {
                    _activeReceiverId = null;
                    _activeReceiverName = null;
                    _messages = [];
                  });
                  _loadConversations();
                },
                tooltip: 'Back to conversations',
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _isLoading
                ? null
                : () {
                    if (_activeReceiverId == null) {
                      _loadConversations();
                    } else {
                      _loadConversation();
                    }
                  },
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.primary),
            onPressed: _isLoading ? null : _showLoadDialog,
            tooltip: 'Load conversation',
          ),
        ],
      ),
      body: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: SafeArea(
          bottom: true,
          child: Column(
            children: [
              if (_requiresLogin)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    border: Border(
                      bottom:
                          BorderSide(color: AppColors.warning.withOpacity(0.3)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Please log in to view and send messages.',
                          style: TextStyle(
                              color: AppColors.textDark, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                          );
                        },
                        child: const Text('Log in'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _activeReceiverId == null
                        ? (_conversations.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Container(
                                    padding: const EdgeInsets.all(32),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                              Icons.message_outlined,
                                              size: 56,
                                              color: AppColors.primary),
                                        ),
                                        const SizedBox(height: 20),
                                        const Text(
                                          'No conversation yet',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Start messaging from a product',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _conversations.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final c = _conversations[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: AppColors.primary,
                                      child: Text(
                                        c.participantName.isNotEmpty
                                            ? c.participantName[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                            color: Colors.white),
                                      ),
                                    ),
                                    title: Text(
                                      c.participantName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      c.lastText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Text(_timeAgo(c.lastTime)),
                                    onTap: () {
                                      setState(() {
                                        _activeReceiverId = c.participantId;
                                        _activeReceiverName = c.participantName;
                                        _messages = [];
                                      });
                                      _loadConversation();
                                    },
                                  );
                                },
                              ))
                        : sortedMessages.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.mail_outline,
                                        size: 64, color: Colors.grey[300]),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No messages yet',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 12),
                                controller: _scrollController,
                                itemCount: sortedMessages.length,
                                itemBuilder: (context, index) {
                                  final m = sortedMessages[index];
                                  final isOutgoing =
                                      m.senderId != _activeReceiverId;

                                  return _buildMessageBubble(m, isOutgoing);
                                },
                              ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 12,
                ),
                child: _activeReceiverId == null
                    ? const SizedBox.shrink()
                    : _buildComposer(),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar:
          isKeyboardOpen ? null : const BottomNav(currentIndex: 3),
    );
  }

  Widget _buildMessageBubble(Message m, bool isOutgoing) {
    // Detect buy request and render a product preview bubble
    if (m.body.startsWith('BUY_REQUEST:')) {
      final jsonPart = m.body.substring('BUY_REQUEST:'.length).trim();
      try {
        final data = jsonDecode(jsonPart) as Map<String, dynamic>;
        return _buildBuyRequestBubble(data, isOutgoing);
      } catch (_) {
        // Fall back to normal text if parsing fails
      }
    }
    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment:
              isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isOutgoing
                    ? AppColors.primary
                    : Colors.grey.withOpacity(0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                m.body,
                style: TextStyle(
                  fontSize: 15,
                  color: isOutgoing ? Colors.white : AppColors.textDark,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _timeAgo(m.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuyRequestBubble(Map<String, dynamic> data, bool isOutgoing) {
    final title = (data['title'] ?? '') as String;
    final price = data['price'];
    final imageUrl = data['image'] as String?;
    final note = (data['note'] ?? 'I want to buy this product.') as String;
    final productId = data['product_id'] as int?;

    final bubbleColor =
        isOutgoing ? AppColors.primary.withOpacity(0.95) : Colors.white;
    final titleColor = isOutgoing ? Colors.white : AppColors.textDark;
    final priceColor = isOutgoing ? Colors.white : AppColors.primaryDark;
    final noteColor = isOutgoing ? Colors.white : AppColors.textDark;

    final bubbleContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageUrl != null && imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
            ),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                height: 160,
                color: Colors.black.withOpacity(0.06),
              ),
              errorWidget: (context, url, error) => Container(
                height: 160,
                color: Colors.grey.withOpacity(0.2),
                alignment: Alignment.center,
                child:
                    const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isNotEmpty ? title : 'Product',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 6),
              if (price != null)
                Text(
                  '¥${(price is num) ? price.toStringAsFixed(0) : price.toString()}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: priceColor,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                note,
                style: TextStyle(
                  fontSize: 14,
                  color: noteColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: productId != null
            ? () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        ProductDetailScreen(productId: productId),
                  ),
                );
              }
            : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          width: MediaQuery.of(context).size.width * 0.75,
          child: bubbleContent,
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final disabled = _isLoading || _isSending || _requiresLogin;
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _messageController,
              enabled: !disabled,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.send, color: Colors.white, size: 20),
            onPressed: disabled ? null : _sendMessage,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class _ConversationSummary {
  final int participantId;
  final String participantName;
  final String lastText;
  final DateTime lastTime;
  _ConversationSummary({
    required this.participantId,
    required this.participantName,
    required this.lastText,
    required this.lastTime,
  });
}
