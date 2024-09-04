import 'package:agc_record/widgets/bottomnav.dart';
import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedSplashScreen(
      splash: Center(
        child: Lottie.asset(
          'assets/animation/Animation - 1725429155564.json'
        ),
      ),
      nextScreen: BottomNavWidgets(),
      duration: 3000,
      backgroundColor: const Color.fromARGB(255, 5, 95, 180),
    );
  }
}