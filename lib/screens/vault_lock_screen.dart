import 'dart:ui';
import 'package:flutter/material.dart';
import '../storage/database.dart';
import '../widgets/glass_box.dart';
import 'vault_gallery_screen.dart';

class VaultLockScreen extends StatefulWidget {
  const VaultLockScreen({Key? key}) : super(key: key);

  @override
  _VaultLockScreenState createState() => _VaultLockScreenState();
}

class _VaultLockScreenState extends State<VaultLockScreen> {
  String _enteredPin = '';
  String? _storedPin;
  bool _isFirstTime = false;
  bool _isConfirming = false;
  String _firstPinAttempt = '';
  String _errorMessage = '';
  bool _isShaking = false;

  @override
  void initState() {
    super.initState();
    _checkStoredPin();
  }

  Future<void> _checkStoredPin() async {
    final pin = await DatabaseHelper.getVaultPin();
    if (mounted) {
      setState(() {
        _storedPin = pin;
        _isFirstTime = (pin == null || pin.isEmpty);
      });
    }
  }

  void _onNumberTap(String number) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += number;
        _errorMessage = '';
      });

      if (_enteredPin.length == 4) {
        _processPin();
      }
    }
  }

  void _onBackspaceTap() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = '';
      });
    }
  }

  void _onClearTap() {
    setState(() {
      _enteredPin = '';
      _errorMessage = '';
    });
  }

  Future<void> _processPin() async {
    if (_isFirstTime) {
      if (!_isConfirming) {
        // Storing first attempt
        setState(() {
          _firstPinAttempt = _enteredPin;
          _enteredPin = '';
          _isConfirming = true;
        });
      } else {
        // Comparing second attempt
        if (_enteredPin == _firstPinAttempt) {
          await DatabaseHelper.setVaultPin(_enteredPin);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PIN Vault successfully created!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const VaultGalleryScreen()),
            );
          }
        } else {
          _triggerShake();
          setState(() {
            _enteredPin = '';
            _errorMessage = 'PIN codes do not match. Try again!';
          });
        }
      }
    } else {
      // Login flow
      if (_enteredPin == _storedPin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const VaultGalleryScreen()),
        );
      } else {
        _triggerShake();
        setState(() {
          _enteredPin = '';
          _errorMessage = 'Incorrect PIN! Please try again.';
        });
      }
    }
  }

  void _triggerShake() {
    setState(() {
      _isShaking = true;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _isShaking = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String instructionText = 'Enter 4-Digit Vault PIN';
    if (_isFirstTime) {
      instructionText = _isConfirming 
          ? 'Confirm 4-Digit PIN' 
          : 'Set 4-Digit PIN to secure Vault';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background glass abstract blur styling
          Positioned(
            top: 100,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.shade900.withOpacity(0.2),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.shade900.withOpacity(0.12),
              ),
            ),
          ),
          
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              color: Colors.black.withOpacity(0.7),
            ),
          ),

          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top close button
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Icon and Title
                Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.blue.shade400,
                  size: 54,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Private Glass Vault',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  instructionText,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12.5,
                  ),
                ),
                
                const SizedBox(height: 32),

                // PIN dots indicators
                AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  padding: EdgeInsets.symmetric(horizontal: _isShaking ? 24.0 : 0.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final isFilled = index < _enteredPin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isFilled 
                              ? Colors.blue.shade400 
                              : Colors.white.withOpacity(0.12),
                          border: Border.all(
                            color: isFilled 
                                ? Colors.blue.shade400 
                                : Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: isFilled
                              ? [
                                  BoxShadow(
                                    color: Colors.blue.shade400.withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  )
                                ]
                              : [],
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 20),

                // Error Message
                SizedBox(
                  height: 20,
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const Spacer(),

                // Keyboard Number Grid
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    childAspectRatio: 1.25,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      ...List.generate(9, (index) {
                        final num = (index + 1).toString();
                        return _buildKeyboardButton(num, () => _onNumberTap(num));
                      }),
                      _buildKeyboardButton('CLEAR', _onClearTap, isAction: true),
                      _buildKeyboardButton('0', () => _onNumberTap('0')),
                      _buildKeyboardButton('BACK', _onBackspaceTap, isAction: true),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardButton(String label, VoidCallback onTap, {bool isAction = false}) {
    final double size = isAction ? 11 : 20;

    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: GlassBox(
          width: 64,
          height: 64,
          borderRadius: 32,
          blur: 10,
          tintColor: Colors.white.withOpacity(0.04),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isAction ? Colors.white70 : Colors.white,
                fontSize: size,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
