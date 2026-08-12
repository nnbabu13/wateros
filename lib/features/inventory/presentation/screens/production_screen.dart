import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/business_helper.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _batches = [];
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
      final prodFuture = Supabase.instance.client
          .from('products')
          .select('id, name, product_type, unit, packaging_unit, conversion_quantity, current_stock, selling_price')
          .eq('business_id', bizId)
          .eq('is_active', true)
          .eq('product_type', 'finished_product')
          .order('name');
      final batchFuture = Supabase.instance.client
          .from('production_batches')
          .select('*, products!product_id(name, unit)')
          .eq('business_id', bizId)
          .order('production_date', ascending: false)
          .limit(50);
      final results = await Future.wait([prodFuture, batchFuture]);
      if (mounted) {
        setState(() {
          _products = List<Map<String, dynamic>>.from(results[0] as List);
          _batches = List<Map<String, dynamic>>.from(results[1] as List);
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
        title: const Text('Production'),
        actions: [IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh))],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.precision_manufacturing, size: 64, color: Theme.of(context).colorScheme.outline),
                              const SizedBox(height: 16),
                              Text('No finished products', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                              const SizedBox(height: 8),
                              Text('Create finished products and recipes first',
                                  style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12)),
                            ],
                          ),
                        )
                      : DefaultTabController(
                          length: 2,
                          child: Column(
                            children: [
                              const TabBar(tabs: [Tab(text: 'Capacity'), Tab(text: 'Batches')]),
                              Expanded(
                                child: TabBarView(
                                  children: [
                                    _buildCapacityTab(),
                                    _buildBatchesTab(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _startProduction(null),
        icon: const Icon(Icons.add),
        label: const Text('New Batch'),
      ),
    );
  }

  Widget _buildCapacityTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _products.length,
      itemBuilder: (context, index) => _capacityCard(_products[index]),
    );
  }

  Widget _capacityCard(Map<String, dynamic> product) {
    final name = product['name'] as String;
    final stock = (product['current_stock'] as num?)?.toDouble() ?? 0;
    final sellPrice = (product['selling_price'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _startProduction(product),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                  Text('${stock.toInt()} ${product['unit']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Sell Price: ₹$sellPrice', style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _startProduction(product),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Check Capacity & Produce'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBatchesTab() {
    if (_batches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('No production batches yet', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _batches.length,
      itemBuilder: (context, index) {
        final b = _batches[index];
        final prod = b['products'] as Map<String, dynamic>?;
        final status = b['status'] as String? ?? 'planned';
        final color = status == 'completed' ? Colors.green : status == 'cancelled' ? Colors.red : Colors.orange;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(Icons.precision_manufacturing, color: color, size: 18),
            ),
            title: Text(prod?['name'] as String? ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              '${b['actual_quantity']} / ${b['planned_quantity']} produced • ${DateFormat('dd MMM').format(DateTime.parse(b['production_date'] as String))}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
            ),
          ),
        );
      },
    );
  }

  Future<void> _startProduction(Map<String, dynamic>? product) async {
    if (product == null && _products.isNotEmpty) {
      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Select Product', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              ..._products.map((p) => ListTile(
                    title: Text(p['name'] as String),
                    subtitle: Text('${(p['current_stock'] as num?)?.toInt() ?? 0} ${p['unit']}'),
                    onTap: () => Navigator.pop(ctx, p),
                  )),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (picked != null) product = picked;
    }
    if (product == null) return;

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductionDetailScreen(
            productId: product!['id'] as String,
            productName: product['name'] as String,
          ),
        ),
      ).then((_) => _loadData());
    }
  }
}

class ProductionDetailScreen extends StatefulWidget {
  final String productId;
  final String productName;
  const ProductionDetailScreen({super.key, required this.productId, required this.productName});

  @override
  State<ProductionDetailScreen> createState() => _ProductionDetailScreenState();
}

