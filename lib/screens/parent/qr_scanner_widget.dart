// File: lib/screens/parent/qr_scanner_widget.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/feedback_service.dart';
import '../../theme/app_theme.dart';

class QRScannerWidget extends StatefulWidget {
  const QRScannerWidget({super.key});

  @override
  State<QRScannerWidget> createState() => _QRScannerWidgetState();
}

class _QRScannerWidgetState extends State<QRScannerWidget> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;
  String? _lastScannedCode;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _handleQRCodeDetected(BarcodeCapture capture) async {
    // Prevent multiple scans of the same code
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code == _lastScannedCode) return;

    _lastScannedCode = code;

    // Expected format: "READMEAPP:CHILD:{childUid}:{PIN}"
    if (!code.startsWith('READMEAPP:CHILD:')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid QR code - not a ReadMe child account'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      // Reset after short delay to allow rescanning
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _lastScannedCode = null);
        }
      });
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final parts = code.split(':');
      if (parts.length != 4) {
        throw 'Invalid QR code format';
      }

      final childUid = parts[2];
      final pin = parts[3];

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Verify the child exists and PIN matches
      final childDoc =
          await authProvider.firestore.collection('users').doc(childUid).get();

      if (!childDoc.exists) {
        throw 'Child account not found';
      }

      final childData = childDoc.data()!;

      // Verify account type
      if (childData['accountType'] != 'child') {
        throw 'This is not a child account';
      }

      // Verify PIN matches
      if (childData['parentAccessPin'] != pin) {
        throw 'Invalid PIN - QR code may be outdated';
      }

      // Check if account is removed
      if (childData['isRemoved'] == true) {
        throw 'This child account has been removed';
      }

      // NEW: Support multiple parents - check parentIds array
      final List<dynamic> existingParents = childData['parentIds'] ?? [];

      // Check if already linked to THIS parent
      if (existingParents.contains(authProvider.userId)) {
        throw 'This child is already linked to your account';
      }

      // Link child to parent (add to both arrays)
      await authProvider.firestore
          .collection('users')
          .doc(authProvider.userId)
          .update({
        'children': FieldValue.arrayUnion([childUid]),
      });

      await authProvider.firestore.collection('users').doc(childUid).update({
        'parentIds': FieldValue.arrayUnion([authProvider.userId]),
      });

      await authProvider.reloadUserProfile();

      if (!mounted) return;

      FeedbackService.instance.playSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${childData['username']} linked successfully!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Close the screen after successful link
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _lastScannedCode = null; // Allow rescanning after error
      });

      // Show user-friendly error message
      final errorMessage = e.toString().replaceAll('Exception: ', '');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: cameraController,
          onDetect: _handleQRCodeDetected,
        ),

        // Overlay with scanning frame
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Scanning frame
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF8E44AD),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isProcessing
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF8E44AD),
                          ),
                        )
                      : null,
                ),
              ),

              const SizedBox(height: 24),

              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isProcessing
                      ? 'Processing...'
                      : 'Position the QR code within the frame',
                  style: AppTheme.body.copyWith(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const Spacer(flex: 3),

              // Flash toggle button
              Container(
                margin: const EdgeInsets.only(bottom: 40),
                child: IconButton(
                  onPressed: () => cameraController.toggleTorch(),
                  icon:
                      const Icon(Icons.flash_on, color: Colors.white, size: 32),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
