import 'package:flutter/material.dart';

class ProductDetailScreen extends StatelessWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Navigate to edit product screen
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Product ID: $productId',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  const Text('Product details coming soon...'),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: DefaultTabController(
              length: 1,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Stock History'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.history, size: 48, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('Stock history coming soon...'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
