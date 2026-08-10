import 'package:flutter/material.dart';

class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.onConfirm,
  });
  final String title;
  final String message;
  final VoidCallback? onConfirm;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: onConfirm, child: const Text('Confirm')),
    ],
  );
}

class LoadingDialog extends StatelessWidget {
  const LoadingDialog({super.key, this.message = 'Please wait…'});
  final String message;
  @override
  Widget build(BuildContext context) => AlertDialog(
    content: Row(
      children: [
        const CircularProgressIndicator(),
        const SizedBox(width: 16),
        Expanded(child: Text(message)),
      ],
    ),
  );
}
