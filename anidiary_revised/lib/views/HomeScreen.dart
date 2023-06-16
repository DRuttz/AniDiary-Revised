import 'package:anidiary_revised/views/AnimeDetailsWithRemoveScreen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:anidiary_revised/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Stream<List<String>>? watchlistStream;
  List<Map<String, dynamic>> animeDetails = [];
  List<bool> expansionStateList = []; // Track expansion state for each anime
  int expandedIndex = -1; // Track the currently expanded anime index

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userId = user.uid;
      watchlistStream = AuthService().getWatchlistStream(userId);
    }
  }

  Future<void> fetchAnimeDetails(List<String> watchlist) async {
    List<Map<String, dynamic>> details = [];
    List<bool> expansionState = [];
    for (String animeId in watchlist) {
      final animeDetail = await getAnimeDetails(animeId);
      if (animeDetail != null) {
        details.add(animeDetail);
        expansionState
            .add(false); // Initialize expansion state as false for each anime
      }
    }
    // Collapse the expanded anime if it is removed from the watchlist
    if (expandedIndex >= details.length) {
      expandedIndex = -1;
    }

    updateAnimeDetails(details, expansionState);
  }

  Future<Map<String, dynamic>> getAnimeDetails(String animeId) async {
    try {
      final response = await http.get(
        Uri.parse('https://kitsu.io/api/edge/anime/$animeId'),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final attributes = responseData['data']['attributes'];

        return {
          'id': animeId,
          'attributes': attributes,
        };
      } else {
        return {};
      }
    } catch (e) {
      return {};
    }
  }

  Future<void> saveEpisodesWatched(String animeId, int episodesWatched) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userId = user.uid;
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('watchlist')
          .doc(animeId);
      await docRef.set({'episodesWatched': episodesWatched});
    }
  }

  void _showEpisodeTextFieldDialog(
      String animeId, int episodesWatched, int totalEpisodes) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        int newValue = episodesWatched;
        return AlertDialog(
          title: Text('Adjust Episodes Watched'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Episodes: $totalEpisodes'),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: episodesWatched.toString(),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  newValue = int.tryParse(value) ?? episodesWatched;
                },
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                saveEpisodesWatched(animeId, newValue);
                Navigator.pop(context);
              },
              child: Text('Save'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void toggleExpansionState(int index) {
    setState(() {
      if (expandedIndex == index) {
        expandedIndex = -1; // Collapse the currently expanded anime
      } else {
        expandedIndex = index; // Expand the selected anime
      }
    });
  }

  void updateAnimeDetails(
      List<Map<String, dynamic>> details, List<bool> expansionState) {
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      setState(() {
        animeDetails = details;
        expansionStateList = expansionState;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Watchlist',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<String>>(
              stream: watchlistStream,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final watchlist = snapshot.data!;
                  if (animeDetails.isEmpty) {
                    fetchAnimeDetails(
                        watchlist); // Fetch anime details using watchlist
                  }

                  return Expanded(
                    child: ListView.builder(
                      itemCount: animeDetails.length,
                      itemBuilder: (context, index) {
                        final animeData = animeDetails[index];
                        final attributes = animeData['attributes'];
                        final isExpanded = expandedIndex == index;

                        return Column(
                          children: [
                            GestureDetector(
                              onDoubleTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        AnimeDetailsWithRemoveScreen(
                                      animeData: animeData,
                                    ),
                                  ),
                                );
                              },
                              child: ListTile(
                                title: Text(attributes['canonicalTitle']),
                                subtitle: Text(attributes['startDate']),
                                leading: Image.network(
                                  attributes['posterImage']['original'],
                                ),
                                onTap: () {
                                  toggleExpansionState(index);
                                },
                                onLongPress: () {
                                  final totalEpisodes =
                                      attributes['episodeCount'] as int?;
                                  if (totalEpisodes != null) {
                                    final user =
                                        FirebaseAuth.instance.currentUser;
                                    if (user != null) {
                                      final userId = user.uid;
                                      final docRef = FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(userId)
                                          .collection('watchlist')
                                          .doc(animeData['id']);
                                      docRef.get().then((snapshot) {
                                        if (snapshot.exists) {
                                          final data = snapshot.data();
                                          final episodesWatched =
                                              data?['episodesWatched'] ?? 0;
                                          _showEpisodeTextFieldDialog(
                                            animeData['id'],
                                            episodesWatched,
                                            totalEpisodes,
                                          );
                                        }
                                      });
                                    }
                                  }
                                },
                              ),
                            ),
                            if (isExpanded) ...[
                              FutureBuilder<Map<String, dynamic>>(
                                future: getAnimeDetails(animeData['id']),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const CircularProgressIndicator();
                                  } else if (snapshot.hasData) {
                                    final animeDetail = snapshot.data!;
                                    final totalEpisodes =
                                        animeDetail['attributes']
                                            ['episodeCount'] as int?;
                                    final user =
                                        FirebaseAuth.instance.currentUser;
                                    if (user != null) {
                                      final userId = user.uid;
                                      final docRef = FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(userId)
                                          .collection('watchlist')
                                          .doc(animeData['id']);
                                      return FutureBuilder<
                                          DocumentSnapshot<
                                              Map<String, dynamic>>>(
                                        future: docRef.get(),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const CircularProgressIndicator();
                                          } else if (snapshot.hasData) {
                                            final data = snapshot.data!.data();
                                            int episodesWatched =
                                                data?['episodesWatched'] ?? 0;
                                            return Column(
                                              children: [
                                                const SizedBox(height: 8),
                                                Text(
                                                    'Episodes Watched: $episodesWatched'),
                                                const SizedBox(height: 8),
                                                totalEpisodes != null
                                                    ? Column(
                                                        children: [
                                                          CircularProgressIndicator(
                                                            value:
                                                                episodesWatched /
                                                                    totalEpisodes,
                                                          ),
                                                          const SizedBox(
                                                              height: 8),
                                                          Text(
                                                            'Watched: $episodesWatched / $totalEpisodes',
                                                          ),
                                                          const SizedBox(
                                                              height: 8),
                                                          Row(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              ElevatedButton(
                                                                onPressed: () {
                                                                  setState(() {
                                                                    episodesWatched = (episodesWatched -
                                                                            1)
                                                                        .clamp(
                                                                            0,
                                                                            totalEpisodes);
                                                                  });
                                                                  saveEpisodesWatched(
                                                                      animeData[
                                                                          'id'],
                                                                      episodesWatched);
                                                                },
                                                                child: Icon(Icons
                                                                    .remove),
                                                              ),
                                                              const SizedBox(
                                                                  width: 8),
                                                              ElevatedButton(
                                                                onPressed: () {
                                                                  setState(() {
                                                                    episodesWatched = (episodesWatched +
                                                                            1)
                                                                        .clamp(
                                                                            0,
                                                                            totalEpisodes);
                                                                  });
                                                                  saveEpisodesWatched(
                                                                      animeData[
                                                                          'id'],
                                                                      episodesWatched);
                                                                },
                                                                child: Icon(
                                                                    Icons.add),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      )
                                                    : Text(
                                                        'Total episodes unknown'),
                                              ],
                                            );
                                          } else {
                                            return Text(
                                                'Error: ${snapshot.error}');
                                          }
                                        },
                                      );
                                    } else {
                                      return const SizedBox();
                                    }
                                  } else {
                                    return const SizedBox();
                                  }
                                },
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  return const CircularProgressIndicator();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
