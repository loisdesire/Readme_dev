import 'package:flutter/material.dart';

void main() {
  runApp(TestIconsApp());
}

class TestIconsApp extends StatelessWidget {
  const TestIconsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Icons',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: TestIconsScreen(),
    );
  }
}

class TestIconsScreen extends StatelessWidget {
  const TestIconsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Icons'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home, size: 50),
            SizedBox(height: 20),
            Icon(Icons.library_books, size: 50),
            SizedBox(height: 20),
            Icon(Icons.settings, size: 50),
            SizedBox(height: 20),
            Icon(Icons.person, size: 50),
            SizedBox(height: 20),
            Text('Icons Test'),
          ],
        ),
      ),
    );
  }
}