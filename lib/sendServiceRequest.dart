import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RequestService {
  static Future<void> sendRequest({
    required BuildContext context,
    required String professionalId, // ID of the professional sending the request
    required String orderId,        // ID of the order being requested
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
      // --- Step 1: Check if the request has already been sent by this professional for this order ---
      final professionalUserRef = FirebaseFirestore.instance.collection('users').doc(professionalId);
      final professionalSnapshot = await professionalUserRef.get();

      if (professionalSnapshot.exists) {
        final professionalData = professionalSnapshot.data();
        final List<dynamic> requestsSent = professionalData?['requestsSent'] ?? [];

        if (requestsSent.contains(orderId)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ You have already sent a request for this order.'),
              backgroundColor: Colors.orange, // Highlight warning
            ),
          );
          return; // Stop execution if request already exists
        }
      } else {
        // Handle case where professional user document doesn't exist (though it should for logged-in users)
        print('Warning: Professional user document not found for ID: $professionalId');
        // You might decide to return or proceed, but it's an unusual state.
        // For robustness, we'll proceed as if they just haven't sent any requests yet.
      }


      // --- Step 2: If not already sent, proceed with sending the request ---
      final request = {
        'professionalId': professionalId,
        'price': price,
        'message': message,
        'status': 'pending',
        'timestamp': DateTime.now().toIso8601String(), // Use server timestamp for accuracy
      };

      // Update the Order Document
      final orderRef = FirebaseFirestore.instance.collection('orders').doc(orderId);
      await orderRef.update({
        'applications': FieldValue.arrayUnion([request]),
      });

      // Update the Professional's User Document (add orderId to requestsSent)
      // This update will only happen if the check above passed.
      await professionalUserRef.update({
        'requestsSent': FieldValue.arrayUnion([orderId]), // Add the orderId to the array
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Request sent successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending request: $e')),
      );
      print('Error sending request: $e'); // For debugging
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
