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
    // IgnorePointer: this is purely decorative and sits on top of every
    // celebration screen's real content/buttons in a Stack. The confetti
    // package's ConfettiWidget hit-tests over its full (screen-filling)
    // area rather than just the visible particles, so without this a
    // screen's buttons underneath became briefly untappable for as long
    // as confetti was active — found while widget-testing a tap on
    // LeaguePromotionScreen's "Continue" button, reproducible in the real
    // app too, not just a test artifact.
    return IgnorePointer(
      child: Stack(
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
      ),
    );
  }
}
