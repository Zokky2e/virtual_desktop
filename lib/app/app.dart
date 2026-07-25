import 'package:flutter/material.dart';
import '../core/di/injector.dart';
import '../core/repositories/auth_repository.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Desktop',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            children: [
              Text('Virtual Desktop'),
              FloatingActionButton(
                child: Text("Login"),
                onPressed: () async {
                  final auth = getIt<AuthRepository>();
                  final result = await auth.signIn(
                    email: 'test@test.com',
                    password: 'x',
                  );
                  debugPrint(result.toString());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
