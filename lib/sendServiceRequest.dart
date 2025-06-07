import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RequestService {
  static Future<void> sendRequest({
    required BuildContext context,
    required String professionalId,
    required String orderId,
    required String price,
    required String message,
  }) async {
    if (price.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required")),
      );
      return;
    }

    try {
      final request = {
        'professionalId' : professionalId,
        'price': price,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);

      await orderRef.update({
        'applications': FieldValue.arrayUnion([request]),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Request sent successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending request: $e')),
      );
    }
  }
}


class SendRequestDialog extends StatefulWidget {
  final String orderId;
  final String professionalId;

  const SendRequestDialog({
    super.key,
    required this.orderId,
    required this.professionalId,
  });

  @override
  State<SendRequestDialog> createState() => _SendRequestDialogState();
}

class _SendRequestDialogState extends State<SendRequestDialog> {
  final TextEditingController priceController = TextEditingController();
  final TextEditingController messageController = TextEditingController();
  bool _loading = false;

  void _submitRequest() async {
    final price = priceController.text.trim();
    final message = messageController.text.trim();

    setState(() => _loading = true);

    await RequestService.sendRequest(
      context: context,
      professionalId: widget.professionalId,
      orderId: widget.orderId,
      price: price,
      message: message,
    );

    setState(() => _loading = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text("Send Request"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: priceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Price',
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
          TextField(
            controller: messageController,
            decoration: const InputDecoration(
              labelText: 'Message',
              prefixIcon: Icon(Icons.message),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submitRequest,
          child: _loading
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Send'),
        ),
      ],
    );
  }
}
