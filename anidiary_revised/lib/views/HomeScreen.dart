// ignore_for_file: file_names, library_private_types_in_public_api

import 'package:anidiary_revised/views/AnimeDetailsWithRemoveScreen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userId = user.uid;
      watchlistStream = AuthService().getWatchlistStream(userId);
    }
    fetchAnimeDetails(); // Fetch anime details once in the initState
  }

  Future<void> fetchAnimeDetails() async {
    final watchlist = await watchlistStream?.first;
    if (watchlist != null) {
      List<Map<String, dynamic>> details = [];
      for (String animeId in watchlist) {
        final animeDetail = await getAnimeDetails(animeId);
        if (animeDetail != null) {
          details.add(animeDetail);
        }
      }
      setState(() {
        animeDetails = details;
      });
    }
  }

  Future<Map<String, dynamic>?> getAnimeDetails(String animeId) async {
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
        return null;
      }
    } catch (e) {
      return null;
    }
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
                  fetchAnimeDetails(); // Fetch anime details using watchlist

                  return Expanded(
                    child: ListView.builder(
                      itemCount: animeDetails.length,
                      itemBuilder: (context, index) {
                        final animeData = animeDetails[index];
                        final attributes = animeData['attributes'];

                        return ListTile(
                          title: Text(attributes['canonicalTitle']),
                          subtitle: Text(attributes['startDate']),
                          leading: Image.network(
                            attributes['posterImage']['original'],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AnimeDetailsWithRemoveScreen(
                                  animeData: animeData,
                                ),
                              ),
                            ).then((value) {
                              // Refresh anime details after returning from AnimeDetailsWithRemoveScreen
                              fetchAnimeDetails();
                            });
                          },
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
