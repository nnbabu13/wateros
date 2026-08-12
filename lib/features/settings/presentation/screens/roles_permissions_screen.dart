import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/business_helper.dart';

class RolesPermissionsScreen extends StatefulWidget {
  const RolesPermissionsScreen({super.key});

  @override
  State<RolesPermissionsScreen> createState() => _RolesPermissionsScreenState();
}

class _RolesPermissionsScreenState extends State<RolesPermissionsScreen> {
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _permissions = [];
  bool _isLoading = true;
  String _selectedRole = 'employee';

  final _modules = ['dashboard', 'customers', 'sales', 'payments', 'suppliers', 'purchases', 'expenses', 'products', 'inventory', 'employees', 'attendance', 'salary', 'reports', 'settings'];

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
          .from('role_permissions')
          .select()
          .eq('business_id', bizId);
      if (mounted) {
        setState(() {
          _permissions = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, Map<String, bool>> _getPermissionMap() {
    final map = <String, Map<String, bool>>{};
    for (final p in _permissions) {
      final role = p['role'] as String;
      final module = p['module'] as String;
      map[role] ??= {};
      map[role]![module] = p['can_view'] as bool? ?? false;
    }
    return map;
  }

  Future<void> _togglePermission(String role, String module, String field, bool value) async {
    final bizId = await BusinessHelper.getOrCreateBusinessId();
    final existing = _permissions.where((p) => p['role'] == role && p['module'] == module);
    if (existing.isNotEmpty) {
      final id = existing.first['id'];
      await Supabase.instance.client.from('role_permissions').update({field: value}).eq('id', id);
    } else {
      await Supabase.instance.client.from('role_permissions').insert({
        'business_id': bizId,
        'role': role,
        'module': module,
        'can_view': field == 'can_view' ? value : false,
        'can_create': field == 'can_create' ? value : false,
        'can_edit': field == 'can_edit' ? value : false,
        'can_delete': field == 'can_delete' ? value : false,
      });
    }
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final roles = ['owner', 'admin', 'manager', 'sales', 'accountant', 'delivery', 'employee'];
    return Scaffold(
      appBar: AppBar(title: const Text('Roles & Permissions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: SegmentedButton<String>(
                    segments: roles.map((r) => ButtonSegment(value: r, label: Text(r[0].toUpperCase() + r.substring(1), style: const TextStyle(fontSize: 11)))).toList(),
                    selected: {_selectedRole},
                    onSelectionChanged: (s) => setState(() => _selectedRole = s.first),
                    style: ButtonStyle(visualDensity: VisualDensity.compact),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Card(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 8,
                            headingRowHeight: 40,
                            dataRowHeight: 44,
                            columns: const [
                              DataColumn(label: Text('Module', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                              DataColumn(label: Text('View', style: TextStyle(fontSize: 12)), numeric: true),
                              DataColumn(label: Text('Create', style: TextStyle(fontSize: 12)), numeric: true),
                              DataColumn(label: Text('Edit', style: TextStyle(fontSize: 12)), numeric: true),
                              DataColumn(label: Text('Delete', style: TextStyle(fontSize: 12)), numeric: true),
                            ],
                            rows: _modules.map((module) {
                              final perm = _permissions.where((p) => p['role'] == _selectedRole && p['module'] == module);
                              final p = perm.isNotEmpty ? perm.first : null;
                              return DataRow(cells: [
                                DataCell(Text(module[0].toUpperCase() + module.substring(1), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                                DataCell(Checkbox(value: p?['can_view'] ?? false, onChanged: (v) => _togglePermission(_selectedRole, module, 'can_view', v ?? false), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                                DataCell(Checkbox(value: p?['can_create'] ?? false, onChanged: (v) => _togglePermission(_selectedRole, module, 'can_create', v ?? false), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                                DataCell(Checkbox(value: p?['can_edit'] ?? false, onChanged: (v) => _togglePermission(_selectedRole, module, 'can_edit', v ?? false), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                                DataCell(Checkbox(value: p?['can_delete'] ?? false, onChanged: (v) => _togglePermission(_selectedRole, module, 'can_delete', v ?? false), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
