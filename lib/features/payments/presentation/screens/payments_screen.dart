import 'package:flutter/material.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.payment),
            onPressed: () {
              // TODO: Navigate to record payment screen
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: 0, // TODO: Replace with actual payments list
        itemBuilder: (context, index) {
          return const ListTile(
            leading: CircleAvatar(
              child: Icon(Icons.payment),
            ),
            title: Text('Payment #123'),
            subtitle: Text('Customer Name'),
            trailing: Text('₹ 500'),
          );
        },
      ),
    );
  }
}