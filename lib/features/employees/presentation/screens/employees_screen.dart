import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<Map<String, dynamic>> _employees = [];
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
          .from('employees')
          .select()
          .eq('business_id', bizId)
          .order('name');
      if (mounted) setState(() { _employees = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        actions: [
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      const Text('No employees yet'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(onPressed: () => context.push('/employees/add'), icon: const Icon(Icons.person_add), label: const Text('Add Employee')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _employees.length,
                    itemBuilder: (context, index) => _buildEmployeeCard(_employees[index]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/employees/add');
          _loadData();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Employee'),
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> emp) {
    final cs = Theme.of(context).colorScheme;
    final isActive = emp['is_active'] as bool? ?? true;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? cs.primaryContainer : cs.surfaceContainerHighest,
          child: Text((emp['name'] as String? ?? '?')[0].toUpperCase(), style: TextStyle(color: isActive ? cs.onPrimaryContainer : cs.onSurface)),
        ),
        title: Row(
          children: [
            Expanded(child: Text(emp['name'] as String? ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
            if (!isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: const Text('INACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey)),
              ),
          ],
        ),
        subtitle: Text([
          emp['designation'] ?? emp['department'] ?? '',
          emp['phone'] as String? ?? '',
        ].where((s) => s.isNotEmpty).join(' • ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('₹${(emp['basic_salary'] as num? ?? 0).toDouble().toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (emp['date_of_joining'] != null)
              Text(DateFormat('dd MMM yyyy').format(DateTime.parse(emp['date_of_joining'] as String)),
                  style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
          ],
        ),
        onTap: () => context.push('/employees/${emp['id']}'),
      ),
    );
  }
}
