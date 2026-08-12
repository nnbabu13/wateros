import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class _PurchaseLineItem {
  String? productId;
  String productName = '';
  double quantity = 1;
  double unitPrice = 0;
  double discountPercent = 0;
  double gstRate = 0;

  double get discountAmount => unitPrice * quantity * discountPercent / 100;
  double get taxableAmount => (unitPrice * quantity) - discountAmount;
  double get gstAmount => taxableAmount * gstRate / 100;
  double get lineTotal => taxableAmount + gstAmount;
}

class CreatePurchaseScreen extends StatefulWidget {
  const CreatePurchaseScreen({super.key});

  @override
  State<CreatePurchaseScreen> createState() => _CreatePurchaseScreenState();
}

class _CreatePurchaseScreenState extends State<CreatePurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _paidAmountController = TextEditingController(text: '0');

  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _allProducts = [];
  String? _selectedSupplierId;
  List<_PurchaseLineItem> _lineItems = [];
  String _paymentMode = 'cash';
  DateTime _purchaseDate = DateTime.now();
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _lineItems.add(_PurchaseLineItem());
  }

  Future<void> _loadData() async {
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final suppliersFuture = Supabase.instance.client
          .from('suppliers')
          .select('id, name, phone, current_balance')
          .eq('business_id', bizId)
          .eq('is_active', true)
          .order('name');
      final productsFuture = Supabase.instance.client
          .from('products')
          .select('id, name, sku, purchase_price, selling_price, gst_rate, current_stock, unit')
          .eq('business_id', bizId)
          .eq('is_active', true)
          .order('name');
      final results = await Future.wait([suppliersFuture, productsFuture]);
      if (mounted) {
        setState(() {
          _suppliers = List<Map<String, dynamic>>.from(results[0]);
          _allProducts = List<Map<String, dynamic>>.from(results[1]);
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  void _addLineItem() => setState(() => _lineItems.add(_PurchaseLineItem()));
  void _removeLineItem(int i) {
    if (_lineItems.length > 1) setState(() => _lineItems.removeAt(i));
  }

  double get _subtotal => _lineItems.fold(0, (s, i) => s + i.unitPrice * i.quantity);
  double get _totalDiscount => _lineItems.fold(0, (s, i) => s + i.discountAmount);
  double get _totalGst => _lineItems.fold(0, (s, i) => s + i.gstAmount);
  double get _grandTotal => _lineItems.fold(0, (s, i) => s + i.lineTotal);

  Future<void> _save() async {
    if (_selectedSupplierId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a supplier')),
      );
      return;
    }
    final validItems = _lineItems.where((i) => i.productId != null && i.quantity > 0).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one product')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final paidAmount = double.tryParse(_paidAmountController.text) ?? 0;
      String status;
      if (paidAmount >= _grandTotal) {
        status = 'paid';
      } else if (paidAmount > 0) {
        status = 'partially_paid';
      } else {
        status = 'pending';
      }

      final purchaseData = {
        'business_id': bizId,
        'supplier_id': _selectedSupplierId,
        'purchase_date': DateFormat('yyyy-MM-dd').format(_purchaseDate),
        'subtotal': _subtotal,
        'discount_amount': _totalDiscount,
        'tax_amount': _totalGst,
        'total_amount': _grandTotal,
        'paid_amount': paidAmount,
        'balance_amount': _grandTotal - paidAmount,
        'payment_mode': _paymentMode,
        'status': status,
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
      };

      final response = await Supabase.instance.client
          .from('purchases')
          .insert(purchaseData)
          .select()
          .single();

      for (final item in validItems) {
        await Supabase.instance.client.from('purchase_items').insert({
          'purchase_id': response['id'],
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'discount_amount': item.discountAmount,
          'gst_rate': item.gstRate,
          'gst_amount': item.gstAmount,
          'total_amount': item.lineTotal,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase created!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Stock Purchase')),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Supplier', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _showAddSupplierSheet,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('New'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedSupplierId,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              hintText: 'Select supplier...',
                              border: OutlineInputBorder(),
                            ),
                            items: _suppliers
                                .map((s) => DropdownMenuItem(
                                      value: s['id'] as String,
                                      child: Text('${s['name']} - ${s['phone'] ?? ''}'),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedSupplierId = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.inventory_2, size: 20),
                              const SizedBox(width: 8),
                              Text('Products', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: _addLineItem,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Item'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(_lineItems.length, (i) => _buildLineItem(i, cs)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _summaryRow('Subtotal', _subtotal),
                          if (_totalDiscount > 0) _summaryRow('Discount', -_totalDiscount, isNeg: true),
                          if (_totalGst > 0) _summaryRow('GST', _totalGst),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              Text('₹ ${_grandTotal.toStringAsFixed(2)}',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: cs.primary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payment', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'cash', label: Text('Cash')),
                              ButtonSegment(value: 'upi', label: Text('UPI')),
                              ButtonSegment(value: 'bank_transfer', label: Text('Bank')),
                              ButtonSegment(value: 'credit', label: Text('Credit')),
                            ],
                            selected: {_paymentMode},
                            onSelectionChanged: (s) => setState(() => _paymentMode = s.first),
                          ),
                          const SizedBox(height: 12),
                          if (_paymentMode != 'credit')
                            TextField(
                              controller: _paidAmountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Amount Paid',
                                prefixText: '₹ ',
                                border: const OutlineInputBorder(),
                                suffixText: 'of ₹ ${_grandTotal.toStringAsFixed(2)}',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _save,
                      icon: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle),
                      label: Text(_isLoading ? 'Saving...' : 'Create Purchase'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildLineItem(int index, ColorScheme cs) {
    final item = _lineItems[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: item.productId != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w500))),
                            GestureDetector(
                              onTap: () => _showProductPicker(index),
                              child: const Icon(Icons.swap_horiz, size: 18),
                            ),
                          ],
                        ),
                      )
                    : InkWell(
                        onTap: () => _showProductPicker(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: cs.outline.withOpacity(0.4)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, size: 18, color: cs.onSurface.withOpacity(0.5)),
                              const SizedBox(width: 8),
                              Text('Select product...', style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
                            ],
                          ),
                        ),
                      ),
              ),
              if (_lineItems.length > 1)
                IconButton(icon: Icon(Icons.delete_outline, color: cs.error, size: 20), onPressed: () => _removeLineItem(index)),
            ],
          ),
          if (item.productId != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Qty', style: TextStyle(fontSize: 12)),
                      TextFormField(
                        initialValue: item.quantity.toString(),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder()),
                        onChanged: (v) => setState(() => item.quantity = double.tryParse(v) ?? 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Price', style: TextStyle(fontSize: 12)),
                      TextFormField(
                        initialValue: item.unitPrice.toStringAsFixed(2),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(isDense: true, prefixText: '₹ ', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder()),
                        onChanged: (v) => setState(() => item.unitPrice = double.tryParse(v) ?? 0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Disc %', style: TextStyle(fontSize: 12)),
                      TextFormField(
                        initialValue: '0',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(isDense: true, suffixText: '%', contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder()),
                        onChanged: (v) => setState(() => item.discountPercent = double.tryParse(v) ?? 0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showProductPicker(int lineIndex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) {
          String search = '';
          return StatefulBuilder(
            builder: (ctx, setSheetState) {
              final filtered = _allProducts.where((p) {
                final name = (p['name'] as String? ?? '').toLowerCase();
                return name.contains(search.toLowerCase());
              }).toList();
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onChanged: (v) => setSheetState(() => search = v),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                        final p = filtered[i];
                        final price = (p['purchase_price'] as num?)?.toDouble() ?? 0;
                        final stock = (p['current_stock'] as num?)?.toDouble() ?? 0;
                        return ListTile(
                          leading: CircleAvatar(child: Text((p['name'] as String)[0].toUpperCase())),
                          title: Text(p['name'] as String),
                          subtitle: Text('Buy: ₹${price.toStringAsFixed(2)} | Stock: ${stock.toStringAsFixed(0)}'),
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _lineItems[lineIndex].productId = p['id'] as String;
                              _lineItems[lineIndex].productName = p['name'] as String;
                              _lineItems[lineIndex].unitPrice = price;
                              _lineItems[lineIndex].gstRate = (p['gst_rate'] as num?)?.toDouble() ?? 0;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _summaryRow(String label, double amount, {bool isNeg = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('${isNeg ? '-' : ''}₹ ${amount.abs().toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _showAddSupplierSheet() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    bool saving = false;

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Supplier', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Supplier Name *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Address (optional)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  onPressed: saving ? null : () async {
                    if (nameController.text.trim().isEmpty) return;
                    setSheetState(() => saving = true);
                    try {
                      final bizId = await BusinessHelper.getOrCreateBusinessId();
                      final data = await Supabase.instance.client
                          .from('suppliers')
                          .insert({
                            'business_id': bizId,
                            'name': nameController.text.trim(),
                            'phone': phoneController.text.trim(),
                            'email': emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                            'address': addressController.text.trim().isEmpty ? null : addressController.text.trim(),
                          })
                          .select('id, name, phone')
                          .single();
                      if (ctx.mounted) Navigator.pop(ctx, {
                        'id': data['id'] as String,
                        'name': data['name'] as String,
                        'phone': data['phone'] as String? ?? '',
                      });
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                        );
                        setSheetState(() => saving = false);
                      }
                    }
                  },
                  child: saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Supplier'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _suppliers.add(result);
        _selectedSupplierId = result['id'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result['name']} added'), backgroundColor: Colors.green),
      );
    }
  }
}
