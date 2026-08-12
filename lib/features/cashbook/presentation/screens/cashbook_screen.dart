import 'package:flutter/material.dart';

class CashbookScreen extends StatefulWidget {
  const CashbookScreen({super.key});

  @override
  State<CashbookScreen> createState() => _CashbookScreenState();
}

class _CashbookScreenState extends State<CashbookScreen> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Book'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterDialog();
            },
          ),
        ],
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
                      'Balance',
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
                Row(
                  children: [
                    _buildSummaryChip('In', '₹0', Colors.green),
                    const SizedBox(width: 8),
                    _buildSummaryChip('Out', '₹0', Colors.red),
                  ],
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
                      child: Icon(Icons.receipt),
                    ),
                    title: const Text('Transaction'),
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
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add cash entry
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryChip(String label, String amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$label: $amount',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filter by Date',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Start Date'),
              subtitle: Text(_startDate?.toString() ?? 'Select'),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _startDate = date);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('End Date'),
              subtitle: Text(_endDate?.toString() ?? 'Select'),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _endDate = date);
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: Apply filter
              },
              child: const Text('Apply Filter'),
            ),
          ],
        ),
      ),
    );
  }
}
