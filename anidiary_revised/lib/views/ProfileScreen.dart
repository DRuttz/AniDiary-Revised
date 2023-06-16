// ignore_for_file: file_names, library_private_types_in_public_api, use_build_context_synchronously

import 'package:anidiary_revised/views/ConversationScreen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  List<String> _friendNames = [];
  List<String> _friendIds = [];
  bool _isAddFriendVisible = false;

  @override
  void initState() {
    super.initState();
    fetchFriends();
  }

  void fetchFriends() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final currentUserId = currentUser.uid;

      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .get();

      setState(() {
        _friendNames = friendsSnapshot.docs.map<String>((doc) {
          if (doc.data().containsKey('name')) {
            return doc['name'] as String;
          }
          return '';
        }).toList();

        _friendIds = friendsSnapshot.docs.map<String>((doc) => doc.id).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: Icon(_isAddFriendVisible ? Icons.remove : Icons.add),
            onPressed: () {
              setState(() {
                _isAddFriendVisible = !_isAddFriendVisible;
              });
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isAddFriendVisible) ...[
              Form(
                key: _formKey,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          hintText: 'Enter friend username',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a username';
                          }
                          return null;
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: addFriend,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Expanded(
              child: ListView.builder(
                itemCount: _friendNames.length,
                itemBuilder: (context, index) {
                  final friendName = _friendNames[index];
                  final friendId = _friendIds[index];

                  return GestureDetector(
                    onTap: () {
                      navigateToConversationScreen(friendName, friendId);
                    },
                    child: ListTile(
                      title: Text(friendName),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void addFriend() async {
    if (_formKey.currentState!.validate()) {
      final friendUsername = _usernameController.text.trim();

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final currentUserId = currentUser.uid;

        final friendSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: friendUsername)
            .limit(1)
            .get();

        if (friendSnapshot.docs.isNotEmpty) {
          final friendId = friendSnapshot.docs[0].id;
          final friendData = friendSnapshot.docs[0].data();

          if (friendData.containsKey('username')) {
            final friendName = friendData['username'] as String;

            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserId)
                .collection('friends')
                .doc(friendId)
                .set({
              'name': friendName,
              'timestamp': DateTime.now(),
            });

            setState(() {
              _usernameController.clear();
              _isAddFriendVisible = false;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Friend added successfully.'),
              ),
            );

            fetchFriends();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Friend name not found.'),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found.'),
            ),
          );
        }
      }
    }
  }

  void navigateToConversationScreen(String friendName, String friendId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationScreen(
          friendName: friendName,
          friendId: friendId,
        ),
      ),
    );
  }
}
