import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/customers/presentation/screens/customers_screen.dart';
import '../../features/customers/presentation/screens/customer_detail_screen.dart';
import '../../features/customers/presentation/screens/add_customer_screen.dart';
import '../../features/sales/presentation/screens/sales_screen.dart';
import '../../features/sales/presentation/screens/create_sale_screen.dart';
import '../../features/sales/presentation/screens/sale_detail_screen.dart';
import '../../features/sales/presentation/screens/edit_sale_screen.dart';
import '../../features/payments/presentation/screens/payments_screen.dart';
import '../../features/payments/presentation/screens/record_payment_screen.dart';
import '../../features/suppliers/presentation/screens/suppliers_screen.dart';
import '../../features/suppliers/presentation/screens/supplier_detail_screen.dart';
import '../../features/suppliers/presentation/screens/add_supplier_screen.dart';
import '../../features/purchases/presentation/screens/purchases_screen.dart';
import '../../features/purchases/presentation/screens/create_purchase_screen.dart';
import '../../features/expenses/presentation/screens/expenses_screen.dart';
import '../../features/expenses/presentation/screens/add_expense_screen.dart';
import '../../features/products/presentation/screens/products_screen.dart';
import '../../features/products/presentation/screens/product_detail_screen.dart';
import '../../features/products/presentation/screens/add_product_screen.dart';
import '../../features/inventory/presentation/screens/inventory_dashboard_screen.dart';
import '../../features/inventory/presentation/screens/product_detail_screen.dart';
import '../../features/inventory/presentation/screens/add_inventory_product_screen.dart';
import '../../features/inventory/presentation/screens/stock_movements_screen.dart';
import '../../features/inventory/presentation/screens/product_recipes_screen.dart';
import '../../features/inventory/presentation/screens/production_screen.dart';
import '../../features/employees/presentation/screens/employees_screen.dart';
import '../../features/employees/presentation/screens/employee_detail_screen.dart';
import '../../features/employees/presentation/screens/add_employee_screen.dart';
import '../../features/attendance/presentation/screens/attendance_screen.dart';
import '../../features/salary/presentation/screens/salary_screen.dart';
import '../../features/cashbook/presentation/screens/transactions_screen.dart';
import '../../features/sales/presentation/screens/daily_sales_screen.dart';
import '../../features/bankbook/presentation/screens/bankbook_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/business_profile_screen.dart';
import '../../features/settings/presentation/screens/invoice_template_screen.dart';
import '../../features/settings/presentation/screens/whatsapp_template_screen.dart';
import '../../features/settings/presentation/screens/roles_permissions_screen.dart';
import '../../features/reports/presentation/screens/expense_report_screen.dart';
import '../widgets/main_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuthenticated = authState.valueOrNull != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isAuthenticated && !isLoginRoute) return '/login';
      if (isAuthenticated && isLoginRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/customers',
            builder: (context, state) => const CustomersScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const AddCustomerScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => CustomerDetailScreen(
                  customerId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => AddCustomerScreen(
                      customerId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/sales',
            builder: (context, state) => SalesScreen(
              initialTab: state.extra as int? ?? 0,
            ),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => CreateSaleScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => SaleDetailScreen(
                  saleId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => EditSaleScreen(
                      saleId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/payments',
            builder: (context, state) => const PaymentsScreen(),
            routes: [
              GoRoute(
                path: 'record',
                builder: (context, state) => const RecordPaymentScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/suppliers',
            builder: (context, state) => const SuppliersScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const AddSupplierScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => SupplierDetailScreen(
                  supplierId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => AddSupplierScreen(
                      supplierId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/purchases',
            builder: (context, state) => const PurchasesScreen(),
            routes: [
              GoRoute(
                path: 'create',
                builder: (context, state) => const CreatePurchaseScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/expenses',
            builder: (context, state) => const ExpensesScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => AddExpenseScreen(
                  expenseId: state.extra as String?,
                ),
              ),
            ],
          ),
          GoRoute(
            path: '/products',
            builder: (context, state) => const ProductsScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const AddProductScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => ProductDetailScreen(
                  productId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => AddProductScreen(
                      productId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryDashboardScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const AddInventoryProductScreen(),
              ),
              GoRoute(
                path: 'movements',
                builder: (context, state) => const StockMovementsScreen(),
              ),
              GoRoute(
                path: 'stock-ledger',
                builder: (context, state) => const StockMovementsScreen(),
              ),
              GoRoute(
                path: 'recipes',
                builder: (context, state) => const ProductRecipesScreen(),
              ),
              GoRoute(
                path: 'production',
                builder: (context, state) => const ProductionScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => InventoryProductDetailScreen(
                  productId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => AddInventoryProductScreen(
                      productId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/employees',
            builder: (context, state) => const EmployeesScreen(),
            routes: [
              GoRoute(
                path: 'add',
                builder: (context, state) => const AddEmployeeScreen(),
              ),
              GoRoute(
                path: ':id',
                builder: (context, state) => EmployeeDetailScreen(
                  employeeId: state.pathParameters['id']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => AddEmployeeScreen(
                      employeeId: state.pathParameters['id'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/attendance',
            builder: (context, state) => const AttendanceScreen(),
          ),
          GoRoute(
            path: '/salary',
            builder: (context, state) => const SalaryScreen(),
          ),
          GoRoute(
            path: '/cashbook',
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: '/bankbook',
            builder: (context, state) => const BankbookScreen(),
          ),
          GoRoute(
            path: '/daily-sales',
            builder: (context, state) => const DailySalesScreen(),
          ),
          GoRoute(
            path: '/receipt-ledger',
            builder: (context, state) => const TransactionsScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
            routes: [
              GoRoute(
                path: 'expense-report',
                builder: (context, state) => const ExpenseReportScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
            routes: [
              GoRoute(path: 'business-profile', builder: (context, state) => const BusinessProfileScreen()),
              GoRoute(path: 'invoice-template', builder: (context, state) => const InvoiceTemplateScreen()),
              GoRoute(path: 'whatsapp-templates', builder: (context, state) => const WhatsAppTemplateScreen()),
              GoRoute(path: 'roles-permissions', builder: (context, state) => const RolesPermissionsScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});
