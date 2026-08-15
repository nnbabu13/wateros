import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reports = [
      _ReportOption('Daily Sales', Icons.today, Colors.blue, '/daily-sales'),
      _ReportOption('All Sales', Icons.receipt_long, Colors.green, '/sales'),
      _ReportOption('Expense Report', Icons.receipt_long, Colors.red, '/reports/expense-report'),
      _ReportOption('Profit & Loss', Icons.analytics, Colors.green, '/reports/pnl'),
      _ReportOption('Cash Flow', Icons.account_balance_wallet, Colors.indigo, '/cashbook'),
      _ReportOption('Bank Book', Icons.account_balance, Colors.teal, '/bankbook'),
      _ReportOption('Inventory', Icons.inventory, Colors.brown, '/inventory'),
      _ReportOption('Employees', Icons.people, Colors.orange, '/employees'),
      _ReportOption('Suppliers', Icons.business, Colors.purple, '/suppliers'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
        ),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          final report = reports[index];
          return GestureDetector(
            onTap: () => context.push(report.route),
            child: Card(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: report.color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(report.icon, color: report.color, size: 32),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    report.label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReportOption {
  final String label;
  final IconData icon;
  final Color color;
  final String route;

  const _ReportOption(this.label, this.icon, this.color, this.route);
}
