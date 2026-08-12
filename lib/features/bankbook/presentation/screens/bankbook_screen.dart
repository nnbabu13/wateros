import 'package:flutter/material.dart';

class BankbookScreen extends StatefulWidget {
  const BankbookScreen({super.key});

  @override
  State<BankbookScreen> createState() => _BankbookScreenState();
}

class _BankbookScreenState extends State<BankbookScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('Bank Book'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All Accounts'),
            Tab(text: 'Savings'),
            Tab(text: 'Current'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Balance',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '₹0.00',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    // TODO: Add bank account
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionList(),
                _buildTransactionList(),
                _buildTransactionList(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add bank transaction
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTransactionList() {
    return ListView.builder(
      itemCount: 0,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.account_balance),
            ),
            title: const Text('Bank Transaction'),
            subtitle: const Text('Description'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹0.00',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: index.isEven ? Colors.green : Colors.red,
                  ),
                ),
                Text(
                  'Date',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
