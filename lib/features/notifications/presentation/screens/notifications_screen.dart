import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedType = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() => _selectedType = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All')),
              const PopupMenuItem(value: 'Sales', child: Text('Sales')),
              const PopupMenuItem(value: 'Payments', child: Text('Payments')),
              const PopupMenuItem(value: 'Inventory', child: Text('Inventory')),
              const PopupMenuItem(value: 'System', child: Text('System')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: () {
              // TODO: Mark all as read
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Filter: $_selectedType',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    // TODO: Clear all notifications
                  },
                  child: const Text('Clear All'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 0,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.notifications),
                    ),
                    title: const Text('Notification Title'),
                    subtitle: const Text('Notification content will appear here...'),
                    trailing: IconButton(
                      icon: const Icon(Icons.mark_email_read),
                      onPressed: () {
                        // TODO: Mark as read
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
