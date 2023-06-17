// ignore_for_file: library_private_types_in_public_api, camel_case_types

import 'package:anidiary_revised/views/HomeScreen.dart';
import 'package:flutter/material.dart';
import 'BrowseScreen.dart';
import 'ProfileScreen.dart';

class home extends StatefulWidget {
  final List<String> watchlist;

  const home({Key? key, required this.watchlist}) : super(key: key);

  @override
  _homeState createState() => _homeState();
}

class _homeState extends State<home> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AniDiary'), centerTitle: true),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          HomeScreen(),
          BrowseScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Browse',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message_rounded),
            label: 'Social',
          )
        ],
      ),
    );
  }
}
