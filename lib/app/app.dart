import 'package:flutter/material.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Desktop',
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('Virtual Desktop'))),
    );
  }
}
