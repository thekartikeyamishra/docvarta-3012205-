// G:\docvartaa\lib\widgets\call_id_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Small dialog widget that shows call ID, with a copy button and nice micro-animation.
/// Usage: showDialog(context: ..., builder: (_) => CallIdDialog(callId: 'abcd123'));
class CallIdDialog extends StatefulWidget {
  final String callId;
  const CallIdDialog({super.key, required this.callId});

  @override
  State<CallIdDialog> createState() => _CallIdDialogState();
}

class _CallIdDialogState extends State<CallIdDialog> with SingleTickerProviderStateMixin {
  bool _copied = false;
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.callId));
    setState(() => _copied = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Call created'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Share this Call ID with the patient so they can join the consultation:'),
          const SizedBox(height: 12),
          SelectableText(widget.callId, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy),
                label: Text(_copied ? 'Copied' : 'Copy ID'),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.check), label: const Text('Done')),
          ]),
        ]),
      ),
    );
  }
}
