import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isGridView = false;
  List<Map<String, dynamic>> _allProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final businessId = await BusinessHelper.getOrCreateBusinessId();

      final data = await Supabase.instance.client
          .from('products')
          .select()
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('name');

      if (mounted) {
        setState(() {
          _allProducts = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    if (_searchQuery.isEmpty) return _allProducts;
    final q = _searchQuery.toLowerCase();
    return _allProducts.where((p) {
      final name = (p['name'] as String? ?? '').toLowerCase();
      final sku = (p['sku'] as String? ?? '').toLowerCase();
      return name.contains(q) || sku.contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await context.push('/products/add');
              _loadProducts();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('No products found',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 16)),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await context.push('/products/add');
                                _loadProducts();
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Product'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        child: _isGridView
                            ? GridView.builder(
                                padding: const EdgeInsets.all(8.0),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 1.3,
                                  crossAxisSpacing: 8.0,
                                  mainAxisSpacing: 8.0,
                                ),
                                itemCount: _filteredProducts.length,
                                itemBuilder: (context, index) {
                                  return _buildProductGridCard(
                                      _filteredProducts[index]);
                                },
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8),
                                itemCount: _filteredProducts.length,
                                itemBuilder: (context, index) {
                                  return _buildProductListTile(
                                      _filteredProducts[index]);
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductListTile(Map<String, dynamic> product) {
    final name = product['name'] as String? ?? '';
    final sku = product['sku'] as String?;
    final price = (product['selling_price'] as num?)?.toDouble() ?? 0;
    final stock = (product['current_stock'] as num?)?.toDouble() ?? 0;
    final minStock = (product['minimum_stock'] as num?)?.toDouble() ?? 0;
    final isLow = stock <= minStock && minStock > 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: isLow
              ? Colors.red.shade50
              : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.inventory_2,
            color: isLow
                ? Colors.red
                : Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            if (sku != null && sku.isNotEmpty)
              Text('SKU: $sku', style: const TextStyle(fontSize: 12)),
            if (sku != null && sku.isNotEmpty) const SizedBox(width: 8),
            Text(
              '₹ ${price.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${stock.toStringAsFixed(0)} pcs',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isLow ? Colors.red : null,
              ),
            ),
            if (isLow)
              const Text(
                'LOW',
                style: TextStyle(fontSize: 10, color: Colors.red),
              ),
          ],
        ),
        onTap: () => context.push('/products/${product['id']}'),
      ),
    );
  }

  Widget _buildProductGridCard(Map<String, dynamic> product) {
    final name = product['name'] as String? ?? '';
    final price = (product['selling_price'] as num?)?.toDouble() ?? 0;
    final stock = (product['current_stock'] as num?)?.toDouble() ?? 0;
    final minStock = (product['minimum_stock'] as num?)?.toDouble() ?? 0;
    final isLow = stock <= minStock && minStock > 0;

    return Card(
      child: InkWell(
        onTap: () => context.push('/products/${product['id']}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2,
                size: 36,
                color: isLow
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                name,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '₹ ${price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Stock: ${stock.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 11,
                  color: isLow ? Colors.red : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
