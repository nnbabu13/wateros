import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final businessId = await BusinessHelper.getOrCreateBusinessId();

      final data = await Supabase.instance.client
          .from('customers')
          .select()
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('name');

      if (mounted) {
        setState(() {
          _customers = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredCustomers {
    if (_searchQuery.isEmpty) return _customers;
    final q = _searchQuery.toLowerCase();
    return _customers.where((c) {
      final name = (c['name'] as String? ?? '').toLowerCase();
      final phone = (c['phone'] as String?) ?? '';
      return name.contains(q) || phone.contains(q);
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
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () async {
              await context.push('/customers/add');
              _loadCustomers();
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
                hintText: 'Search customers...',
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
                : _filteredCustomers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('No customers found',
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await context.push('/customers/add');
                                _loadCustomers();
                              },
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add Customer'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCustomers,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _filteredCustomers.length,
                          itemBuilder: (context, index) {
                            final customer = _filteredCustomers[index];
                            final name = customer['name'] as String? ?? '';
                            final phone = customer['phone'] as String? ?? '';
                            final balance =
                                (customer['current_balance'] as num?)?.toDouble() ?? 0;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                leading: CircleAvatar(
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                                title: Text(name,
                                    style: const TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: Text(phone,
                                    style: const TextStyle(fontSize: 13)),
                                trailing: balance > 0
                                    ? Text(
                                        '₹ ${balance.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      )
                                    : null,
                                onTap: () => context.push('/customers/${customer['id']}'),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
