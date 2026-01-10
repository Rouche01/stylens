import 'package:flutter/material.dart';
import 'dart:async';
import 'package:gostylens/pages/login.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (context) => LoginPage()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'GoStylens',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w600,
            fontFamily: 'ClashDisplay',
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.primary,
    );
  }
}
