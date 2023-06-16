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

  @override
  void initState() {
    super.initState();
    initSharedPreferences().then((_) {
      checkLoginStatus();
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
        SnackBar(
          content:
              const Text('An error occurred while accessing the watchlist.'),
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

  @override
  Widget build(BuildContext context) {
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
