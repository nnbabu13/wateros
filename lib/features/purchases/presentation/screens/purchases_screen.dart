import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  List<Map<String, dynamic>> _purchases = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final data = await Supabase.instance.client
          .from('purchases')
          .select('*, suppliers(name)')
          .eq('business_id', bizId)
          .neq('status', 'cancelled')
          .order('purchase_date', ascending: false);

      if (mounted) {
        setState(() {
          _purchases = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePurchase(Map<String, dynamic> purchase) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Purchase'),
        content: Text('Delete ${purchase['purchase_number']}? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('purchase_items')
          .delete()
          .eq('purchase_id', purchase['id']);

      await Supabase.instance.client
          .from('purchases')
          .delete()
          .eq('id', purchase['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase deleted'), backgroundColor: Colors.green),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredPurchases {
    if (_searchQuery.isEmpty) return _purchases;
    final q = _searchQuery.toLowerCase();
    return _purchases.where((p) {
      final number = (p['purchase_number'] as String? ?? '').toLowerCase();
      final supplier = (p['suppliers'] as Map<String, dynamic>?)?['name'] as String? ?? '';
      return number.contains(q) || supplier.toLowerCase().contains(q);
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid': return Colors.green;
      case 'partially_paid': return Colors.orange;
      default: return Colors.red;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid': return 'PAID';
      case 'partially_paid': return 'PARTIAL';
      default: return 'PENDING';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rupee = String.fromCharCode(8377);
    final totalAmount = _filteredPurchases.fold<double>(0, (s, p) => s + ((p['total_amount'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchases'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push<bool>('/purchases/create');
          if (result == true) _loadData();
        },
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search purchases...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          if (!_isLoading && _filteredPurchases.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text('${_filteredPurchases.length} purchases', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const Spacer(),
                  Text('Total: $rupee${totalAmount.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.primary)),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPurchases.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shopping_cart_outlined, size: 64, color: cs.outline),
                            const SizedBox(height: 16),
                            Text('No purchases yet', style: TextStyle(color: cs.onSurfaceVariant)),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => context.push('/purchases/create'),
                              icon: const Icon(Icons.add),
                              label: const Text('Create Purchase'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredPurchases.length,
                          itemBuilder: (context, index) => _buildPurchaseCard(_filteredPurchases[index], cs),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseCard(Map<String, dynamic> purchase, ColorScheme cs) {
    final supplierName = (purchase['suppliers'] as Map<String, dynamic>?)?['name'] as String? ?? 'Unknown';
    final purchaseNumber = purchase['purchase_number'] as String? ?? '';
    final dateStr = purchase['purchase_date'] as String? ?? '';
    final totalAmount = (purchase['total_amount'] as num?)?.toDouble() ?? 0;
    final paidAmount = (purchase['paid_amount'] as num?)?.toDouble() ?? 0;
    final balanceAmount = (purchase['balance_amount'] as num?)?.toDouble() ?? 0;
    final status = purchase['status'] as String? ?? 'pending';
    final purchaseDate = dateStr.isNotEmpty ? DateTime.tryParse(dateStr) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await context.push<bool>('/purchases/create', extra: purchase['id']);
          if (result == true) _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(supplierName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(purchaseNumber, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                    onSelected: (v) async {
                      if (v == 'edit') {
                        final result = await context.push<bool>('/purchases/create', extra: purchase['id']);
                        if (result == true) _loadData();
                      } else if (v == 'delete') {
                        _deletePurchase(purchase);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (purchaseDate != null)
                    Text(DateFormat('dd MMM yyyy').format(purchaseDate), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_statusLabel(status), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _statusColor(status))),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Total: ', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                  Text('₹${totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const Spacer(),
                  if (balanceAmount > 0)
                    Text('Due: ₹${balanceAmount.toStringAsFixed(0)}', style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
