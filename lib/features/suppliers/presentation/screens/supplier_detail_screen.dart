import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SupplierDetailScreen extends StatefulWidget {
  final String supplierId;
  const SupplierDetailScreen({super.key, required this.supplierId});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  Map<String, dynamic>? _supplier;
  List<Map<String, dynamic>> _purchases = [];
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final supFuture = Supabase.instance.client
          .from('suppliers')
          .select()
          .eq('id', widget.supplierId)
          .single();
      final purchasesFuture = Supabase.instance.client
          .from('purchases')
          .select('id, purchase_number, purchase_date, total_amount, paid_amount, balance_amount, status')
          .eq('supplier_id', widget.supplierId)
          .order('purchase_date', ascending: false)
          .limit(50);
      final paymentsFuture = Supabase.instance.client
          .from('supplier_payments')
          .select('id, amount, payment_mode, payment_date, reference_number, notes')
          .eq('supplier_id', widget.supplierId)
          .order('payment_date', ascending: false)
          .limit(50);
      final results = await Future.wait([supFuture, purchasesFuture, paymentsFuture]);

      if (mounted) {
        setState(() {
          _supplier = results[0] as Map<String, dynamic>;
          _purchases = List<Map<String, dynamic>>.from(results[1] as List);
          _payments = List<Map<String, dynamic>>.from(results[2] as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final s = _supplier;
    if (s == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Supplier not found')));
    }

    final cs = Theme.of(context).colorScheme;
    final balance = (s['current_balance'] as num?)?.toDouble() ?? 0;
    final totalPurchases = _purchases.fold<double>(0, (sum, p) => sum + ((p['total_amount'] as num?)?.toDouble() ?? 0));
    final totalPaid = _payments.fold<double>(0, (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0));

    return Scaffold(
      appBar: AppBar(
        title: Text(s['name'] as String),
        actions: [
          PopupMenuButton(
            itemBuilder: (_) => <PopupMenuEntry<String>>[
              const PopupMenuItem(value: 'edit', child: Text('Edit Supplier')),
              const PopupMenuItem(value: 'call', child: Text('Call')),
              const PopupMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete', child: Text('Delete Supplier', style: TextStyle(color: Colors.red))),
            ],
            onSelected: (v) => _handleMenuAction(v),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildProfileHeader(s, cs),
          _buildBalanceSummary(balance, totalPurchases, totalPaid, cs),
          _buildTabBar(cs),
          Expanded(child: _buildTabContent(cs)),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> s, ColorScheme cs) {
    final phone = s['phone'] as String? ?? '';
    final email = s['email'] as String?;
    final address = s['address'] as String?;
    final city = s['city'] as String?;
    final state = s['state'] as String?;
    final gst = s['gst_number'] as String?;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    (s['name'] as String).substring(0, 1).toUpperCase(),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: cs.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['name'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(phone, style: TextStyle(color: cs.outline, fontSize: 14)),
                      if (email != null && email.isNotEmpty)
                        Text(email, style: TextStyle(color: cs.outline, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            if (address != null && address.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 16, color: cs.outline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [address, city, state].where((e) => e != null && e.isNotEmpty).join(', '),
                      style: TextStyle(color: cs.outline, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            if (gst != null && gst.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.receipt_long, size: 16, color: cs.outline),
                  const SizedBox(width: 6),
                  Text('GST: $gst', style: TextStyle(color: cs.outline, fontSize: 13)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceSummary(double balance, double totalPurchases, double totalPaid, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _statCard('Balance Due', '₹${balance.toStringAsFixed(0)}', balance > 0 ? Colors.orange : Colors.green, cs),
            const SizedBox(width: 8),
            _statCard('Total Purchases', '₹${totalPurchases.toStringAsFixed(0)}', Colors.blue, cs),
            const SizedBox(width: 8),
            _statCard('Total Paid', '₹${totalPaid.toStringAsFixed(0)}', Colors.teal, cs),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, ColorScheme cs) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: cs.outline)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _tabButton('Purchases (${_purchases.length})', 0, cs),
          _tabButton('Payments (${_payments.length})', 1, cs),
          _tabButton('Info', 2, cs),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index, ColorScheme cs) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? cs.onPrimary : cs.outline,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(ColorScheme cs) {
    switch (_selectedTab) {
      case 0:
        return _buildPurchasesTab(cs);
      case 1:
        return _buildPaymentsTab(cs);
      case 2:
        return _buildInfoTab(cs);
      default:
        return const SizedBox();
    }
  }

  Widget _buildPurchasesTab(ColorScheme cs) {
    if (_purchases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text('No purchases yet', style: TextStyle(color: cs.outline)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _purchases.length,
      itemBuilder: (context, index) {
        final purchase = _purchases[index];
        final total = (purchase['total_amount'] as num?)?.toDouble() ?? 0;
        final balance = (purchase['balance_amount'] as num?)?.toDouble() ?? 0;
        final status = purchase['status'] as String;
        final dateStr = purchase['purchase_date'] as String;
        final date = DateTime.tryParse(dateStr);
        final purNo = purchase['purchase_number'] as String? ?? '';

        final statusColor = status == 'paid' ? Colors.green : status == 'partially_paid' ? Colors.orange : Colors.red;
        final statusText = status == 'paid' ? 'Paid' : status == 'partially_paid' ? 'Partial' : 'Due';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(purNo, style: TextStyle(fontSize: 11, color: cs.outline, fontWeight: FontWeight.w500)),
                    ),
                    Text(
                      date != null ? DateFormat('dd MMM yyyy').format(date) : dateStr,
                      style: TextStyle(fontSize: 11, color: cs.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                    ),
                    const Spacer(),
                    Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    if (balance > 0) ...[
                      const SizedBox(width: 8),
                      Text('Due ₹${balance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentsTab(ColorScheme cs) {
    if (_payments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text('No payments yet', style: TextStyle(color: cs.outline)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final payment = _payments[index];
        final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
        final mode = payment['payment_mode'] as String? ?? 'cash';
        final dateStr = payment['payment_date'] as String;
        final date = DateTime.tryParse(dateStr);
        final ref = payment['reference_number'] as String?;

        final modeIcon = mode == 'cash' ? Icons.money : mode == 'upi' ? Icons.phone_android : Icons.account_balance;
        final modeLabel = mode.toUpperCase();

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.1),
              child: Icon(modeIcon, color: Colors.orange, size: 20),
            ),
            title: Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.orange)),
            subtitle: Text('$modeLabel${ref != null ? ' • $ref' : ''}', style: const TextStyle(fontSize: 12)),
            trailing: Text(
              date != null ? DateFormat('dd MMM yy').format(date) : dateStr,
              style: TextStyle(fontSize: 12, color: cs.outline),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTab(ColorScheme cs) {
    final s = _supplier!;
    final createdAt = s['created_at'] as String?;
    final createdDate = createdAt != null ? DateTime.tryParse(createdAt) : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoRow('Phone', s['phone'] as String? ?? '-', Icons.phone),
        if (s['whatsapp_phone'] != null && (s['whatsapp_phone'] as String).isNotEmpty)
          _infoRow('WhatsApp', s['whatsapp_phone'] as String, Icons.chat),
        if (s['email'] != null && (s['email'] as String).isNotEmpty)
          _infoRow('Email', s['email'] as String, Icons.email),
        if (s['address'] != null && (s['address'] as String).isNotEmpty)
          _infoRow('Address', s['address'] as String, Icons.location_on),
        if (s['city'] != null && (s['city'] as String).isNotEmpty)
          _infoRow('City', s['city'] as String, Icons.location_city),
        if (s['state'] != null && (s['state'] as String).isNotEmpty)
          _infoRow('State', s['state'] as String, Icons.map),
        if (s['pincode'] != null && (s['pincode'] as String).isNotEmpty)
          _infoRow('Pincode', s['pincode'] as String, Icons.pin_drop),
        if (s['gst_number'] != null && (s['gst_number'] as String).isNotEmpty)
          _infoRow('GST Number', s['gst_number'] as String, Icons.receipt_long),
        _infoRow('Opening Balance', '₹${(s['opening_balance'] as num?)?.toDouble().toStringAsFixed(0) ?? '0'}', Icons.account_balance_wallet),
        if (s['notes'] != null && (s['notes'] as String).isNotEmpty)
          _infoRow('Notes', s['notes'] as String, Icons.notes),
        if (createdDate != null)
          _infoRow('Added On', DateFormat('dd MMM yyyy').format(createdDate), Icons.calendar_today),
      ],
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        context.push('/suppliers/${widget.supplierId}/edit').then((_) => _loadData());
        break;
      case 'call':
        final phone = _supplier?['phone'] as String? ?? '';
        if (phone.isNotEmpty) launchUrl(Uri.parse('tel:$phone'));
        break;
      case 'whatsapp':
        final phone = _supplier?['whatsapp_phone'] as String? ?? _supplier?['phone'] as String? ?? '';
        if (phone.isNotEmpty) launchUrl(Uri.parse('https://wa.me/${phone.replaceAll(RegExp(r'[^0-9]'), '')}'));
        break;
      case 'delete':
        _deleteSupplier();
        break;
    }
  }

  Future<void> _deleteSupplier() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text('Delete "${_supplier?['name']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await Supabase.instance.client.from('suppliers').delete().eq('id', widget.supplierId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Supplier deleted'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
