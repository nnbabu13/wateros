import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class AddInventoryProductScreen extends StatefulWidget {
  final String? productId;
  const AddInventoryProductScreen({super.key, this.productId});

  @override
  State<AddInventoryProductScreen> createState() => _AddInventoryProductScreenState();
}

class _AddInventoryProductScreenState extends State<AddInventoryProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _stockController = TextEditingController(text: '0');
  final _minStockController = TextEditingController(text: '0');
  final _purchasePriceController = TextEditingController(text: '0');
  final _sellingPriceController = TextEditingController(text: '0');
  final _conversionQtyController = TextEditingController(text: '1');
  final _notesController = TextEditingController();

  String _productType = 'finished_product';
  String _unit = 'pcs';
  String? _packagingUnit;
  bool _isSaving = false;
  bool _isEdit = false;

  static const _units = ['pcs', 'kg', 'g', 'litre', 'ml', 'dozen', 'box', 'bag', 'roll', 'metre'];
  static const _productTypes = [
    {'value': 'raw_material', 'label': 'Raw Material'},
    {'value': 'finished_product', 'label': 'Finished Product'},
    {'value': 'packaging', 'label': 'Packaging'},
    {'value': 'reusable_asset', 'label': 'Reusable Asset'},
  ];
  static const _packagingUnits = ['box', 'case', 'carton', 'bag', 'bundle', 'pack'];

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      _isEdit = true;
      _loadProduct();
    }
  }

  Future<void> _loadProduct() async {
    try {
      final data = await Supabase.instance.client
          .from('products')
          .select()
          .eq('id', widget.productId!)
          .single();
      if (mounted) {
        setState(() {
          _nameController.text = data['name'] as String? ?? '';
          _productType = data['product_type'] as String? ?? 'finished_product';
          _unit = data['unit'] as String? ?? 'pcs';
          _packagingUnit = data['packaging_unit'] as String?;
          _stockController.text = ((data['current_stock'] as num?)?.toDouble() ?? 0).toString();
          _minStockController.text = ((data['minimum_stock'] as num?)?.toDouble() ?? 0).toString();
          _purchasePriceController.text = ((data['purchase_price'] as num?)?.toDouble() ?? 0).toString();
          _sellingPriceController.text = ((data['selling_price'] as num?)?.toDouble() ?? 0).toString();
          _conversionQtyController.text = ((data['conversion_quantity'] as num?)?.toDouble() ?? 1).toString();
          _notesController.text = data['notes'] as String? ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _conversionQtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isRawMaterial => _productType == 'raw_material' || _productType == 'packaging';

  @override
  Widget build(BuildContext context) {
    final typeLabel = _isRawMaterial ? 'Raw Material' : 'Finished Product';
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit $typeLabel' : 'Add $typeLabel'),
      ),
      body: Form(
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
                    Text('Basic Info', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _productType,
                      decoration: const InputDecoration(labelText: 'Product Type *', border: OutlineInputBorder()),
                      items: _productTypes.map((t) => DropdownMenuItem(value: t['value'], child: Text(t['label']!))).toList(),
                      onChanged: _isEdit ? null : (v) => setState(() => _productType = v ?? _productType),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: const InputDecoration(labelText: 'Unit *', border: OutlineInputBorder()),
                      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (v) => setState(() => _unit = v ?? _unit),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    if (!_isEdit)
                      TextFormField(
                        controller: _stockController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Opening Stock', border: OutlineInputBorder()),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _minStockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Minimum Stock Level', border: OutlineInputBorder()),
                    ),
                    if (!_isRawMaterial) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _packagingUnit,
                              decoration: const InputDecoration(labelText: 'Packaging Unit', border: OutlineInputBorder()),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('None')),
                                ..._packagingUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))),
                              ],
                              onChanged: (v) => setState(() => _packagingUnit = v),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _conversionQtyController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Per Case Qty',
                                border: OutlineInputBorder(),
                                helperText: 'e.g. 20 pcs per case',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pricing', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _purchasePriceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: _isRawMaterial ? 'Purchase Price (₹) *' : 'Cost Price (₹)',
                              border: const OutlineInputBorder(),
                            ),
                            validator: _isRawMaterial ? (v) {
                              final val = double.tryParse(v ?? '0') ?? 0;
                              return val <= 0 ? 'Required for raw material' : null;
                            } : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _sellingPriceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: !_isRawMaterial ? 'Selling Price (₹) *' : 'Selling Price (₹)',
                              border: const OutlineInputBorder(),
                            ),
                            validator: !_isRawMaterial ? (v) {
                              final val = double.tryParse(v ?? '0') ?? 0;
                              return val <= 0 ? 'Required for finished product' : null;
                            } : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Additional', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(_isEdit ? 'Update Product' : 'Add Product'),
              ),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _delete,
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                  child: const Text('Delete Product', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final product = {
        'business_id': bizId,
        'name': _nameController.text.trim(),
        'product_type': _productType,
        'unit': _unit,
        'packaging_unit': _packagingUnit,
        'conversion_quantity': double.tryParse(_conversionQtyController.text) ?? 1,
        'current_stock': double.tryParse(_stockController.text) ?? 0,
        'minimum_stock': double.tryParse(_minStockController.text) ?? 0,
        'purchase_price': double.tryParse(_purchasePriceController.text) ?? 0,
        'selling_price': double.tryParse(_sellingPriceController.text) ?? 0,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };

      if (_isEdit) {
        await Supabase.instance.client.from('products').update(product).eq('id', widget.productId!);
      } else {
        await Supabase.instance.client.from('products').insert(product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Product updated' : 'Product added'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: const Text('This will deactivate the product. It will no longer appear in lists.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.from('products').update({'is_active': false}).eq('id', widget.productId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product deleted'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
