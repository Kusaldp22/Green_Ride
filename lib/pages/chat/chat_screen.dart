import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  final String driverId;
  final String driverName;
  final String? driverImage;
  final String currentUserId;

  const ChatScreen({
    Key? key,
    required this.driverId,
    required this.driverName,
    this.driverImage,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  void _loadMessages() {
    try {
      FirebaseFirestore.instance
          .collection('chats')
          .doc(_getChatId())
          .collection('messages')
          .orderBy('timestamp')
          .snapshots()
          .listen((snapshot) {
        final loadedMessages = snapshot.docs
            .map((doc) {
              final data = doc.data();
              if (data.containsKey('senderId') &&
                  data.containsKey('text') &&
                  data.containsKey('timestamp')) {
                return ChatMessage(
                  senderId: data['senderId'] ?? '',
                  text: data['text'] ?? '',
                  timestamp: (data['timestamp'] as Timestamp?)?.toDate() ??
                      DateTime.now(),
                  isMe: data['senderId'] == widget.currentUserId,
                );
              } else {
                return null;
              }
            })
            .whereType<ChatMessage>()
            .toList();

        if (mounted) {
          setState(() => _messages = loadedMessages);
          _scrollToBottom();
        }
      });
    } catch (e, stackTrace) {
      debugPrint("❌ Error loading messages: $e");
      debugPrint("🧵 StackTrace: $stackTrace");
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _sendMessage() async {
    try {
      final text = _messageController.text.trim();
      if (text.isEmpty) return;

      final newMessage = ChatMessage(
        senderId: widget.currentUserId,
        text: text,
        timestamp: DateTime.now(),
        isMe: true,
      );

      setState(() {
        _messages.add(newMessage);
      });

      _messageController.clear();
      _scrollToBottom();

      final chatId = _getChatId();
      final chatDoc =
          FirebaseFirestore.instance.collection('chats').doc(chatId);

      await chatDoc.set({
        'participants': [widget.currentUserId, widget.driverId],
        'lastMessageTime': Timestamp.fromDate(newMessage.timestamp),
        'lastMessage': newMessage.text,
      }, SetOptions(merge: true));

      await chatDoc.collection('messages').add({
        'senderId': newMessage.senderId,
        'text': newMessage.text,
        'timestamp': Timestamp.fromDate(newMessage.timestamp),
      });
    } catch (e, stackTrace) {
      debugPrint("❌ Error sending message: $e");
      debugPrint("🧵 StackTrace: $stackTrace");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    }
  }

  String _getChatId() {
    final ids = [widget.currentUserId, widget.driverId]..sort();
    return ids.join('_');
  }

  void _scrollToBottom() {
    try {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      debugPrint("⚠️ Scroll error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green.shade200,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color.fromARGB(255, 6, 96, 199),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.driverImage != null
                  ? NetworkImage(widget.driverImage!)
                  : null,
              child: widget.driverImage == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
              radius: 20,
            ),
            const SizedBox(width: 10),
            Text(
              widget.driverName,
              style: const TextStyle(color: Colors.black),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isMe
              ? const Color.fromARGB(255, 6, 96, 199)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isMe ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: message.isMe ? Colors.white70 : Colors.black54,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    try {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color.fromARGB(255, 6, 96, 199),
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    try {
      _messageController.dispose();
      _scrollController.dispose();
    } catch (e) {
      debugPrint("❌ Dispose error: $e");
    }
    super.dispose();
  }
}

class ChatMessage {
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isMe;

  ChatMessage({
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isMe,
  });
}
