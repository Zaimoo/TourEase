import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tourease/services/use_auth.dart';
import 'package:tourease/view/onboarding_screen.dart';
import 'package:tourease/view/root_page.dart';

import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final Future<Widget> _splashScreenFuture;
  final _auth = UseAuth();

  Future<Widget> _checkUser() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    if (!hasSeenOnboarding) {
      return OnboardingScreen(
        onComplete: () {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SplashScreen()),
          );
        },
      );
    }

    if (_auth.user != null) {
      return const RootPage();
    } else {
      return const LoginScreen();
    }
  }

  @override
  void initState() {
    super.initState();
    _splashScreenFuture = _checkUser();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: true,
        body: FutureBuilder<Widget>(
            future: _splashScreenFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Icon(
                    CupertinoIcons.compass_fill,
                    size: 64,
                  ),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const LoginScreen();
              }
              return snapshot.data!;
            }));
  }
}
