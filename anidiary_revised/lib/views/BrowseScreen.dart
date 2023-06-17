// ignore_for_file: file_names, library_private_types_in_public_api

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'AnimeDetailsScreeen.dart';
import 'SearchScreen.dart';
import 'AnimeDetailsWithRemoveScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:anidiary_revised/recommendation_stream.dart';
import 'package:anidiary_revised/recommendation_service.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({Key? key}) : super(key: key);

  @override
  _BrowseScreenState createState() => _BrowseScreenState();
}

Future<List<dynamic>> _fetchRecommendedAnime() async {
  final recommendationService = RecommendationService();
  final recommendations = await recommendationService.fetchRecommendedAnime();
  return recommendations;
}

class _BrowseScreenState extends State<BrowseScreen> {
  List<dynamic> animeList = [];
  List<dynamic> recommendedAnimeList = [];
  List<dynamic> trendingAnimeList = [];
  List<String> watchlist = [];
  int _currentPage = 0;
  bool _isLoading = false;
  final bool _showRecommendedAnime = true;
  final ScrollController _scrollController = ScrollController();
  late StreamSubscription<bool> _streamSubscription;

  Future<void> _fetchAnimeData(int page) async {
    setState(() {
      _isLoading = true;
    });

    final response = await http.get(Uri.parse(
        'https://kitsu.io/api/edge/anime?page[limit]=20&page[offset]=$page'));

    if (response.statusCode == 200) {
      final parsedJson = json.decode(response.body);
      final animeData = parsedJson['data'];

      setState(() {
        animeList.addAll(animeData);
        _isLoading = false;
      });
    } else {
      throw Exception('Failed to load anime list');
    }
  }

  Future<void> _fetchTrendingAnime() async {
    final response =
        await http.get(Uri.parse('https://kitsu.io/api/edge/trending/anime'));

    if (response.statusCode == 200) {
      final parsedJson = json.decode(response.body);
      final animeData = parsedJson['data'];
      setState(() {
        trendingAnimeList = animeData;
      });
    } else {
      throw Exception('Failed to load trending anime');
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchAnimeData(_currentPage);
    _fetchRecommendedAnimeList();
    _fetchTrendingAnime();
    _fetchWatchlist();

    _scrollController.addListener(_scrollListener);

    _streamSubscription = RecommendationStream.stream.listen((bool _) {
      _updateRecommendedAnime();
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _currentPage += 20;
      _fetchAnimeData(_currentPage);
    }
  }

  Future<void> _fetchRecommendedAnimeList() async {
    final recommendations = await _fetchRecommendedAnime();

    final filteredRecommendations =
        await Future.wait(recommendations.map((animeData) async {
      final animeId = animeData['id'];
      final isInWatchlist = await checkIfInWatchlist(animeId);
      return isInWatchlist ? null : animeData;
    }));

    setState(() {
      recommendedAnimeList = filteredRecommendations
          .where((animeData) => animeData != null)
          .toList();
    });
  }

  Future<void> _fetchWatchlist() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final watchlistSnapshot =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = watchlistSnapshot.data();
      if (data != null && data.containsKey('watchlist')) {
        final watchlist = List<String>.from(data['watchlist']);
        setState(() {
          this.watchlist = watchlist;
        });
      }
    }
  }

  Future<bool> checkIfInWatchlist(String animeId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final uid = user.uid;
      final watchlistSnapshot = await FirebaseFirestore.instance
          .collection('watchlists')
          .doc(uid)
          .get();
      final data = watchlistSnapshot.data();
      if (data != null && data.containsKey('anime')) {
        final watchlist = List<String>.from(data['anime']);
        return watchlist.contains(animeId);
      }
    }
    return false;
  }

  void _updateRecommendedAnime() {
    _fetchRecommendedAnimeList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _streamSubscription.cancel();
    super.dispose();
  }

  Widget _buildTrendingAnimeList() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: trendingAnimeList.length,
      itemBuilder: (BuildContext context, int index) {
        final animeData = trendingAnimeList[index];
        final animeAttributes = animeData['attributes'];
        final animePoster = animeAttributes['posterImage']['small'];
        final animeTitle = animeAttributes['canonicalTitle'];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AnimeDetailsScreen(
                  animeData: animeData,
                ),
              ),
            );
          },
          child: Container(
            width: 120.0,
            margin: const EdgeInsets.only(right: 1.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      animePoster,
                      height: 150,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  animeTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecommendedAnimeList() {
    if (recommendedAnimeList.isEmpty) {
      return const SizedBox();
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: recommendedAnimeList.length,
      itemBuilder: (BuildContext context, int index) {
        final animeData = recommendedAnimeList[index];
        final animeAttributes = animeData['attributes'];
        final animeId = animeData['id'];
        final animePoster = animeAttributes['posterImage']['small'];
        final animeTitle = animeAttributes['canonicalTitle'];

        final bool isInWatchlist = watchlist.contains(animeId);

        if (isInWatchlist) {
          return const SizedBox();
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => _showRecommendedAnime && isInWatchlist
                    ? AnimeDetailsWithRemoveScreen(
                        animeData: animeData,
                      )
                    : AnimeDetailsScreen(
                        animeData: animeData,
                      ),
              ),
            );
          },
          child: Container(
            width: 120.0,
            margin: const EdgeInsets.only(right: 1.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      animePoster,
                      height: 150,
                      width: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  animeTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AnimeSearchScreen(),
            ),
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.search),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          animeList.clear();
          _currentPage = 0;
          await _fetchAnimeData(_currentPage);
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const Row(
                    children: [
                      Text(
                        'Recommended Anime',
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  Visibility(
                    visible: _showRecommendedAnime,
                    child: SizedBox(
                      height: 180.0,
                      child: _buildRecommendedAnimeList(),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  const Row(
                    children: [
                      Text(
                        'Trending Anime',
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8.0),
                  SizedBox(
                    height: 180.0,
                    child: _buildTrendingAnimeList(),
                  ),
                  const SizedBox(height: 16.0),
                  const Text(
                    'All Anime',
                    style: TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                ]),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) {
                  return _buildAnimeListItem(index);
                },
                childCount: animeList.length,
              ),
            ),
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 16.0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimeListItem(int index) {
    final animeData = animeList[index];
    final animeAttributes = animeData['attributes'];
    final animeId = animeData['id'];
    final animePoster = animeAttributes['posterImage']['medium'];
    final animeTitle = animeAttributes['canonicalTitle'];
    final animeStartDate = animeAttributes['startDate'];
    final animeEpisodeCount = animeAttributes['episodeCount'].toString();
    final animeStatus = animeAttributes['status'];
    final isInWatchlist = watchlist.contains(animeId);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => isInWatchlist
                      ? AnimeDetailsWithRemoveScreen(
                          animeData: animeData,
                        )
                      : AnimeDetailsScreen(
                          animeData: animeData,
                        ),
                ),
              );
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    animePoster,
                    width: 66.6,
                    height: 100.0,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        animeTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(animeStartDate),
                      Text('Episode count: $animeEpisodeCount'),
                      Text('Status: $animeStatus')
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(
          height: 0.25,
        ), // Add a divider to separate the list items if desired
      ],
    );
  }
}
