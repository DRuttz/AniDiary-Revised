import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<List<String>> getWatchlist(String userId) async {
    try {
      DocumentSnapshot<Map<String, dynamic>> document = await FirebaseFirestore
          .instance
          .collection('watchlists')
          .doc(userId)
          .get();

      if (document.exists) {
        // Watchlist document exists, retrieve the watchlist
        Map<String, dynamic> data = document.data()!;
        if (data.containsKey('anime') && data['anime'] is List<dynamic>) {
          return List<String>.from(data['anime']);
        }
      }

      // Invalid or missing watchlist, return an empty list
      return [];
    } catch (e) {
      // Handle any potential exceptions and return an empty list
      return [];
    }
  }

  Stream<List<String>> getWatchlistStream(String userId) {
    return FirebaseFirestore.instance
        .collection('watchlists')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        final watchlist = data['anime'] as List<dynamic>;
        return watchlist.cast<String>();
      } else {
        // Return an empty list if the watchlist document doesn't exist
        return [];
      }
    });
  }

  Future<void> createWatchlist(String userId, List<String> animeList) async {
    try {
      await FirebaseFirestore.instance
          .collection('watchlists')
          .doc(userId)
          .set({'anime': animeList});
    } catch (e) {
      // Handle any potential exceptions
    }
  }

  Future<String?> registration({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = _auth.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'username': username});
      }
      return 'Success';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        return 'The account already exists for that email.';
      } else {
        return e.message;
      }
    } catch (e) {
      return e.toString();
    }
  }

  Future<List<Map<String, dynamic>>> fetchWatchlist() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userId = user.uid;
      final snapshot = await FirebaseFirestore.instance
          .collection('watchlist')
          .doc(userId)
          .get();

      if (snapshot.exists) {
        final watchlistData = snapshot.data() as Map<String, dynamic>;
        final watchlist = watchlistData['anime'] as List<dynamic>;
        return List<Map<String, dynamic>>.from(watchlist);
      }
    }

    return [];
  }

  Future<String?> getUsername() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return userData.data()?['username'];
    }
    return null;
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return 'Success';
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        return 'Wrong password provided for that user.';
      } else {
        return e.message;
      }
    } catch (e) {
      return e.toString();
    }
  }

  String? getCurrentUserId() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  Future<void> removeAnimeFromWatchlist(String userId, String animeId) async {
    final watchlistRef =
        FirebaseFirestore.instance.collection('watchlists').doc(userId);

    final document = await watchlistRef.get();
    if (document.exists) {
      final watchlist = document.data();
      final List<String> animeList =
          (watchlist?['anime'] as List<dynamic>).cast<String>();

      animeList.remove(animeId); // Remove the anime from the watchlist

      await watchlistRef.update({'anime': animeList});
    }
  }

  Future<void> addAnimeToWatchlist(String userId, String animeId) async {
    final watchlistRef =
        FirebaseFirestore.instance.collection('watchlists').doc(userId);

    // Get the current watchlist data
    final document = await watchlistRef.get();
    if (document.exists) {
      // Watchlist document exists, update the watchlist
      final watchlist = document.data();
      final List<String> animeList = (watchlist?['anime'] as List<dynamic>)
          .cast<String>(); // Convert the dynamic list to a list of strings

      // Check if the anime is already in the watchlist
      if (!animeList.contains(animeId)) {
        animeList.add(animeId); // Add the anime to the watchlist
      }

      // Update the watchlist document with the updated anime list
      await watchlistRef.update({'anime': animeList});
    } else {
      // Watchlist document doesn't exist, create a new watchlist
      await createWatchlist(userId, [animeId]);
    }
  }
}
