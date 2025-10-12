import 'package:flutter/material.dart';

// Simple icon test widget
class IconTestWidget extends StatelessWidget {
  const IconTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text('Icon Test', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Icon(Icons.home, size: 24, color: Colors.purple),
                  Text('Home'),
                ],
              ),
              Column(
                children: [
                  Icon(Icons.library_books, size: 24, color: Colors.purple),
                  Text('Library'),
                ],
              ),
              Column(
                children: [
                  Icon(Icons.settings, size: 24, color: Colors.purple),
                  Text('Settings'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('If you see squares or empty spaces above, it\'s an icon font issue.'),
        ],
      ),
    );
  }
}