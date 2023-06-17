// ignore_for_file: file_names, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ConversationScreen extends StatefulWidget {
  final String friendName;
  final String friendId;

  const ConversationScreen(
      {super.key, required this.friendName, required this.friendId});

  @override
  _ConversationScreenState createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && widget.friendId.isNotEmpty) {
    } else {
      throw Exception('Invalid friendId or currentUser is null');
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final String conversationId =
        _generateConversationId(currentUser!.uid, widget.friendId);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.friendName),
      ),
      body: Column(
        children: [
          Expanded(
            child: Align(
                alignment: Alignment.bottomCenter,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('conversations')
                      .doc(conversationId)
                      .collection('messages')
                      .orderBy('timestamp')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircularProgressIndicator();
                    }

                    final messages = snapshot.data?.docs ?? [];

                    return ListView.builder(
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index].data();

                        final messageText = message['message'] ?? '';
                        final timestamp = message['timestamp'] as Timestamp?;
                        final senderId = message['senderId'] ?? '';

                        final formattedTime = timestamp != null
                            ? _formatTimestamp(timestamp)
                            : '';

                        final isMe = currentUser.uid == senderId;

                        return MessageBubble(
                          message: messageText,
                          formattedTime: formattedTime,
                          isMe: isMe,
                        );
                      },
                    );
                  },
                )),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: () {
                    sendMessage();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void sendMessage() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null && widget.friendId.isNotEmpty) {
      final senderId = currentUser.uid;
      final messageText = _messageController.text.trim();

      if (messageText.isNotEmpty) {
        final conversationId =
            _generateConversationId(currentUser.uid, widget.friendId);

        FirebaseFirestore.instance
            .collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .add({
          'senderId': senderId,
          'message': messageText,
          'timestamp': FieldValue.serverTimestamp(),
        });

        _messageController.clear();
      }
    }
  }

  String _generateConversationId(String currentUserId, String friendId) {
    final List<String> ids = [currentUserId, friendId];
    ids.sort(); // Sort the IDs to ensure consistent conversation ID generation
    return ids.join('_');
  }

  String _formatTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final timeFormat = DateFormat('HH:mm');
    return timeFormat.format(dateTime);
  }
}

class MessageBubble extends StatelessWidget {
  final String message;
  final String formattedTime;
  final bool isMe;

  const MessageBubble({
    super.key,
    required this.message,
    required this.formattedTime,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          color: isMe ? Colors.blue : Colors.grey.shade300,
          borderRadius: BorderRadius.only(
            topLeft:
                isMe ? const Radius.circular(12) : const Radius.circular(0),
            topRight:
                isMe ? const Radius.circular(0) : const Radius.circular(12),
            bottomLeft: const Radius.circular(12),
            bottomRight: const Radius.circular(12),
          ),
        ),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              formattedTime,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isMe ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: TextStyle(
                fontSize: 18,
                color: isMe ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
