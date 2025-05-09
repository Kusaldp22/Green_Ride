import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Chat extends StatefulWidget {
  final String passengerId;
  final String passengerName;
  final String? passengerImage;
  final String currentUserId; // The logged-in user (driver or passenger)

  const Chat({
    super.key,
    required this.passengerId,
    required this.passengerName,
    this.passengerImage,
    required this.currentUserId,
  });

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  late final String _chatId;

  @override
  void initState() {
    super.initState();
    try {
      _chatId = _getChatId();
      _listenForMessages();
    } catch (e, stackTrace) {
      debugPrint("Error in initState: $e");
      debugPrint("StackTrace: $stackTrace");
    }
  }

  String _getChatId() {
    final ids = [widget.currentUserId, widget.passengerId]..sort();
    return ids.join('_');
  }

  void _listenForMessages() {
    try {
      FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .orderBy('timestamp')
          .snapshots()
          .listen((snapshot) {
        try {
          final messages = snapshot.docs.map((doc) {
            final data = doc.data();
            return ChatMessage(
              senderId: data['senderId'] ?? '',
              text: data['text'] ?? '',
              timestamp:
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
              isMe: data['senderId'] == widget.currentUserId,
            );
          }).toList();

          if (mounted) {
            setState(() => _messages = messages);
            _scrollToBottom();
          }
        } catch (e, stackTrace) {
          debugPrint("Error processing snapshot data: $e");
          debugPrint("StackTrace: $stackTrace");
        }
      });
    } catch (e, stackTrace) {
      debugPrint("Error setting up listener: $e");
      debugPrint("StackTrace: $stackTrace");
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || widget.currentUserId.isEmpty) return;

    final message = {
      'senderId': widget.currentUserId,
      'text': text,
      'timestamp': Timestamp.now(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add(message);
      _messageController.clear();
      _scrollToBottom();
    } catch (e, stackTrace) {
      debugPrint("Error sending message: $e");
      debugPrint("StackTrace: $stackTrace");
    }
  }

  void _scrollToBottom() {
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 100,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e, stackTrace) {
      debugPrint("Error scrolling: $e");
      debugPrint("StackTrace: $stackTrace");
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
              backgroundImage: widget.passengerImage != null
                  ? NetworkImage(widget.passengerImage!)
                  : null,
              child: widget.passengerImage == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
              radius: 20,
            ),
            const SizedBox(width: 10),
            Text(
              widget.passengerName,
              style: const TextStyle(color: Colors.black),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text("No messages yet"))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      try {
                        return _buildMessageBubble(_messages[index]);
                      } catch (e) {
                        debugPrint("Error building message bubble: $e");
                        return const SizedBox.shrink();
                      }
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

  String _formatTime(DateTime time) {
    try {
      final hour = time.hour > 12 ? time.hour - 12 : time.hour;
      final ampm = time.hour >= 12 ? 'PM' : 'AM';
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute $ampm';
    } catch (e) {
      debugPrint("Error formatting time: $e");
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color.fromARGB(255, 6, 96, 199),
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
      debugPrint("Error during dispose: $e");
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
