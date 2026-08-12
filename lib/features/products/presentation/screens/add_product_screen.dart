import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class AddProductScreen extends StatefulWidget {
  final String? productId;

  const AddProductScreen({super.key, this.productId});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _unitController = TextEditingController(text: 'pcs');
  final _purchasePriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  final _maxStockController = TextEditingController();
  final _gstController = TextEditingController();
  final _categoryController = TextEditingController();
  final _packagingUnitController = TextEditingController();
  final _conversionQtyController = TextEditingController(text: '1');
  final _notesController = TextEditingController();

  bool get isEditing => widget.productId != null;
  bool _isLoading = false;
  bool _isActive = true;
  String? _selectedCategoryId;
  String _productType = 'finished_product';
  List<Map<String, dynamic>> _categories = [];
  String _businessId = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _businessId = await BusinessHelper.getOrCreateBusinessId();

      final cats = await Supabase.instance.client
          .from('product_categories')
          .select('id, name')
          .eq('business_id', _businessId)
          .order('name');

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(cats);
        });
      }

      if (isEditing) {
        await _loadProduct();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load: $e')),
        );
      }
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
          _skuController.text = data['sku'] as String? ?? '';
          _barcodeController.text = data['barcode'] as String? ?? '';
          _descriptionController.text = data['description'] as String? ?? '';
          _unitController.text = data['unit'] as String? ?? 'pcs';
          _purchasePriceController.text =
              (data['purchase_price'] as num?)?.toString() ?? '';
          _sellingPriceController.text =
              (data['selling_price'] as num?)?.toString() ?? '';
          _stockController.text =
              (data['current_stock'] as num?)?.toString() ?? '';
          _minStockController.text =
              (data['minimum_stock'] as num?)?.toString() ?? '';
          _maxStockController.text =
              (data['maximum_stock'] as num?)?.toString() ?? '';
          _gstController.text =
              (data['gst_rate'] as num?)?.toString() ?? '';
          _selectedCategoryId = data['category_id'] as String?;
          _isActive = data['is_active'] as bool? ?? true;
          _productType = data['product_type'] as String? ?? 'finished_product';
          _packagingUnitController.text = data['packaging_unit'] as String? ?? '';
          _conversionQtyController.text = (data['conversion_quantity'] as num?)?.toString() ?? '1';
          _notesController.text = data['notes'] as String? ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load product: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_businessId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business profile not found. Please go back and try again.')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final data = {
        'business_id': _businessId,
        'name': _nameController.text.trim(),
        'sku': _skuController.text.isEmpty ? null : _skuController.text.trim(),
        'barcode':
            _barcodeController.text.isEmpty ? null : _barcodeController.text.trim(),
        'description':
            _descriptionController.text.isEmpty ? null : _descriptionController.text.trim(),
        'unit': _unitController.text.trim().isEmpty ? 'pcs' : _unitController.text.trim(),
        'purchase_price': double.tryParse(_purchasePriceController.text) ?? 0,
        'selling_price': double.tryParse(_sellingPriceController.text) ?? 0,
        'gst_rate': double.tryParse(_gstController.text) ?? 0,
        'current_stock': double.tryParse(_stockController.text) ?? 0,
        'minimum_stock': double.tryParse(_minStockController.text) ?? 0,
        'maximum_stock': double.tryParse(_maxStockController.text) ?? 0,
        'category_id': _selectedCategoryId,
        'is_active': _isActive,
        'product_type': _productType,
        'packaging_unit': _packagingUnitController.text.isEmpty ? null : _packagingUnitController.text.trim(),
        'conversion_quantity': double.tryParse(_conversionQtyController.text) ?? 1,
        'notes': _notesController.text.isEmpty ? null : _notesController.text.trim(),
      };

      if (isEditing) {
        await Supabase.instance.client
            .from('products')
            .update(data)
            .eq('id', widget.productId!);
      } else {
        await Supabase.instance.client.from('products').insert(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Product updated!' : 'Product added!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    _unitController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _maxStockController.dispose();
    _gstController.dispose();
    _categoryController.dispose();
    _packagingUnitController.dispose();
    _conversionQtyController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Product' : 'Add Product'),
        actions: [
          if (isEditing)
            IconButton(
              icon: Icon(_isActive ? Icons.visibility : Icons.visibility_off),
              tooltip: _isActive ? 'Active' : 'Inactive',
              onPressed: () => setState(() => _isActive = !_isActive),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _productType,
              decoration: const InputDecoration(
                labelText: 'Product Type *',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'finished_product', child: Text('Finished Product')),
                DropdownMenuItem(value: 'raw_material', child: Text('Raw Material')),
                DropdownMenuItem(value: 'packaging', child: Text('Packaging Material')),
                DropdownMenuItem(value: 'reusable_asset', child: Text('Reusable Asset')),
              ],
              onChanged: (val) => setState(() => _productType = val ?? 'finished_product'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a product name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _skuController,
                    decoration: const InputDecoration(
                      labelText: 'SKU',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    decoration: const InputDecoration(
                      labelText: 'Barcode',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _unitController.text.isEmpty ? 'pcs' : _unitController.text,
                    decoration: const InputDecoration(
                      labelText: 'Unit *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'pcs', child: Text('Pieces (pcs)')),
                      DropdownMenuItem(value: 'kg', child: Text('Kilograms (kg)')),
                      DropdownMenuItem(value: 'g', child: Text('Grams (g)')),
                      DropdownMenuItem(value: 'litre', child: Text('Litres')),
                      DropdownMenuItem(value: 'ml', child: Text('Millilitres (ml)')),
                      DropdownMenuItem(value: 'dozen', child: Text('Dozen')),
                      DropdownMenuItem(value: 'box', child: Text('Box')),
                      DropdownMenuItem(value: 'bag', child: Text('Bag')),
                      DropdownMenuItem(value: 'roll', child: Text('Roll')),
                      DropdownMenuItem(value: 'metre', child: Text('Metre')),
                    ],
                    onChanged: (val) => setState(() => _unitController.text = val ?? 'pcs'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('None')),
                      ..._categories.map((c) => DropdownMenuItem(
                            value: c['id'] as String,
                            child: Text(c['name'] as String),
                          )),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedCategoryId = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _purchasePriceController,
                    decoration: InputDecoration(
                      labelText: _productType == 'finished_product' ? 'Cost Price' : 'Purchase Price *',
                      border: const OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (_productType != 'finished_product') {
                        if (value == null || value.isEmpty) return 'Required';
                        if (double.tryParse(value) == null) return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _sellingPriceController,
                    decoration: InputDecoration(
                      labelText: _productType == 'finished_product' ? 'Selling Price *' : 'Selling Price',
                      border: const OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (_productType == 'finished_product') {
                        if (value == null || value.isEmpty) return 'Required';
                        if (double.tryParse(value) == null) return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    decoration: const InputDecoration(
                      labelText: 'Current Stock',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _minStockController,
                    decoration: const InputDecoration(
                      labelText: 'Min Stock',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _maxStockController,
                    decoration: const InputDecoration(
                      labelText: 'Max Stock',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _gstController,
                    decoration: const InputDecoration(
                      labelText: 'GST (%)',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _packagingUnitController,
                    decoration: const InputDecoration(
                      labelText: 'Packaging Unit',
                      hintText: 'CASE, BOTTLE, BOX',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _conversionQtyController,
                    decoration: const InputDecoration(
                      labelText: 'Conversion Qty',
                      hintText: 'pcs per case',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEditing ? 'Update Product' : 'Save Product'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
