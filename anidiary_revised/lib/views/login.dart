// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'create_account.dart';
import 'package:flutter/material.dart';
import 'home.dart';
import 'package:anidiary_revised/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  SharedPreferences? _prefs;
  bool _showFirstTimeDialog =
      false; // Track if the first-time dialog should be shown

  @override
  void initState() {
    super.initState();
    initSharedPreferences().then((_) {
      checkLoginStatus();
      checkFirstTimeDialog();
    });
  }

  Future<void> initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

  void checkLoginStatus() {
    final isLoggedIn = _prefs?.getBool('isLoggedIn') ?? false;
    if (isLoggedIn) {
      navigateToHome();
    }
  }

  void checkFirstTimeDialog() {
    final isFirstTime = _prefs?.getBool('isFirstTime') ?? true;
    setState(() {
      _showFirstTimeDialog = isFirstTime;
    });
  }

  Future<void> saveLoginStatus(bool isLoggedIn) async {
    await _prefs?.setBool('isLoggedIn', isLoggedIn);
  }

  Future<void> loginUser() async {
    final email = _emailController.text;
    final password = _passwordController.text;

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await saveLoginStatus(true);
      navigateToHome();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login failed: $e'),
        ),
      );
    }
  }

  Future<void> navigateToHome() async {
    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      List<String> watchlist = await getWatchlist(userId);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => home(watchlist: watchlist),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred while accessing the watchlist.'),
        ),
      );
    }
  }

  Future<List<String>> getWatchlist(String userId) async {
    try {
      final watchlist = await AuthService().getWatchlist(userId);
      return watchlist;
    } catch (e) {
      return [];
    }
  }

  Future<void> dismissFirstTimeDialog() async {
    await _prefs?.setBool('isFirstTime', false);
    setState(() {
      _showFirstTimeDialog = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show the dialog by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_showFirstTimeDialog) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Welcome!'),
            content: const Text(
                'This is app is in an extremely early alpha and so many features may not work as intended. Fear not - updates are on the way, just slow.Any bugs can be reported on my github(https://github.com/DRuttz/AniDiary-Revised).When inputting the episodes watched you can hold to bring up a dialogue box which will allow you to enter a number, additionally to remove an anime from your watchlist you can double tap the anime from the homescreen which will take you to the details page.To be able to message someone they must add you as a friend also.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  dismissFirstTimeDialog();
                },
                child: const Text('Never see again'),
              ),
            ],
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width / 2,
              child: TextField(
                controller: _emailController,
                decoration: const InputDecoration(hintText: 'Email'),
              ),
            ),
            const SizedBox(
              height: 30.0,
            ),
            SizedBox(
              width: MediaQuery.of(context).size.width / 2,
              child: TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Password',
                ),
              ),
            ),
            const SizedBox(
              height: 30.0,
            ),
            ElevatedButton(
              onPressed: () {
                loginUser();
              },
              child: const Text('Login'),
            ),
            const SizedBox(
              height: 30.0,
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CreateAccount(),
                  ),
                );
              },
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }
}
