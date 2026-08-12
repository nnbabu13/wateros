import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/business_helper.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';

class StockMovementsScreen extends ConsumerStatefulWidget {
  const StockMovementsScreen({super.key});

  @override
  ConsumerState<StockMovementsScreen> createState() => _StockMovementsScreenState();
}

class _StockMovementsScreenState extends ConsumerState<StockMovementsScreen> {
  List<Map<String, dynamic>> _movements = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref.listen<int>(dashboardRefreshProvider, (_, __) => _loadData());
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final bizId = await BusinessHelper.getOrCreateBusinessId();
      final data = await Supabase.instance.client
          .from('inventory_movements')
          .select('*, products(name, unit)')
          .eq('business_id', bizId)
          .order('created_at', ascending: false)
          .limit(200);
      if (mounted) {
        setState(() {
          _movements = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter == 'all'
        ? _movements
        : _movements.where((m) => m['movement_type'] == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Movements'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      _filterChip('All', 'all'),
                      const SizedBox(width: 6),
                      _filterChip('In', 'in'),
                      const SizedBox(width: 6),
                      _filterChip('Out', 'out'),
                      const SizedBox(width: 6),
                      _filterChip('Adjust', 'adjustment'),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long, size: 64, color: Theme.of(context).colorScheme.outline),
                              const SizedBox(height: 16),
                              Text('No movements found', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) => _movementTile(filtered[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _filter == value;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: selected ? Colors.white : null)),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _movementTile(Map<String, dynamic> m) {
    final type = m['movement_type'] as String;
    final qty = (m['quantity'] as num?)?.toDouble() ?? 0;
    final product = m['products'] as Map<String, dynamic>?;
    final productName = product?['name'] as String? ?? 'Unknown';
    final unit = product?['unit'] as String? ?? '';
    final color = type == 'in' ? Colors.green : type == 'out' ? Colors.red : Colors.orange;
    final icon = type == 'in' ? Icons.arrow_downward : type == 'out' ? Icons.arrow_upward : Icons.tune;
    final createdAt = m['created_at'] as String;
    final date = DateTime.parse(createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(productName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${type == 'in' ? '+' : type == 'out' ? '-' : ''}${qty.abs().toInt()} $unit • ${m['notes'] ?? type.toUpperCase()}',
          style: TextStyle(fontSize: 12, color: color),
        ),
        trailing: Text(DateFormat('dd MMM yy').format(date), style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}
