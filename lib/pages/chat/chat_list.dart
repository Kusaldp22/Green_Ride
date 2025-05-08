import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:green_ride/pages/chat/chat_screen.dart';
import 'package:intl/intl.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.green.shade200,
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              // Implement search functionality
            },
          ),
        ],
      ),
      body: const ChatListContent(),
    );
  }
}

class ChatListContent extends StatelessWidget {
  const ChatListContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const NotLoggedInView();
    }

    // Get chat documents where current user is a participant
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }

        if (snapshot.hasError) {
          return ErrorView(error: snapshot.error.toString());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const EmptyChatView();
        }

        final userChats = snapshot.data!.docs;
        return ChatListView(userChats: userChats, currentUserId: currentUserId);
      },
    );
  }
}

class NotLoggedInView extends StatelessWidget {
  const NotLoggedInView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_circle, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Not logged in',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              // Navigate to login screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 6, 96, 199),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              Color.fromARGB(255, 6, 96, 199),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading chats...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String error;

  const ErrorView({Key? key, required this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading chats',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              error,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyChatView extends StatelessWidget {
  const EmptyChatView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No active chats',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start a new conversation by contacting a driver',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ChatListView extends StatelessWidget {
  final List<QueryDocumentSnapshot> userChats;
  final String currentUserId;

  const ChatListView({
    Key? key,
    required this.userChats,
    required this.currentUserId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Recent chats header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                'Recent Chats',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const Spacer(),
              Text(
                '${userChats.length} ${userChats.length == 1 ? 'chat' : 'chats'}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),

        // Chat list
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: userChats.length,
            itemBuilder: (context, index) {
              final chatDoc = userChats[index];
              final Map<String, dynamic> data =
                  chatDoc.data() as Map<String, dynamic>;

              // Extract chat data
              final chatId = chatDoc.id;
              final participants =
                  List<String>.from(data['participants'] ?? []);
              final otherUserId = participants.firstWhere(
                (id) => id != currentUserId,
                orElse: () => "Unknown",
              );

              // Extract message data with fallbacks for missing fields
              final lastMessage =
                  data['lastMessage'] as String? ?? 'Start a conversation';
              final lastMessageTime =
                  data['lastMessageTime'] as Timestamp? ?? Timestamp.now();
              final unreadCount =
                  data['unreadCount_$currentUserId'] as int? ?? 0;

              // Fetch other user's data
              return FutureBuilder<DataSnapshot>(
                future: FirebaseDatabase.instance
                    .ref()
                    .child('users')
                    .child(otherUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  String username = "User";
                  String? profileImage;
                  bool isOnline = false;

                  if (userSnapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }

                  if (userSnapshot.hasData && userSnapshot.data != null) {
                    final userData =
                        userSnapshot.data!.value as Map<dynamic, dynamic>?;
                    if (userData != null) {
                      username = userData['username'] ?? "User";
                      profileImage = userData['profileImage'];
                      isOnline = userData['isOnline'] ?? false;
                    }
                  }

                  return ChatListTile(
                    username: username,
                    profileImage: profileImage,
                    lastMessage: lastMessage,
                    lastMessageTime: lastMessageTime.toDate(),
                    unreadCount: unreadCount,
                    isOnline: isOnline,
                    onTap: () {
                      FirebaseFirestore.instance
                          .collection('chats')
                          .doc(chatId)
                          .update({'unreadCount_$currentUserId': 0});
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            driverId: otherUserId,
                            driverName: username,
                            driverImage: profileImage,
                            currentUserId: currentUserId,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class ChatListTile extends StatelessWidget {
  final String username;
  final String? profileImage;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final bool isOnline;
  final VoidCallback onTap;

  const ChatListTile({
    Key? key,
    required this.username,
    this.profileImage,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.isOnline,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: unreadCount > 0 ? Colors.green.shade50 : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile image with online indicator
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.green.shade200,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: profileImage != null && profileImage!.isNotEmpty
                        ? Image.network(
                            profileImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return CircleAvatar(
                                backgroundColor: Colors.green.shade100,
                                child: Text(
                                  username.isNotEmpty
                                      ? username[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    color: Colors.black54,
                                  ),
                                ),
                              );
                            },
                          )
                        : CircleAvatar(
                            backgroundColor: Colors.green.shade100,
                            child: Text(
                              username.isNotEmpty
                                  ? username[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 24,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // Message content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          username,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatMessageTime(lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: unreadCount > 0
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: unreadCount > 0
                                ? Colors.black87
                                : Colors.grey.shade600,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(255, 6, 96, 199),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
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

  String _formatMessageTime(DateTime messageTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate =
        DateTime(messageTime.year, messageTime.month, messageTime.day);

    if (messageDate == today) {
      return DateFormat('h:mm a').format(messageTime);
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(messageTime).inDays < 7) {
      return DateFormat('EEEE').format(messageTime); // Day name
    } else {
      return DateFormat('MMM d').format(messageTime); // Month and day
    }
  }
}
