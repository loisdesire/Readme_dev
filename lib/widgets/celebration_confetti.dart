import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

/// Standardized confetti widget used across all celebration screens.
/// Creates two confetti blasts from top-left and top-right corners.
class CelebrationConfetti extends StatelessWidget {
  final ConfettiController controller;

  const CelebrationConfetti({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Left confetti
        Align(
          alignment: Alignment.topLeft,
          child: ConfettiWidget(
            confettiController: controller,
            blastDirection: 0,
            blastDirectionality: BlastDirectionality.directional,
            emissionFrequency: 0.15,
            numberOfParticles: 1,
            gravity: 0.2,
            shouldLoop: false,
            colors: const [
              Colors.yellow,
              Colors.orange,
              Colors.pink,
              Colors.purple,
              Colors.blue,
              Colors.green,
            ],
          ),
        ),
        // Right confetti
        Align(
          alignment: Alignment.topRight,
          child: ConfettiWidget(
            confettiController: controller,
            blastDirection: 3.14,
            blastDirectionality: BlastDirectionality.directional,
            emissionFrequency: 0.15,
            numberOfParticles: 1,
            gravity: 0.2,
            shouldLoop: false,
            colors: const [
              Colors.yellow,
              Colors.orange,
              Colors.pink,
              Colors.purple,
              Colors.blue,
              Colors.green,
            ],
          ),
        ),
      ],
    );
  }
}
