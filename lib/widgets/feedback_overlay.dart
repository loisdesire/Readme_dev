import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../services/feedback_service.dart';

/// Small overlay that listens to FeedbackService.event and plays a
/// short confetti burst when requested. UI can include this near the
/// root of relevant flows (e.g., BookDetailsScreen, QuizResultScreen)
/// or in the app scaffold.
class FeedbackOverlay extends StatefulWidget {
  const FeedbackOverlay({super.key});

  @override
  State<FeedbackOverlay> createState() => _FeedbackOverlayState();
}

class _FeedbackOverlayState extends State<FeedbackOverlay> {
  late ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 1));
    FeedbackService.instance.event.addListener(_onEvent);
  }

  void _onEvent() {
    final e = FeedbackService.instance.event.value;
    if (e == FeedbackEvent.confetti) {
      _controller.play();
      // Clear the event so repeated UI won't replay unintentionally
      FeedbackService.instance.event.value = FeedbackEvent.none;
    }
  }

  @override
  void dispose() {
    FeedbackService.instance.event.removeListener(_onEvent);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: _controller,
        blastDirectionality: BlastDirectionality.explosive,
        shouldLoop: false,
        emissionFrequency: 0.6,
        numberOfParticles: 5,
        maxBlastForce: 20,
        minBlastForce: 8,
        gravity: 0.3,
      ),
    );
  }
}
