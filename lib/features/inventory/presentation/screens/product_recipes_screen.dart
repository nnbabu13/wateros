import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class ProductRecipesScreen extends StatefulWidget {
  const ProductRecipesScreen({super.key});

  @override
  State<ProductRecipesScreen> createState() => _ProductRecipesScreenState();
}

class _ProductRecipesScreenState extends State<ProductRecipesScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

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
          .from('products')
          .select('id, name, product_type, unit, current_stock')
          .eq('business_id', bizId)
          .eq('is_active', true)
          .eq('product_type', 'finished_product')
          .order('name');
      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Recipes'),
        actions: [IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh))],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant, size: 64, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text('No finished products', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                      const SizedBox(height: 8),
                      Text('Create finished products first', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => Navigator.pushNamed(context, '/products/add'),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Product'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _products.length,
                  itemBuilder: (context, index) {
                    final p = _products[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.withOpacity(0.1),
                          child: const Icon(Icons.restaurant, color: Colors.green, size: 18),
                        ),
                        title: Text(p['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text('${(p['current_stock'] as num?)?.toInt() ?? 0} ${p['unit']}', style: const TextStyle(fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _editRecipe(p['id'] as String, p['name'] as String),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _editRecipe(String productId, String productName) async {
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();

      var recipe = await Supabase.instance.client
          .from('product_recipes')
          .select()
          .eq('product_id', productId)
          .eq('is_active', true)
          .maybeSingle();

      if (recipe == null) {
        recipe = await Supabase.instance.client.from('product_recipes').insert({
          'business_id': bizId,
          'product_id': productId,
          'name': '$productName Recipe',
        }).select().single();
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeEditScreen(
              recipeId: recipe!['id'] as String,
              productName: productName,
            ),
          ),
        ).then((_) => _loadData());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class RecipeEditScreen extends StatefulWidget {
  final String recipeId;
  final String productName;
  const RecipeEditScreen({super.key, required this.recipeId, required this.productName});

  @override
  State<RecipeEditScreen> createState() => _RecipeEditScreenState();
}

class _RecipeEditScreenState extends State<RecipeEditScreen> {
  Map<String, dynamic>? _recipe;
  List<Map<String, dynamic>> _recipeItems = [];
  List<Map<String, dynamic>> _allMaterials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final recipeFuture = Supabase.instance.client
          .from('product_recipes')
          .select()
          .eq('id', widget.recipeId)
          .single();
      final itemsFuture = Supabase.instance.client
          .from('recipe_items')
          .select('*, products!material_id(name, unit)')
          .eq('recipe_id', widget.recipeId)
          .order('sort_order');
      final materialsFuture = Supabase.instance.client
          .from('products')
          .select('id, name, unit, product_type, average_cost, purchase_price')
          .eq('business_id', bizId)
          .eq('is_active', true)
          .inFilter('product_type', ['raw_material', 'packaging'])
          .order('name');

      final results = await Future.wait([recipeFuture, itemsFuture, materialsFuture]);
      if (mounted) {
        setState(() {
          _recipe = results[0] as Map<String, dynamic>;
          _recipeItems = (results[1] as List).map((e) => Map<String, dynamic>.from(e)).toList();
          _allMaterials = List<Map<String, dynamic>>.from(results[2] as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.productName} Recipe'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recipe for: ${widget.productName}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text('Add raw materials required to produce 1 unit of this product.',
                            style: TextStyle(color: cs.outline, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Materials', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    TextButton.icon(
                      onPressed: _addMaterial,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                if (_recipeItems.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text('No materials added yet', style: TextStyle(color: cs.outline)),
                      ),
                    ),
                  )
                else
                  ..._recipeItems.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    final matName = (item['products'] as Map<String, dynamic>?)?['name'] as String? ?? 'Unknown';
                    final matUnit = item['unit'] as String? ?? '';
                    final qty = (item['quantity_per_unit'] as num?)?.toDouble() ?? 0;
                    final matId = item['material_id'] as String;
                    final material = _allMaterials.firstWhere(
                      (m) => m['id'] == matId,
                      orElse: () => {},
                    );
                    final avgCost = (material['average_cost'] as num?)?.toDouble() ??
                        (material['purchase_price'] as num?)?.toDouble() ?? 0;
                    final lineCost = qty * avgCost;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.1),
                          child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        ),
                        title: Text(matName, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text('${qty.toStringAsFixed(3)} $matUnit × ₹${avgCost.toStringAsFixed(0)} = ₹${lineCost.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 12)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _editMaterial(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                              onPressed: () => _deleteMaterial(item['id'] as String),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                if (_recipeItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Card(
                    color: cs.primaryContainer.withOpacity(0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Estimated Cost per Unit', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            '₹${_calcTotalCost().toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: cs.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  double _calcTotalCost() {
    double total = 0;
    for (final item in _recipeItems) {
      final matId = item['material_id'] as String;
      final qty = (item['quantity_per_unit'] as num?)?.toDouble() ?? 0;
      final material = _allMaterials.firstWhere((m) => m['id'] == matId, orElse: () => {});
      final cost = (material['average_cost'] as num?)?.toDouble() ??
          (material['purchase_price'] as num?)?.toDouble() ?? 0;
      total += qty * cost;
    }
    return total;
  }

  Future<void> _addMaterial() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _MaterialPickerSheet(materials: _allMaterials),
    );
    if (picked != null) {
      try {
        await Supabase.instance.client.from('recipe_items').insert({
          'recipe_id': widget.recipeId,
          'material_id': picked['id'],
          'quantity_per_unit': picked['quantity'],
          'unit': picked['unit'],
          'sort_order': _recipeItems.length,
        });
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _editMaterial(Map<String, dynamic> item) async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _MaterialPickerSheet(
        materials: _allMaterials,
        selectedId: item['material_id'] as String,
        initialQty: (item['quantity_per_unit'] as num?)?.toDouble() ?? 0,
      ),
    );
    if (picked != null) {
      try {
        await Supabase.instance.client.from('recipe_items').update({
          'material_id': picked['id'],
          'quantity_per_unit': picked['quantity'],
          'unit': picked['unit'],
        }).eq('id', item['id'] as String);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _deleteMaterial(String itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove material?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await Supabase.instance.client.from('recipe_items').delete().eq('id', itemId);
      _loadData();
    }
  }
}

class _MaterialPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> materials;
  final String? selectedId;
  final double initialQty;

  const _MaterialPickerSheet({required this.materials, this.selectedId, this.initialQty = 0});

  @override
  State<_MaterialPickerSheet> createState() => _MaterialPickerSheetState();
}

class _MaterialPickerSheetState extends State<_MaterialPickerSheet> {
  String? _selectedId;
  final _qtyController = TextEditingController();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];
  bool _useConversion = false;
  final _conversionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedId = widget.selectedId;
    _qtyController.text = widget.initialQty > 0 ? widget.initialQty.toString() : '';
    _filtered = widget.materials;
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _searchController.dispose();
    _conversionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedMat = _selectedId != null
        ? widget.materials.firstWhere((m) => m['id'] == _selectedId, orElse: () => {})
        : null;
    final matUnit = selectedMat?['unit'] as String? ?? '';

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add Material', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(hintText: 'Search materials...', isDense: true, border: OutlineInputBorder(), prefixIcon: Icon(Icons.search, size: 18)),
            onChanged: (v) {
              setState(() {
                _filtered = widget.materials
                    .where((m) => (m['name'] as String).toLowerCase().contains(v.toLowerCase()))
                    .toList();
              });
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: _filtered.isEmpty
                ? Center(child: Text('No raw materials found', style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)))
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final m = _filtered[index];
                      final sel = m['id'] == _selectedId;
                      return ListTile(
                        dense: true,
                        selected: sel,
                        title: Text(m['name'] as String, style: const TextStyle(fontSize: 14)),
                        subtitle: Text('${m['unit']} • ₹${(m['average_cost'] as num?)?.toDouble() ?? (m['purchase_price'] as num?)?.toDouble() ?? 0}',
                            style: const TextStyle(fontSize: 11)),
                        trailing: sel ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                        onTap: () {
                          setState(() => _selectedId = m['id'] as String);
                        },
                      );
                    },
                  ),
          ),
          if (_selectedId != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(_useConversion ? 'Conversion mode' : 'Direct mode', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _useConversion ? '1 $matUnit makes X finished units' : 'Quantity of $matUnit per 1 finished unit',
                      style: const TextStyle(fontSize: 10),
                    ),
                    value: _useConversion,
                    onChanged: (v) => setState(() {
                      _useConversion = v;
                      _qtyController.clear();
                      _conversionController.clear();
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (_useConversion)
              Row(
                children: [
                  const Text('1 ', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(matUnit, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                  const Text(' makes ', style: TextStyle()),
                  Expanded(
                    child: TextField(
                      controller: _conversionController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: '# finished',
                        isDense: true,
                        border: const OutlineInputBorder(),
                        suffixText: 'units',
                      ),
                      onChanged: (v) {
                        final conversionQty = double.tryParse(v) ?? 0;
                        if (conversionQty > 0) {
                          final perUnit = 1.0 / conversionQty;
                          _qtyController.text = perUnit.toStringAsFixed(4);
                        }
                      },
                    ),
                  ),
                ],
              )
            else
              TextField(
                controller: _qtyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Quantity of $matUnit per 1 finished unit',
                  hintText: _getHintText(matUnit),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                if (_selectedId == null || _qtyController.text.isEmpty) return;
                final qty = double.tryParse(_qtyController.text) ?? 0;
                if (qty <= 0) return;
                final mat = widget.materials.firstWhere((m) => m['id'] == _selectedId);
                Navigator.pop(context, {
                  'id': _selectedId,
                  'quantity': qty,
                  'unit': mat['unit'] as String,
                });
              },
              child: const Text('Add'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _getHintText(String unit) {
    if (unit == 'kg') return 'e.g. 0.083 for 12 bags/kg';
    if (unit == 'g') return 'e.g. 83 for 12 bags/kg';
    if (unit == 'litre' || unit == 'ml') return 'e.g. 0.5 for 2 bags/litre';
    return 'e.g. 0.1';
  }
}