class _ProductionDetailScreenState extends State<ProductionDetailScreen> {
  Map<String, dynamic>? _recipe;
  List<Map<String, dynamic>> _recipeItems = [];
  Map<String, dynamic>? _product;
  double _actualQty = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final prodFuture = Supabase.instance.client
          .from('products')
          .select()
          .eq('id', widget.productId)
          .single();
      final recipeFuture = Supabase.instance.client
          .from('product_recipes')
          .select()
          .eq('product_id', widget.productId)
          .eq('is_active', true)
          .maybeSingle();
      final results = await Future.wait([prodFuture, recipeFuture]);

      final prod = results[0] as Map<String, dynamic>;
      final recipe = results[1] as Map<String, dynamic>?;

      List<Map<String, dynamic>> items = [];
      if (recipe != null) {
        final itemsData = await Supabase.instance.client
            .from('recipe_items')
            .select('*, products!material_id(name, unit, current_stock, average_cost, purchase_price)')
            .eq('recipe_id', recipe['id'] as String)
            .order('sort_order');
        items = (itemsData as List).map((e) => Map<String, dynamic>.from(e)).toList();
      }

      if (mounted) {
        setState(() {
          _product = prod;
          _recipe = recipe;
          _recipeItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _calcCapacity() {
    if (_recipeItems.isEmpty) return {'probable': 0, 'limiting': 'No recipe', 'details': []};

    final details = <Map<String, dynamic>>[];
    double? minCapacity;
    String? limitingMaterial;
    final productUnit = _product?['unit'] as String? ?? 'units';

    for (final item in _recipeItems) {
      final mat = item['products'] as Map<String, dynamic>?;
      final matName = mat?['name'] as String? ?? 'Unknown';
      final matStock = (mat?['current_stock'] as num?)?.toDouble() ?? 0;
      final qtyPerUnit = (item['quantity_per_unit'] as num?)?.toDouble() ?? 0;
      final matUnit = item['unit'] as String? ?? '';

      if (qtyPerUnit > 0) {
        final capacity = matStock / qtyPerUnit;
        // Calculate the inverse for display: how many units per 1 unit of material
        final unitsPerMaterial = 1.0 / qtyPerUnit;
        details.add({
          'name': matName,
          'stock': matStock,
          'unit': matUnit,
          'qtyPerUnit': qtyPerUnit,
          'capacity': capacity,
          'unitsPerMaterial': unitsPerMaterial,
          'displayHint': '1 $matUnit → ${unitsPerMaterial.toStringAsFixed(1)} $productUnit',
        });
        if (minCapacity == null || capacity < minCapacity) {
          minCapacity = capacity;
          limitingMaterial = matName;
        }
      }
    }

    return {
      'probable': minCapacity?.floor() ?? 0,
      'limiting': limitingMaterial ?? 'N/A',
      'details': details,
    };
  }

  double _calcUnitCost() {
    double total = 0;
    for (final item in _recipeItems) {
      final mat = item['products'] as Map<String, dynamic>?;
      final avgCost = (mat?['average_cost'] as num?)?.toDouble() ??
          (mat?['purchase_price'] as num?)?.toDouble() ?? 0;
      final qty = (item['quantity_per_unit'] as num?)?.toDouble() ?? 0;
      total += qty * avgCost;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));

    final cs = Theme.of(context).colorScheme;
    final capacity = _calcCapacity();
    final probable = capacity['probable'] as int;
    final limiting = capacity['limiting'] as String;
    final details = capacity['details'] as List;
    final unitCost = _calcUnitCost();
    final sellPrice = (_product?['selling_price'] as num?)?.toDouble() ?? 0;
    final margin = sellPrice - unitCost;
    final marginPct = sellPrice > 0 ? (margin / sellPrice * 100) : 0;

    return Scaffold(
      appBar: AppBar(title: Text('Produce ${widget.productName}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: cs.primaryContainer.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('PROBABLE OUTPUT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('$probable ${_product?['unit'] ?? ''}',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 32, color: cs.primary)),
                  const SizedBox(height: 4),
                  Text('Limiting: $limiting', style: TextStyle(color: cs.outline, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (details.isNotEmpty) ...[
            Text('Capacity by Material', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...details.map((d) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: (d['capacity'] as double).floor() == probable
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      child: Text(
                        (d['capacity'] as double).floor() == probable ? '!' : '✓',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: (d['capacity'] as double).floor() == probable ? Colors.red : Colors.green,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    title: Text(d['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d['displayHint'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                        Text(
                          '${(d['stock'] as double).toStringAsFixed(1)} ${d['unit']} stock ÷ ${(d['qtyPerUnit'] as double).toStringAsFixed(4)} = ${(d['capacity'] as double).floor()} ${_product?['unit'] ?? ''}',
                          style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${(d['capacity'] as double).floor()}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: (d['capacity'] as double).floor() == probable ? Colors.red : Colors.green,
                            )),
                        if ((d['capacity'] as double).floor() == probable)
                          const Text('LIMITING', style: TextStyle(fontSize: 8, color: Colors.red, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )),
          ] else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 32),
                      const SizedBox(height: 8),
                      Text('No recipe defined', style: TextStyle(color: cs.outline)),
                      const SizedBox(height: 4),
                      Text('Add a recipe for this product first', style: TextStyle(color: cs.outline, fontSize: 12)),
                    ],
                  ),
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
                  Text('Cost & Margin', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Material Cost/Unit'),
                      Text('₹${unitCost.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Selling Price'),
                      Text('₹${sellPrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Gross Margin', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('₹${margin.toStringAsFixed(2)} (${marginPct.toStringAsFixed(1)}%)',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: margin >= 0 ? Colors.green : Colors.red)),
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
                  Text('Actual Production', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Planned: ', style: TextStyle(color: cs.outline)),
                      Text('$probable ${_product?['unit'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Actual Quantity Produced',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _actualQty = double.tryParse(v) ?? 0,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveProduction,
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Record Production'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProduction() async {
    if (_actualQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter actual quantity'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final capacity = _calcCapacity();
      final planned = capacity['probable'] as int;

      // Create batch
      final batch = await Supabase.instance.client.from('production_batches').insert({
        'business_id': bizId,
        'product_id': widget.productId,
        'recipe_id': _recipe?['id'],
        'planned_quantity': planned,
        'actual_quantity': _actualQty,
        'production_date': DateTime.now().toIso8601String().substring(0, 10),
        'status': 'completed',
      }).select().single();

      // Consume materials
      for (final item in _recipeItems) {
        final matId = item['material_id'] as String;
        final qtyPerUnit = (item['quantity_per_unit'] as num?)?.toDouble() ?? 0;
        final consumeQty = _actualQty * qtyPerUnit;

        // Record consumption
        await Supabase.instance.client.from('production_consumptions').insert({
          'batch_id': batch['id'],
          'material_id': matId,
          'planned_quantity': planned * qtyPerUnit,
          'actual_quantity': consumeQty,
        });

        // Deduct from raw material stock
        final mat = await Supabase.instance.client
            .from('products')
            .select('current_stock')
            .eq('id', matId)
            .single();
        final currentStock = (mat['current_stock'] as num?)?.toDouble() ?? 0;
        await Supabase.instance.client.from('products').update({
          'current_stock': currentStock - consumeQty,
        }).eq('id', matId);

        // Create stock movement
        await Supabase.instance.client.from('inventory_movements').insert({
          'business_id': bizId,
          'product_id': matId,
          'movement_type': 'production_consumption',
          'quantity': -consumeQty,
          'reference_type': 'production',
          'reference_id': batch['id'],
          'notes': 'Production of ${_actualQty} ${widget.productName}',
        });
      }

      // Add finished product stock
      final currentProdStock = (_product?['current_stock'] as num?)?.toDouble() ?? 0;
      await Supabase.instance.client.from('products').update({
        'current_stock': currentProdStock + _actualQty,
      }).eq('id', widget.productId);

      // Create output movement
      await Supabase.instance.client.from('inventory_movements').insert({
        'business_id': bizId,
        'product_id': widget.productId,
        'movement_type': 'production_output',
        'quantity': _actualQty,
        'reference_type': 'production',
        'reference_id': batch['id'],
        'notes': 'Production batch completed',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Production recorded: ${_actualQty.toInt()} ${widget.productName}'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
