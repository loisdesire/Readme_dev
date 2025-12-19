import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

class ParentLinkQRScreen extends StatefulWidget {
  final String childUid;
  final String childName;
  final String? parentAccessPin;

  const ParentLinkQRScreen({
    super.key,
    required this.childUid,
    required this.childName,
    this.parentAccessPin,
  });

  @override
  State<ParentLinkQRScreen> createState() => _ParentLinkQRScreenState();
}

class _ParentLinkQRScreenState extends State<ParentLinkQRScreen> {
  String? _pin;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePin();
  }

  Future<void> _initializePin() async {
    try {
      if (widget.parentAccessPin != null) {
        // Use existing PIN
        setState(() {
          _pin = widget.parentAccessPin;
          _isLoading = false;
        });
      } else {
        // Generate and save new PIN
        final newPin =
            (100000 + (DateTime.now().millisecondsSinceEpoch % 900000))
                .toString();

        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.firestore
            .collection('users')
            .doc(widget.childUid)
            .update({'parentAccessPin': newPin});

        await authProvider.reloadUserProfile();

        setState(() {
          _pin = newPin;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Link to Parent',
            style: AppTheme.heading.copyWith(color: Colors.black87),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF8E44AD)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F9F9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Link to Parent',
            style: AppTheme.heading.copyWith(color: Colors.black87),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Failed to generate PIN',
                  style: AppTheme.heading.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: AppTheme.body.copyWith(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Create QR data with child info
    final qrData = 'READMEAPP:CHILD:${widget.childUid}:$_pin';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Link to Parent',
          style: AppTheme.heading.copyWith(color: Colors.black87),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF8E44AD),
                      Color(0xFFA062BA),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Text(
                      'Connect with Parent',
                      style: AppTheme.heading.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Show this to your parent',
                      style: AppTheme.body.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // QR Code
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x1A9E9E9E),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 250.0,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF8E44AD),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF8E44AD),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.childName,
                      style: AppTheme.heading.copyWith(
                        fontSize: 20,
                        color: const Color(0xFF8E44AD),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // PIN Alternative
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurpleOpaque10,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppTheme.primaryPurpleOpaque30,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.key,
                          color: Color(0xFF8E44AD),
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Or use PIN code',
                          style: AppTheme.heading.copyWith(
                            fontSize: 16,
                            color: const Color(0xFF8E44AD),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _pin!,
                        style: AppTheme.heading.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF8E44AD),
                          letterSpacing: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Instructions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x1A9E9E9E),
                      spreadRadius: 1,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How to connect:',
                      style: AppTheme.heading.copyWith(
                        fontSize: 18,
                        color: const Color(0xFF8E44AD),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildStep(
                      '1',
                      'Parent opens the ReadMe app',
                    ),
                    _buildStep(
                      '2',
                      'Parent taps "Add Child" → "Scan QR Code"',
                    ),
                    _buildStep(
                      '3',
                      'Parent scans this QR code with their camera',
                    ),
                    _buildStep(
                      '4',
                      'Done! You\'ll be linked instantly',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF8E44AD),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                number,
                style: AppTheme.heading.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                text,
                style: AppTheme.body.copyWith(
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
