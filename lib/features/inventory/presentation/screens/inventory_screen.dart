import 'package:flutter/material.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Stock In'),
            Tab(text: 'Stock Out'),
            Tab(text: 'Transfers'),
            Tab(text: 'Adjustments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStockInTab(),
          _buildStockOutTab(),
          _buildTransfersTab(),
          _buildAdjustmentsTab(),
        ],
      ),
    );
  }

  Widget _buildStockInTab() {
    return ListView.builder(
      itemCount: 0,
      itemBuilder: (context, index) {
        return const ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.green,
            child: Icon(Icons.arrow_downward, color: Colors.white),
          ),
          title: Text('Stock In Entry'),
          subtitle: Text('Supplier - +0 units'),
        );
      },
    );
  }

  Widget _buildStockOutTab() {
    return ListView.builder(
      itemCount: 0,
      itemBuilder: (context, index) {
        return const ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.red,
            child: Icon(Icons.arrow_upward, color: Colors.white),
          ),
          title: Text('Stock Out Entry'),
          subtitle: Text('Sale - -0 units'),
        );
      },
    );
  }

  Widget _buildTransfersTab() {
    return ListView.builder(
      itemCount: 0,
      itemBuilder: (context, index) {
        return const ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blue,
            child: Icon(Icons.swap_horiz, color: Colors.white),
          ),
          title: Text('Transfer Entry'),
          subtitle: Text('Location A → Location B'),
        );
      },
    );
  }

  Widget _buildAdjustmentsTab() {
    return ListView.builder(
      itemCount: 0,
      itemBuilder: (context, index) {
        return const ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.orange,
            child: Icon(Icons.tune, color: Colors.white),
          ),
          title: Text('Adjustment Entry'),
          subtitle: Text('Reason - +0 units'),
        );
      },
    );
  }
}
