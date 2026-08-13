import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/business_helper.dart';
import '../../../../core/utils/cash_transaction_helper.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

class _EditSaleLineItem {
  String? id; // sale_item id for existing items
  String? productId;
  String productName;
  double quantity;
  double unitPrice;
  double discountPercent;
  double gstRate;

  _EditSaleLineItem({
    this.id,
    this.productId,
    this.productName = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.discountPercent = 0,
    this.gstRate = 0,
  });

  double get discountAmount => unitPrice * quantity * discountPercent / 100;
  double get taxableAmount => (unitPrice * quantity) - discountAmount;
  double get gstAmount => taxableAmount * gstRate / 100;
  double get lineTotal => taxableAmount + gstAmount;
}

class _PaymentEntry {
  String mode;
  double amount;
  final TextEditingController controller;

  _PaymentEntry({this.mode = 'cash', this.amount = 0})
      : controller = TextEditingController(text: amount > 0 ? amount.toStringAsFixed(2) : '');
}

class EditSaleScreen extends ConsumerStatefulWidget {
  final String saleId;

  const EditSaleScreen({super.key, required this.saleId});

  @override
  ConsumerState<EditSaleScreen> createState() => _EditSaleScreenState();
}

class _EditSaleScreenState extends ConsumerState<EditSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchProductController = TextEditingController();
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filteredProducts = [];
  Map<String, dynamic>? _selectedCustomer;
  List<_EditSaleLineItem> _lineItems = [];
  List<_PaymentEntry> _paymentEntries = [];
  DateTime _invoiceDate = DateTime.now();
  bool _isLoading = false;
  bool _isLoadingData = true;
  int _productPickerIndex = -1;

  // Original sale data for reversal
  Map<String, dynamic>? _originalSale;
  List<Map<String, dynamic>> _originalItems = [];
  List<Map<String, dynamic>> _originalPayments = [];

  @override
  void initState() {
    super.initState();
    _loadSaleAndData();
  }

  Future<void> _loadSaleAndData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoadingData = false);
        return;
      }

      final businessId = await BusinessHelper.getOrCreateBusinessId();

      // Load sale, items, payments, customers, and products in parallel
      final saleFuture = Supabase.instance.client
          .from('sales')
          .select()
          .eq('id', widget.saleId)
          .single();

      final itemsFuture = Supabase.instance.client
          .from('sale_items')
          .select()
          .eq('sale_id', widget.saleId);

      final paymentsFuture = Supabase.instance.client
          .from('payments')
          .select()
          .eq('sale_id', widget.saleId);

      final customersFuture = Supabase.instance.client
          .from('customers')
          .select('id, name, phone, current_balance')
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('name');

      final productsFuture = Supabase.instance.client
          .from('products')
          .select('id, name, sku, selling_price, purchase_price, gst_rate, current_stock, unit')
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('name');

      final results = await Future.wait<dynamic>([saleFuture, itemsFuture, paymentsFuture, customersFuture, productsFuture]);

      final saleData = results[0] as Map<String, dynamic>;
      final itemsData = List<Map<String, dynamic>>.from(results[1] as List);
      final paymentsData = List<Map<String, dynamic>>.from(results[2] as List);
      final customersData = List<Map<String, dynamic>>.from(results[3] as List);
      final productsData = List<Map<String, dynamic>>.from(results[4] as List);

      // Parse original sale
      _originalSale = saleData;
      _originalItems = itemsData;
      _originalPayments = paymentsData;

      // Populate form from existing sale
      final customerId = saleData['customer_id'] as String?;
      final matchedCustomers = customersData.where((c) => c['id'] == customerId).toList();
      _selectedCustomer = customerId != null && matchedCustomers.isNotEmpty
          ? matchedCustomers.first
          : null;

      _invoiceDate = DateTime.parse(saleData['invoice_date'] as String);
      _notesController.text = saleData['notes'] as String? ?? '';

      // Populate payment entries from existing payments
      if (paymentsData.isNotEmpty) {
        _paymentEntries = paymentsData.map((p) {
          return _PaymentEntry(
            mode: p['payment_mode'] as String? ?? 'cash',
            amount: (p['amount'] as num?)?.toDouble() ?? 0,
          );
        }).toList();
      } else {
        // Fallback: use sale's paid_amount with its payment_mode
        final paidAmount = (saleData['paid_amount'] as num?)?.toDouble() ?? 0;
        final paymentMode = saleData['payment_mode'] as String? ?? 'cash';
        _paymentEntries = [_PaymentEntry(mode: paymentMode, amount: paidAmount)];
      }

      // Populate line items from existing sale items
      _lineItems = itemsData.map((item) {
        final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0;
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
        final discountAmount = (item['discount_amount'] as num?)?.toDouble() ?? 0;
        // Calculate discount percent from amount
        final discountPercent = unitPrice * quantity > 0
            ? (discountAmount / (unitPrice * quantity)) * 100
            : 0.0;

        return _EditSaleLineItem(
          id: item['id'] as String?,
          productId: item['product_id'] as String?,
          productName: item['product_name'] as String? ?? '',
          quantity: quantity,
          unitPrice: unitPrice,
          discountPercent: discountPercent,
          gstRate: (item['gst_rate'] as num?)?.toDouble() ?? 0,
        );
      }).toList();

      if (_lineItems.isEmpty) {
        _lineItems.add(_EditSaleLineItem());
      }

      if (mounted) {
        setState(() {
          _customers = customersData;
          _allProducts = productsData;
          _filteredProducts = _allProducts;
          _isLoadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingData = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load sale: $e')),
        );
      }
    }
  }

  void _filterProducts(String query) {
    setState(() {
      _filteredProducts = _allProducts.where((p) {
        final name = (p['name'] as String? ?? '').toLowerCase();
        final sku = (p['sku'] as String? ?? '').toLowerCase();
        final q = query.toLowerCase();
        return name.contains(q) || sku.contains(q);
      }).toList();
    });
  }

  void _addLineItem() {
    setState(() => _lineItems.add(_EditSaleLineItem()));
  }

  void _removeLineItem(int index) {
    if (_lineItems.length > 1) {
      setState(() => _lineItems.removeAt(index));
    }
  }

  void _selectProduct(int lineIndex, Map<String, dynamic> product) {
    setState(() {
      _lineItems[lineIndex].productId = product['id'] as String;
      _lineItems[lineIndex].productName = product['name'] as String;
      _lineItems[lineIndex].unitPrice =
          (product['selling_price'] as num?)?.toDouble() ?? 0;
      _lineItems[lineIndex].gstRate =
          (product['gst_rate'] as num?)?.toDouble() ?? 0;
      _productPickerIndex = -1;
      _searchProductController.clear();
      _filteredProducts = _allProducts;
    });
  }

  double get _subtotal =>
      _lineItems.fold(0, (sum, item) => sum + item.unitPrice * item.quantity);

  double get _totalDiscount =>
      _lineItems.fold(0, (sum, item) => sum + item.discountAmount);

  double get _totalGst =>
      _lineItems.fold(0, (sum, item) => sum + item.gstAmount);

  double get _grandTotal =>
      _lineItems.fold(0, (sum, item) => sum + item.lineTotal);

  double get _totalPaid => _paymentEntries.fold(0, (sum, e) {
    final amt = double.tryParse(e.controller.text) ?? 0;
    return sum + amt;
  });

  String get _primaryPaymentMode {
    if (_paymentEntries.isEmpty) return 'cash';
    final validEntries = _paymentEntries.where((e) {
      final amt = double.tryParse(e.controller.text) ?? 0;
      return amt > 0;
    }).toList();
    if (validEntries.isEmpty) return 'cash';
    if (validEntries.length == 1) return validEntries.first.mode;
    return 'multiple';
  }

  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final prefix = 'INV';
    final counter = now.millisecondsSinceEpoch % 1000000;
    return '$prefix-${counter.toString().padLeft(6, '0')}';
  }

  Future<void> _updateSale() async {
    final validItems =
        _lineItems.where((item) => item.productId != null && item.quantity > 0).toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product')),
      );
      return;
    }

    final paidAmount = _totalPaid;

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final businessId = await BusinessHelper.getOrCreateBusinessId();
      final client = Supabase.instance.client;

      // Resolve customer
      String customerId;
      if (_selectedCustomer != null) {
        customerId = _selectedCustomer!['id'] as String;
      } else {
        var walkIn = await client
            .from('customers')
            .select('id')
            .eq('business_id', businessId)
            .eq('name', 'Walk-in')
            .eq('is_active', true)
            .maybeSingle();
        if (walkIn == null) {
          walkIn = await client
              .from('customers')
              .insert({
                'business_id': businessId,
                'name': 'Walk-in',
                'phone': '0000000000',
                'is_active': true,
              })
              .select('id')
              .single();
        }
        customerId = walkIn['id'] as String;
      }

      // === STEP 1: Reverse original sale effects ===
      // 1a. Restore inventory for original items
      for (final item in _originalItems) {
        final productId = item['product_id'] as String?;
        final quantity = (item['quantity'] as num?)?.toDouble() ?? 0;
        if (productId != null && quantity > 0) {
          try {
            final product = await client
                .from('products')
                .select('product_type, current_stock')
                .eq('id', productId)
                .single();
            final productType = product['product_type'] as String? ?? '';
            if (productType == 'finished_product') {
              final currentStock = (product['current_stock'] as num?)?.toDouble() ?? 0;
              await client.from('products').update({
                'current_stock': currentStock + quantity,
              }).eq('id', productId);
            }
          } catch (_) {}
        }
      }

      // 1b. Delete original inventory movements
      await client.from('inventory_movements')
          .delete()
          .eq('reference_type', 'sale')
          .eq('reference_id', widget.saleId);

      // 1c. Delete original payments
      await client.from('payments').delete().eq('sale_id', widget.saleId);

      // 1d. Delete original cash transactions (both legacy sale.id and new payment.id references)
      await CashTransactionHelper.deleteAllForSale(widget.saleId);
      // Also delete any legacy references where reference_id = sale.id
      await client.from('cash_transactions')
          .delete()
          .eq('reference_type', 'sale')
          .eq('reference_id', widget.saleId);

      // 1e. Reverse bank account balance and delete bank transactions (all originals)
      final origBankTxns = await client
          .from('bank_transactions')
          .select('bank_account_id, amount')
          .eq('reference_type', 'sale')
          .eq('reference_id', widget.saleId);
      for (final txn in origBankTxns) {
        final accId = txn['bank_account_id'] as String?;
        final amt = (txn['amount'] as num?)?.toDouble() ?? 0;
        if (accId != null && amt > 0) {
          try {
            final acc = await client
                .from('bank_accounts')
                .select('balance')
                .eq('id', accId)
                .single();
            final currentBal = (acc['balance'] as num?)?.toDouble() ?? 0;
            await client.from('bank_accounts').update({
              'balance': currentBal - amt,
            }).eq('id', accId);
          } catch (_) {}
        }
      }
      await client.from('bank_transactions')
          .delete()
          .eq('reference_type', 'sale')
          .eq('reference_id', widget.saleId);

      // 1f. Delete original sale items
      await client.from('sale_items').delete().eq('sale_id', widget.saleId);

      // === STEP 2: Update the sale record ===
      String status;
      if (paidAmount >= _grandTotal) {
        status = 'paid';
      } else if (paidAmount > 0) {
        status = 'partially_paid';
      } else {
        status = 'pending';
      }

      final saleUpdateData = {
        'customer_id': customerId,
        'invoice_date': DateFormat('yyyy-MM-dd').format(_invoiceDate),
        'subtotal': _subtotal,
        'discount_amount': _totalDiscount,
        'discount_percent': 0,
        'tax_amount': _totalGst,
        'total_amount': _grandTotal,
        'paid_amount': paidAmount,
        'balance_amount': _grandTotal - paidAmount,
        'payment_mode': _primaryPaymentMode,
        'status': status,
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
      };

      await client.from('sales').update(saleUpdateData).eq('id', widget.saleId);

      // === STEP 3: Apply new line items ===
      for (final item in validItems) {
        final itemData = {
          'sale_id': widget.saleId,
          'product_id': item.productId,
          'product_name': item.productName,
          'quantity': item.quantity,
          'unit_price': item.unitPrice,
          'discount_amount': item.discountAmount,
          'gst_rate': item.gstRate,
          'gst_amount': item.gstAmount,
          'total_amount': item.lineTotal,
        };
        await client.from('sale_items').insert(itemData);
      }

      // === STEP 4: Apply new financial records ===
      for (final entry in _paymentEntries) {
        final amt = double.tryParse(entry.controller.text) ?? 0;
        if (amt <= 0) continue;

        final mode = entry.mode;

        // Create payment record and capture its ID
        final paymentResponse = await client
            .from('payments')
            .insert({
              'business_id': businessId,
              'customer_id': customerId,
              'sale_id': widget.saleId,
              'amount': amt,
              'payment_mode': mode,
              'payment_date': DateFormat('yyyy-MM-dd').format(_invoiceDate),
            })
            .select()
            .single();
        final paymentId = paymentResponse['id'] as String;

        // Create financial transactions based on mode
        if (mode == 'cash') {
          await CashTransactionHelper.recordCashIn(
            businessId: businessId,
            amount: amt,
            referenceType: 'sale',
            referenceId: paymentId,
            description: 'Sale ${_originalSale!['invoice_number'] ?? ''}',
            transactionDate: _invoiceDate,
          );
        } else if (mode == 'upi' || mode == 'bank_transfer') {
          final bankAccounts = await client
              .from('bank_accounts')
              .select('id')
              .eq('business_id', businessId)
              .eq('is_active', true)
              .limit(1);
          if (bankAccounts.isNotEmpty) {
            final accId = bankAccounts[0]['id'] as String;
            final acc = await client
                .from('bank_accounts')
                .select('balance')
                .eq('id', accId)
                .single();
            final currentBal = (acc['balance'] as num?)?.toDouble() ?? 0;
            await client
                .from('bank_accounts')
                .update({'balance': currentBal + amt})
                .eq('id', accId);

            await client.from('bank_transactions').insert({
              'business_id': businessId,
              'bank_account_id': accId,
              'transaction_type': 'in',
              'amount': amt,
              'reference_type': 'sale',
              'reference_id': widget.saleId,
              'description': 'Sale ${_originalSale!['invoice_number'] ?? ''} (${mode.toUpperCase()})',
              'transaction_date': DateFormat('yyyy-MM-dd').format(_invoiceDate),
            });
          }
        }
      }

      // === STEP 5: Recalculate customer balance ===
      if (customerId.isNotEmpty) {
        try {
          final remainingSales = await client
              .from('sales')
              .select('balance_amount')
              .eq('customer_id', customerId);
          double totalDue = 0;
          for (final s in remainingSales) {
            totalDue += (s['balance_amount'] as num?)?.toDouble() ?? 0;
          }
          await client.from('customers').update({
            'current_balance': totalDue,
          }).eq('id', customerId);
        } catch (_) {}
      }

      if (mounted) {
        ref.read(dashboardRefreshProvider.notifier).state++;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update sale: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddProductDialog(int lineIndex) async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final gstCtrl = TextEditingController(text: '0');
    final stockCtrl = TextEditingController(text: '0');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Product Name *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Selling Price *',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: gstCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'GST %',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Stock',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Name and price are required')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) throw Exception('Not logged in');

        final businessId = await BusinessHelper.getOrCreateBusinessId();

        final newProduct = await Supabase.instance.client
            .from('products')
            .insert({
              'business_id': businessId,
              'name': nameCtrl.text.trim(),
              'selling_price': double.parse(priceCtrl.text),
              'gst_rate': double.tryParse(gstCtrl.text) ?? 0,
              'current_stock': double.tryParse(stockCtrl.text) ?? 0,
              'unit': 'pcs',
              'is_active': true,
            })
            .select()
            .single();

        setState(() {
          _allProducts.add(newProduct);
          _filteredProducts = _allProducts;
          _lineItems[lineIndex].productId = newProduct['id'] as String;
          _lineItems[lineIndex].productName = newProduct['name'] as String;
          _lineItems[lineIndex].unitPrice =
              (newProduct['selling_price'] as num?)?.toDouble() ?? 0;
          _lineItems[lineIndex].gstRate =
              (newProduct['gst_rate'] as num?)?.toDouble() ?? 0;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product added!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add product: $e')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _searchProductController.dispose();
    _notesController.dispose();
    for (final entry in _paymentEntries) {
      entry.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_originalSale != null
            ? 'Edit ${_originalSale!['invoice_number'] ?? 'Sale'}'
            : 'Edit Sale'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCustomerSection(cs),
                  const SizedBox(height: 16),
                  _buildDateSection(cs),
                  const SizedBox(height: 16),
                  _buildProductsSection(cs),
                  const SizedBox(height: 16),
                  _buildSummarySection(cs),
                  const SizedBox(height: 16),
                  _buildPaymentSection(cs),
                  const SizedBox(height: 16),
                  _buildNotesSection(cs),
                  const SizedBox(height: 24),
                  _buildSaveButton(cs),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildCustomerSection(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('Customer',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.push('/customers/add'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedCustomer?['id'] as String?,
              isExpanded: true,
              decoration: const InputDecoration(
                hintText: 'Select customer...',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Walk-in (No customer)')),
                ..._customers.map((c) => DropdownMenuItem(
                      value: c['id'] as String,
                      child: Text('${c['name']} - ${c['phone'] ?? ''}'),
                    )),
              ],
              onChanged: (v) {
                setState(() {
                  _selectedCustomer = v != null ? _customers.firstWhere((c) => c['id'] == v) : null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection(ColorScheme cs) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.calendar_today, color: cs.primary),
        title: const Text('Invoice Date'),
        subtitle: Text(DateFormat('dd MMM yyyy').format(_invoiceDate)),
        trailing: const Icon(Icons.edit_calendar),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _invoiceDate,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now(),
          );
          if (picked != null) setState(() => _invoiceDate = picked);
        },
      ),
    );
  }

  Widget _buildProductsSection(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('Products',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    if (_lineItems.isNotEmpty) {
                      _showAddProductDialog(_lineItems.length - 1);
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Product'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(_lineItems.length, (index) =>
                _buildLineItem(index, cs)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addLineItem,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ),
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
        border: Border.all(color: cs.outline.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: item.productId != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.productName,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  item.productId = null;
                                  item.productName = '';
                                  item.unitPrice = 0;
                                  item.gstRate = 0;
                                });
                                _showProductPicker(index);
                              },
                              child: const Icon(Icons.swap_horiz, size: 18),
                            ),
                          ],
                        ),
                      )
                    : InkWell(
                        onTap: () => _showProductPicker(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: cs.outline.withOpacity(0.4)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search, size: 18, color: cs.onSurface.withOpacity(0.5)),
                              const SizedBox(width: 8),
                              Text(
                                'Select product...',
                                style: TextStyle(
                                    color: cs.onSurface.withOpacity(0.5)),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              if (_lineItems.length > 1)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
                  onPressed: () => _removeLineItem(index),
                ),
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
                      Text('Qty',
                          style: Theme.of(context).textTheme.bodySmall),
                      TextFormField(
                        initialValue: item.quantity.toString(),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                        ],
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          setState(() {
                            item.quantity = double.tryParse(val) ?? 1;
                          });
                        },
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
                      Text('Price',
                          style: Theme.of(context).textTheme.bodySmall),
                      TextFormField(
                        initialValue: item.unitPrice.toStringAsFixed(2),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                        ],
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          isDense: true,
                          prefixText: '₹ ',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          setState(() {
                            item.unitPrice = double.tryParse(val) ?? 0;
                          });
                        },
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
                      Text('Disc %',
                          style: Theme.of(context).textTheme.bodySmall),
                      TextFormField(
                        initialValue: item.discountPercent.toStringAsFixed(0),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          isDense: true,
                          suffixText: '%',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          setState(() {
                            item.discountPercent =
                                double.tryParse(val) ?? 0;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GST %',
                          style: Theme.of(context).textTheme.bodySmall),
                      TextFormField(
                        initialValue: item.gstRate.toStringAsFixed(0),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          isDense: true,
                          suffixText: '%',
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          setState(() {
                            item.gstRate = double.tryParse(val) ?? 0;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total',
                            style: Theme.of(context).textTheme.bodySmall),
                        Text(
                          '₹ ${item.lineTotal.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
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
    _productPickerIndex = lineIndex;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _EditProductPickerSheet(
        products: _allProducts,
        onSelect: (product) {
          Navigator.pop(ctx);
          _selectProduct(lineIndex, product);
        },
        onAddNew: () {
          Navigator.pop(ctx);
          _showAddProductDialog(lineIndex);
        },
      ),
    );
  }

  Widget _buildSummarySection(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow('Subtotal', _subtotal, cs),
            if (_totalDiscount > 0)
              _summaryRow('Discount', -_totalDiscount, cs, isDiscount: true),
            if (_totalGst > 0) _summaryRow('GST', _totalGst, cs),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                Text(
                  '₹ ${_grandTotal.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double amount, ColorScheme cs,
      {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            '${isDiscount ? '-' : ''}₹ ${amount.abs().toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(ColorScheme cs) {
    final totalPaid = _totalPaid;
    final balance = _grandTotal - totalPaid;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('Payment',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                const Spacer(),
                Text(
                  'Paid: ₹ ${totalPaid.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: totalPaid >= _grandTotal ? Colors.green : cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(_paymentEntries.length, (index) =>
                _buildPaymentEntry(index, cs)),
            const SizedBox(height: 8),
            if (balance > 0)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _paymentEntries.add(_PaymentEntry());
                    });
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Payment Method'),
                ),
              ),
            if (balance <= 0 && totalPaid > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Fully paid',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentEntry(int index, ColorScheme cs) {
    final entry = _paymentEntries[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'cash', label: Text('Cash'), icon: Icon(Icons.money, size: 16)),
                    ButtonSegment(value: 'upi', label: Text('UPI'), icon: Icon(Icons.qr_code, size: 16)),
                    ButtonSegment(value: 'bank_transfer', label: Text('Bank'), icon: Icon(Icons.account_balance, size: 16)),
                  ],
                  selected: {entry.mode},
                  onSelectionChanged: (sel) {
                    setState(() => entry.mode = sel.first);
                  },
                ),
              ),
              if (_paymentEntries.length > 1)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
                  onPressed: () {
                    setState(() {
                      entry.controller.dispose();
                      _paymentEntries.removeAt(index);
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: entry.controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
            ],
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixText: '₹ ',
              border: const OutlineInputBorder(),
              suffixText: 'of ₹ ${_grandTotal.toStringAsFixed(2)}',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(ColorScheme cs) {
    return Card(
      child: TextField(
        controller: _notesController,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: 'Notes (optional)',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme cs) {
    final paidAmount = _totalPaid;
    final balance = _grandTotal - paidAmount;

    return Column(
      children: [
        if (_selectedCustomer != null && balance > 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Balance to pay: ₹ ${balance.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _updateSale,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle),
            label: Text(_isLoading ? 'Updating...' : 'Update Sale'),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EditProductPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final Function(Map<String, dynamic>) onSelect;
  final VoidCallback onAddNew;

  const _EditProductPickerSheet({
    required this.products,
    required this.onSelect,
    required this.onAddNew,
  });

  @override
  State<_EditProductPickerSheet> createState() => _EditProductPickerSheetState();
}

class _EditProductPickerSheetState extends State<_EditProductPickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products.where((p) {
      final name = (p['name'] as String? ?? '').toLowerCase();
      final sku = (p['sku'] as String? ?? '').toLowerCase();
      final q = _search.toLowerCase();
      return name.contains(q) || sku.contains(q);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (val) => setState(() => _search = val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: widget.onAddNew,
                    icon: const Icon(Icons.add),
                    tooltip: 'Add new product',
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: filtered.length,
                itemBuilder: (ctx, index) {
                  final product = filtered[index];
                  final stock = (product['current_stock'] as num?)?.toDouble() ?? 0;
                  final price = (product['selling_price'] as num?)?.toDouble() ?? 0;
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        (product['name'] as String)[0].toUpperCase(),
                      ),
                    ),
                    title: Text(product['name'] as String),
                    subtitle: Text(
                      '₹ ${price.toStringAsFixed(2)} | Stock: ${stock.toStringAsFixed(0)}',
                    ),
                    onTap: () => widget.onSelect(product),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
