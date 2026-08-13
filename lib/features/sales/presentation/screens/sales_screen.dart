import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class SalesScreen extends StatefulWidget {
  final int initialTab;
  const SalesScreen({super.key, this.initialTab = 0});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allSales = [];
  bool _isLoading = true;
  String _businessId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);
    _loadSales();
  }

  Future<void> _loadSales() async {
    try {
      _businessId = await BusinessHelper.getOrCreateBusinessId();

      final data = await Supabase.instance.client
          .from('sales')
          .select('*, customer:customers(name, phone)')
          .eq('business_id', _businessId)
          .order('invoice_date', ascending: false);

      if (mounted) {
        setState(() {
          _allSales = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredSales(String? status) {
    if (status == null) return _allSales;
    return _allSales.where((s) => s['status'] == status).toList();
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'partially_paid':
        return 'Partial';
      case 'pending':
        return 'Pending';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status, BuildContext context) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'partially_paid':
        return Colors.orange;
      case 'pending':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Theme.of(context).colorScheme.primary;
    }
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
        title: const Text('Sales'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Paid'),
            Tab(text: 'Pending'),
            Tab(text: 'Partial'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await context.push('/sales/create');
              if (result == true) _loadSales();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSalesList(_allSales),
                _buildSalesList(_getFilteredSales('paid')),
                _buildSalesList(_getFilteredSales('pending')),
                _buildSalesList(_getFilteredSales('partially_paid')),
              ],
            ),
    );
  }

  Widget _buildSalesList(List<Map<String, dynamic>> sales) {
    if (sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('No sales found',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await context.push('/sales/create');
                if (result == true) _loadSales();
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Sale'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSales,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: sales.length,
        itemBuilder: (context, index) {
          final sale = sales[index];
          final customerName =
              (sale['customer'] as Map<String, dynamic>?)?['name'] as String? ??
                  sale['customer_name'] as String? ??
                  'Unknown';
          final total = (sale['total_amount'] as num?)?.toDouble() ?? 0;
          final paid = (sale['paid_amount'] as num?)?.toDouble() ?? 0;
          final balance = (sale['balance_amount'] as num?)?.toDouble() ?? 0;
          final status = sale['status'] as String? ?? 'pending';
          final invoiceDate = sale['invoice_date'] as String? ?? '';
          final invoiceNum = sale['invoice_number'] as String? ?? '';

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(status, context).withOpacity(0.1),
                child: Text(
                  customerName[0].toUpperCase(),
                  style: TextStyle(
                    color: _getStatusColor(status, context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      customerName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status, context).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(status, context),
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Row(
                children: [
                  if (invoiceNum.isNotEmpty)
                    Text(invoiceNum,
                        style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 8),
                  if (invoiceDate.isNotEmpty)
                    Text(
                      DateFormat('dd MMM').format(DateTime.parse(invoiceDate)),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹ ${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (balance > 0)
                    Text(
                      'Bal: ₹ ${balance.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange.shade700,
                      ),
                    ),
                ],
              ),
              onTap: () {
                context.push('/sales/${sale['id']}');
              },
            ),
          );
        },
      ),
    );
  }
}
