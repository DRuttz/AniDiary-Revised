// ignore_for_file: file_names, library_private_types_in_public_api

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'AnimeDetailsScreeen.dart';
import 'SearchScreen.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({Key? key}) : super(key: key);

  @override
  _BrowseScreenState createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  List<dynamic> animeList = [];
  int _currentPage = 0;
  bool _isLoading = false;

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

  @override
  void initState() {
    super.initState();
    _fetchAnimeData(_currentPage);
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
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (!_isLoading &&
              scrollNotification.metrics.pixels ==
                  scrollNotification.metrics.maxScrollExtent) {
            _currentPage += 20;
            _fetchAnimeData(_currentPage);
            return true;
          }
          return false;
        },
        child: ListView.builder(
          itemCount: animeList.length + 1,
          itemBuilder: (BuildContext context, int index) {
            if (index == animeList.length) {
              return _buildProgressIndicator();
            } else {
              final animeData = animeList[index];
              final animeAttributes = animeData['attributes'];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AnimeDetailsScreen(animeData: animeData),
                    ),
                  );
                },
                child: ListTile(
                  leading:
                      Image.network(animeAttributes['posterImage']['small']),
                  title: Text(animeAttributes['canonicalTitle']),
                  subtitle: Text(animeAttributes['startDate']),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Container();
  }
}
