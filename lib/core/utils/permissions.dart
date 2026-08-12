import '../constants/app_enums.dart';

class Permission {
  final String module;
  final bool canView;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;

  const Permission({
    required this.module,
    this.canView = false,
    this.canCreate = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      module: json['module'] as String,
      canView: json['can_view'] as bool? ?? false,
      canCreate: json['can_create'] as bool? ?? false,
      canEdit: json['can_edit'] as bool? ?? false,
      canDelete: json['can_delete'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'module': module,
      'can_view': canView,
      'can_create': canCreate,
      'can_edit': canEdit,
      'can_delete': canDelete,
    };
  }

  bool get hasAnyPermission => canView || canCreate || canEdit || canDelete;
}

class PermissionsHelper {
  PermissionsHelper._();

  static const Map<UserRole, Map<String, bool>> defaultPermissions = {
    UserRole.owner: {
      'dashboard': true,
      'customers': true,
      'sales': true,
      'payments': true,
      'suppliers': true,
      'purchases': true,
      'expenses': true,
      'products': true,
      'inventory': true,
      'employees': true,
      'attendance': true,
      'salary': true,
      'cashbook': true,
      'bankbook': true,
      'reports': true,
      'notifications': true,
      'settings': true,
    },
    UserRole.admin: {
      'dashboard': true,
      'customers': true,
      'sales': true,
      'payments': true,
      'suppliers': true,
      'purchases': true,
      'expenses': true,
      'products': true,
      'inventory': true,
      'employees': true,
      'attendance': true,
      'salary': true,
      'cashbook': true,
      'bankbook': true,
      'reports': true,
      'notifications': true,
      'settings': true,
    },
    UserRole.manager: {
      'dashboard': true,
      'customers': true,
      'sales': true,
      'payments': true,
      'suppliers': true,
      'purchases': true,
      'expenses': true,
      'products': true,
      'inventory': true,
      'employees': false,
      'attendance': true,
      'salary': false,
      'cashbook': true,
      'bankbook': true,
      'reports': true,
      'notifications': true,
      'settings': false,
    },
    UserRole.sales: {
      'dashboard': true,
      'customers': true,
      'sales': true,
      'payments': true,
      'suppliers': false,
      'purchases': false,
      'expenses': false,
      'products': true,
      'inventory': false,
      'employees': false,
      'attendance': false,
      'salary': false,
      'cashbook': false,
      'bankbook': false,
      'reports': false,
      'notifications': true,
      'settings': false,
    },
    UserRole.accountant: {
      'dashboard': true,
      'customers': true,
      'sales': true,
      'payments': true,
      'suppliers': true,
      'purchases': true,
      'expenses': true,
      'products': false,
      'inventory': false,
      'employees': true,
      'attendance': true,
      'salary': true,
      'cashbook': true,
      'bankbook': true,
      'reports': true,
      'notifications': true,
      'settings': false,
    },
    UserRole.delivery: {
      'dashboard': true,
      'customers': true,
      'sales': false,
      'payments': false,
      'suppliers': false,
      'purchases': false,
      'expenses': false,
      'products': false,
      'inventory': true,
      'employees': false,
      'attendance': false,
      'salary': false,
      'cashbook': false,
      'bankbook': false,
      'reports': false,
      'notifications': true,
      'settings': false,
    },
    UserRole.employee: {
      'dashboard': true,
      'customers': false,
      'sales': false,
      'payments': false,
      'suppliers': false,
      'purchases': false,
      'expenses': false,
      'products': false,
      'inventory': false,
      'employees': false,
      'attendance': false,
      'salary': false,
      'cashbook': false,
      'bankbook': false,
      'reports': false,
      'notifications': true,
      'settings': false,
    },
  };

  static bool hasPermission(UserRole role, String module) {
    return defaultPermissions[role]?[module] ?? false;
  }

  static List<String> getAccessibleModules(UserRole role) {
    final permissions = defaultPermissions[role] ?? {};
    return permissions.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }
}
