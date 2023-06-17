import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecommendationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<dynamic>> get recommendedAnimeStream {
    return FirebaseFirestore.instance
        .collection('watchlist')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<List<String>> fetchWatchlist() async {
    try {
      String userId = _auth.currentUser!.uid;
      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('watchlists')
          .doc(userId)
          .get();

      if (snapshot.exists) {
        Map<String, dynamic>? data = snapshot.data() as Map<String, dynamic>?;

        if (data != null && data.containsKey('anime')) {
          List<String> watchlistData =
              List<String>.from(data['anime'] as List<dynamic>);
          return watchlistData;
        } else {
          return [];
        }
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> fetchAnimeDetails(List<String> watchlist) async {
    final List<Future<dynamic>> futures = [];
    for (final animeId in watchlist) {
      final response =
          await http.get(Uri.parse('https://kitsu.io/api/edge/anime/$animeId'));
      if (response.statusCode == 200) {
        final parsedJson = json.decode(response.body);
        final animeData = parsedJson['data'];
        futures.add(Future.value(animeData));
      }
    }
    return Future.wait(futures);
  }

  Future<List<List<dynamic>>> fetchSimilarAnime(
      List<dynamic> animeDetails) async {
    final List<Future<List<dynamic>>> futures = [];
    for (final anime in animeDetails) {
      final animeId = anime['id'];
      final response = await http
          .get(Uri.parse('https://kitsu.io/api/edge/anime/$animeId/genres'));
      if (response.statusCode == 200) {
        final parsedJson = json.decode(response.body);
        final genres = parsedJson['data']
            .map((genre) => genre['attributes']['name'])
            .toList();
        final queryParameters = Uri.encodeQueryComponent(genres.join(','));
        final searchUrl =
            'https://kitsu.io/api/edge/anime?filter[genres]=$queryParameters';
        final similarAnimeResponse = await http.get(Uri.parse(searchUrl));
        if (similarAnimeResponse.statusCode == 200) {
          final similarAnimeData =
              json.decode(similarAnimeResponse.body)['data'];
          futures.add(Future.value(similarAnimeData));
        } else {}
      } else {}
    }
    return Future.wait(futures);
  }

  List<dynamic> recommendedAnimeList = [];

  Future<List<void>> fetchRecommendedAnime() async {
    final watchlist = await fetchWatchlist();

    final animeDetails = await fetchAnimeDetails(watchlist);

    final similarAnime = await fetchSimilarAnime(animeDetails);

    // Flatten the similar anime list
    final List<dynamic> flattenedSimilarAnime = [];
    for (final animeList in similarAnime) {
      flattenedSimilarAnime.addAll(animeList);
    }

    // Remove duplicates from the flattened list
    final Set<String> uniqueAnimeIds = {};
    final List<dynamic> filteredSimilarAnime = [];
    for (final anime in flattenedSimilarAnime) {
      final animeId = anime['id'];
      if (!uniqueAnimeIds.contains(animeId)) {
        uniqueAnimeIds.add(animeId);
        filteredSimilarAnime.add(anime);
      }
    }

    // Sort the anime by popularity
    filteredSimilarAnime.sort((a, b) {
      final popularityA = a['attributes']['popularity'] ?? 0;
      final popularityB = b['attributes']['popularity'] ?? 0;
      return popularityB.compareTo(popularityA);
    });

    // Return the top 20 recommendations or all if fewer than 20
    recommendedAnimeList = filteredSimilarAnime.sublist(
        0, filteredSimilarAnime.length < 20 ? filteredSimilarAnime.length : 20);

    return recommendedAnimeList;
  }
}
