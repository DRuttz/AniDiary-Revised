// ignore_for_file: file_names, library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:anidiary_revised/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'AnimeDetailsScreeen.dart';

class AnimeDetailsWithRemoveScreen extends StatefulWidget {
  final Map<String, dynamic> animeData;

  const AnimeDetailsWithRemoveScreen({Key? key, required this.animeData})
      : super(key: key);

  @override
  _AnimeDetailsWithRemoveScreenState createState() =>
      _AnimeDetailsWithRemoveScreenState();
}

class _AnimeDetailsWithRemoveScreenState
    extends State<AnimeDetailsWithRemoveScreen> {
  double _rating = 0.0;
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, String>> _comments = [];

  @override
  void initState() {
    super.initState();
    fetchComments();
    fetchRating();
  }

  void fetchComments() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('anime')
        .doc(widget.animeData['id'])
        .collection('comments')
        .get();

    setState(() {
      _comments = snapshot.docs.map((doc) {
        final comment = doc.data()['comment'] as String?;
        final commenterName = doc.data()['commenterName'] as String?;
        return {
          'comment': comment ?? '',
          'commenterName': commenterName ?? '',
        };
      }).toList();
    });
  }

  void fetchRating() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final ratingSnapshot = await FirebaseFirestore.instance
          .collection('anime')
          .doc(widget.animeData['id'])
          .collection('ratings')
          .doc(userId)
          .get();

      final rating = ratingSnapshot.data()?['rating'] as double?;
      if (rating != null) {
        setState(() {
          _rating = rating;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final attributes = widget.animeData['attributes'];

    return Scaffold(
      appBar: AppBar(
        title: Text(attributes['canonicalTitle']),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Display anime poster
              Image.network(attributes['posterImage']['original']),
              const SizedBox(height: 16),
              const Text(
                'Synopsis',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              // Display anime synopsis
              Text(attributes['synopsis']),
              const SizedBox(height: 16),
              // Display episode count
              Text(
                'Episode Count: ${attributes['episodeCount']}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              // Remove from watchlist button
              ElevatedButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final userId = user.uid;
                    final animeId = widget.animeData['id'] as String;
                    await AuthService()
                        .removeAnimeFromWatchlist(userId, animeId);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Anime removed from watchlist.'),
                      ),
                    );
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AnimeDetailsScreen(
                          animeData: widget.animeData,
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Remove from Watchlist'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Rating',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Display average rating as decimal number
              Text('Average Rating: ${_rating.toStringAsFixed(1)}'),
              const SizedBox(height: 8),
              // Rating system
              Slider(
                value: _rating,
                min: 0,
                max: 10,
                onChanged: (value) {
                  setState(() {
                    _rating = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              // Add rating button
              ElevatedButton(
                onPressed: () {
                  addRating();
                },
                child: const Text('Add Rating'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Comments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Comments section
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index]['comment'];
                  final commenterName = _comments[index]['commenterName'];

                  return ListTile(
                    title: Text(comment ?? ''),
                    subtitle: Text('By: $commenterName'),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Add comment text field
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: 'Add a comment',
                ),
              ),
              const SizedBox(height: 8),
              // Add comment button
              ElevatedButton(
                onPressed: () {
                  addComment();
                },
                child: const Text('Add Comment'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> addComment() async {
    final comment = _commentController.text;
    final commenterName = await AuthService().getUsername() ??
        "Unknown User"; // Provide a default value for the commenterName

    // Save comment and commenter's name to Firebase Firestore for the specific anime
    await FirebaseFirestore.instance
        .collection('anime')
        .doc(widget.animeData['id'])
        .collection('comments')
        .add({
      'comment': comment,
      'commenterName': commenterName,
    });

    setState(() {
      _comments.add({'comment': comment, 'commenterName': commenterName});
      _commentController.clear();
    });
  }

  Future<void> addRating() async {
    final rating = _rating;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      // Save the rating to Firebase Firestore for the specific anime
      await FirebaseFirestore.instance
          .collection('anime')
          .doc(widget.animeData['id'])
          .collection('ratings')
          .doc(userId)
          .set({
        'rating': rating,
      });

      // After saving the rating, you can fetch all the ratings and calculate the average rating
      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('anime')
          .doc(widget.animeData['id'])
          .collection('ratings')
          .get();

      if (ratingsSnapshot.docs.isNotEmpty) {
        final ratings = ratingsSnapshot.docs
            .map<double>((doc) => (doc.data()['rating'] as double?) ?? 0.0)
            .toList();

        final sum = ratings.fold(0.0, (previous, rating) => previous + rating);
        final average = sum / ratings.length;

        // Update the average rating in the UI
        setState(() {
          _rating = average;
        });
      }
    }
  }
}
