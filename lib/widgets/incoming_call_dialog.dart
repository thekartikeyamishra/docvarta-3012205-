// lib/widgets/incoming_call_dialog.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

class IncomingCallDialog extends StatefulWidget {
  final String doctorName;
  final String callId;
  final String? doctorSpecialization;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallDialog({
    super.key,
    required this.doctorName,
    required this.callId,
    this.doctorSpecialization,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;
  Timer? _autoDeclineTimer;
  int _remainingSeconds = 30;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    // Pulse animation for call icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Ripple animation for background
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    // Auto-decline after 30 seconds
    _autoDeclineTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
          if (_remainingSeconds <= 0) {
            timer.cancel();
            if (!_isProcessing) {
              widget.onDecline();
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rippleController.dispose();
    _autoDeclineTimer?.cancel();
    super.dispose();
  }

  void _handleAccept() {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _autoDeclineTimer?.cancel();
    widget.onAccept();
  }

  void _handleDecline() {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _autoDeclineTimer?.cancel();
    widget.onDecline();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.blue.shade50.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Call Icon with Ripples
            Stack(
              alignment: Alignment.center,
              children: [
                // Ripple effect
                AnimatedBuilder(
                  animation: _rippleAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 140 + (40 * _rippleAnimation.value),
                      height: 140 + (40 * _rippleAnimation.value),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blue.withOpacity(
                            0.3 * (1 - _rippleAnimation.value),
                          ),
                          width: 2,
                        ),
                      ),
                    );
                  },
                ),
                // Pulsing icon
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade400,
                          Colors.blue.shade700,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.video_call,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Incoming Call Text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '📞 Incoming Video Call',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Doctor Name
            Text(
              'Dr. ${widget.doctorName}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Specialization (if available)
            if (widget.doctorSpecialization != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.doctorSpecialization!,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Timer with Progress Indicator
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: _remainingSeconds / 30,
                    strokeWidth: 3,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _remainingSeconds <= 10 ? Colors.red : Colors.blue,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_remainingSeconds',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _remainingSeconds <= 10 
                            ? Colors.red.shade700 
                            : Colors.blue.shade700,
                      ),
                    ),
                    Text(
                      'sec',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Text(
              _remainingSeconds <= 10 
                  ? 'Call ending soon!' 
                  : 'Auto-decline in progress',
              style: TextStyle(
                fontSize: 12,
                color: _remainingSeconds <= 10 
                    ? Colors.red.shade700 
                    : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Action Buttons
            if (!_isProcessing) ...[
              Row(
                children: [
                  // Decline Button
                  Expanded(
                    child: _buildActionButton(
                      onPressed: _handleDecline,
                      icon: Icons.call_end_rounded,
                      label: 'Decline',
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Accept Button
                  Expanded(
                    child: _buildActionButton(
                      onPressed: _handleAccept,
                      icon: Icons.video_call_rounded,
                      label: 'Accept',
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      isPrimary: true,
                    ),
                  ),
                ],
              ),
            ] else ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 8),
              const Text(
                'Connecting...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    bool isPrimary = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: isPrimary ? 8 : 4,
        shadowColor: backgroundColor.withOpacity(0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}