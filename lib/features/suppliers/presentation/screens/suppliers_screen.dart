import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;
  String _search = '';

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
          .from('suppliers')
          .select()
          .eq('business_id', bizId)
          .order('name');
      if (mounted) setState(() { _suppliers = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered => _search.isEmpty
      ? _suppliers
      : _suppliers.where((s) => (s['name'] as String? ?? '').toLowerCase().contains(_search.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers'),
        actions: [IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh))],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search suppliers...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.business_outlined, size: 64, color: cs.outline),
                              const SizedBox(height: 16),
                              const Text('No suppliers yet'),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(onPressed: () => context.push('/suppliers/add'), icon: const Icon(Icons.add_business), label: const Text('Add Supplier')),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) => _buildSupplierCard(_filtered[index]),
                          ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/suppliers/add');
          _loadData();
        },
        icon: const Icon(Icons.add_business),
        label: const Text('Add Supplier'),
      ),
    );
  }

  Widget _buildSupplierCard(Map<String, dynamic> s) {
    final balance = (s['current_balance'] as num? ?? 0).toDouble();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.purple.withOpacity(0.1), child: const Icon(Icons.business, color: Colors.purple)),
        title: Text(s['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(s['phone'] as String? ?? ''),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (balance > 0) Text('₹${balance.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange, fontSize: 13)),
            if (s['city'] != null) Text(s['city'] as String, style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
          ],
        ),
        onTap: () => context.push('/suppliers/${s['id']}').then((_) => _loadData()),
      ),
    );
  }
}
