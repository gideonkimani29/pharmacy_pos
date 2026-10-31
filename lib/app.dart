import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;

import 'core/constants/app_config.dart';
import 'core/constants/app_strings.dart';
import 'core/network/api_session.dart';
import 'core/network/login_page.dart';
import 'core/theme/app_theme.dart';
import 'features/shared/data/rest_repositories.dart';
import 'features/checkout/domain/repositories/customer_repository.dart';
import 'features/checkout/domain/repositories/product_repository.dart';
import 'features/checkout/domain/repositories/sale_repository.dart';
import 'features/checkout/domain/usecases/find_product_by_barcode.dart';
import 'features/checkout/domain/usecases/get_customers.dart';
import 'features/checkout/domain/usecases/search_products.dart';
import 'features/checkout/domain/usecases/submit_sale.dart';
import 'features/checkout/presentation/bloc/cart_bloc.dart';
import 'features/checkout/presentation/bloc/customers_cubit.dart';
import 'features/checkout/presentation/bloc/product_search_bloc.dart';
import 'features/customers/domain/repositories/customer_account_repository.dart';
import 'features/customers/domain/usecases/get_customer_accounts.dart';
import 'features/customers/domain/usecases/receive_account_payment.dart';
import 'features/customers/domain/usecases/save_customer_account.dart';
import 'features/customers/domain/usecases/set_customer_active.dart';
import 'features/customers/presentation/bloc/customer_accounts_cubit.dart';
import 'features/dashboard/domain/repositories/dashboard_repository.dart';
import 'features/dashboard/domain/usecases/get_dashboard_summary.dart';
import 'features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'features/medicines/domain/repositories/medicine_repository.dart';
import 'features/medicines/domain/usecases/get_medicines.dart';
import 'features/medicines/domain/usecases/save_medicine.dart';
import 'features/medicines/domain/usecases/set_medicine_active.dart';
import 'features/medicines/presentation/bloc/medicines_cubit.dart';
import 'features/purchases/domain/repositories/purchase_repository.dart';
import 'features/purchases/domain/repositories/supplier_repository.dart';
import 'features/purchases/domain/usecases/get_purchases.dart';
import 'features/purchases/presentation/bloc/purchases_cubit.dart';
import 'features/reports/domain/repositories/report_repository.dart';
import 'features/reports/domain/usecases/get_losses_report.dart';
import 'features/reports/domain/usecases/get_profit_report.dart';
import 'features/reports/domain/usecases/get_sales_report.dart';
import 'features/reports/presentation/bloc/reports_cubit.dart';
import 'features/settings/domain/repositories/settings_repository.dart';
import 'features/settings/domain/repositories/user_repository.dart';
import 'features/settings/domain/usecases/get_settings.dart';
import 'features/settings/domain/usecases/get_users.dart';
import 'features/settings/domain/usecases/save_settings.dart';
import 'features/settings/domain/usecases/save_user.dart';
import 'features/settings/domain/usecases/set_user_active.dart';
import 'features/settings/presentation/bloc/settings_cubit.dart';
import 'features/shell/presentation/pages/app_shell.dart';
import 'features/stock/domain/repositories/stock_repository.dart';
import 'features/stock/domain/usecases/adjust_stock.dart';
import 'features/stock/domain/usecases/get_stock_batches.dart';
import 'features/stock/presentation/bloc/stock_cubit.dart';

/// Composition root. Repository interfaces keep HTTP details out of features.
class PharmacyPosApp extends StatefulWidget {
  const PharmacyPosApp({super.key, this.session});

  final ApiSession? session;

  @override
  State<PharmacyPosApp> createState() => _PharmacyPosAppState();
}

class _PharmacyPosAppState extends State<PharmacyPosApp> {
  late final ApiSession _session;
  late final bool _ownsSession;
  Future<int>? _taxRateFuture;

  @override
  void initState() {
    super.initState();
    _ownsSession = widget.session == null;
    _session = widget.session ??
        ApiSession(
          baseUrl: const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://127.0.0.1:8080/api/v1',
          ),
        );
    unawaited(_session.restore());
  }

  @override
  void dispose() {
    if (_ownsSession) _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: AnimatedBuilder(
        animation: _session,
        builder: (context, _) {
          if (!_session.isInitialized) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (_session.restoreError case final error?) {
            return _ConnectionError(
                error: error.message, onRetry: _session.restore);
          }
          if (!_session.isAuthenticated) {
            _taxRateFuture = null;
            return LoginPage(session: _session);
          }
          _taxRateFuture ??= _loadTaxRate();
          return FutureBuilder<int>(
            future: _taxRateFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _ConnectionError(
                  error: 'Could not load pharmacy settings: ${snapshot.error}',
                  onRetry: _retryTaxRate,
                );
              }
              if (!snapshot.hasData) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              return _authenticatedHome(snapshot.data!);
            },
          );
        },
      ),
    );
  }

  Future<int> _loadTaxRate() async {
    final settings = apiObject(await _session.get('settings'));
    final taxRate = settings['taxRateBasisPoints'];
    if (taxRate is! int ||
        taxRate < 0 ||
        taxRate > AppConfig.basisPointsDenominator) {
      throw const FormatException(
          'The API returned an invalid pharmacy tax rate.');
    }
    return taxRate;
  }

  Future<void> _retryTaxRate() async {
    setState(() => _taxRateFuture = _loadTaxRate());
  }

  Widget _authenticatedHome(int taxRateBasisPoints) {
    return RepositoryProvider<ApiSession>.value(
      value: _session,
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ProductRepository>(
              create: (_) => RestProductRepository(_session)),
          RepositoryProvider<SaleRepository>(
              create: (_) => RestSaleRepository(_session)),
          RepositoryProvider<CustomerRepository>(
              create: (_) => RestCustomerRepository(_session)),
          RepositoryProvider<DashboardRepository>(
              create: (_) => RestDashboardRepository(_session)),
          RepositoryProvider<SupplierRepository>(
              create: (_) => RestSupplierRepository(_session)),
          RepositoryProvider<PurchaseRepository>(
              create: (_) => RestPurchaseRepository(_session)),
          RepositoryProvider<MedicineRepository>(
              create: (_) => RestMedicineRepository(_session)),
          RepositoryProvider<StockRepository>(
              create: (_) => RestStockRepository(_session)),
          RepositoryProvider<ReportRepository>(
              create: (_) => RestReportRepository(_session)),
          RepositoryProvider<SettingsRepository>(
              create: (_) => RestSettingsRepository(_session)),
          RepositoryProvider<UserRepository>(
              create: (_) => RestUserRepository(_session)),
          RepositoryProvider<CustomerAccountRepository>(
              create: (_) => RestCustomerAccountRepository(_session)),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<ProductSearchBloc>(
              create: (context) => ProductSearchBloc(
                searchProducts:
                    SearchProducts(context.read<ProductRepository>()),
                findProductByBarcode:
                    FindProductByBarcode(context.read<ProductRepository>()),
              ),
            ),
            BlocProvider<CartBloc>(
              create: (context) => CartBloc(
                submitSale: SubmitSale(context.read<SaleRepository>()),
                taxRateBasisPoints: taxRateBasisPoints,
              ),
            ),
            BlocProvider<CustomersCubit>(
              create: (context) => CustomersCubit(
                  getCustomers:
                      GetCustomers(context.read<CustomerRepository>()))
                ..load(),
            ),
            BlocProvider<DashboardCubit>(
              create: (context) => DashboardCubit(
                getDashboardSummary:
                    GetDashboardSummary(context.read<DashboardRepository>()),
              ),
            ),
            BlocProvider<PurchasesCubit>(
              create: (context) => PurchasesCubit(
                  getPurchases:
                      GetPurchases(context.read<PurchaseRepository>())),
            ),
            BlocProvider<MedicinesCubit>(
              create: (context) {
                final repository = context.read<MedicineRepository>();
                return MedicinesCubit(
                  getMedicines: GetMedicines(repository),
                  saveMedicine: SaveMedicine(repository),
                  setMedicineActive: SetMedicineActive(repository),
                );
              },
            ),
            BlocProvider<StockCubit>(
              create: (context) {
                final repository = context.read<StockRepository>();
                return StockCubit(
                  getStockBatches: GetStockBatches(repository),
                  adjustStock: AdjustStock(repository),
                );
              },
            ),
            BlocProvider<CustomerAccountsCubit>(
              create: (context) {
                final repository = context.read<CustomerAccountRepository>();
                return CustomerAccountsCubit(
                  getCustomerAccounts: GetCustomerAccounts(repository),
                  saveCustomerAccount: SaveCustomerAccount(repository),
                  setCustomerActive: SetCustomerActive(repository),
                  receiveAccountPayment: ReceiveAccountPayment(repository),
                );
              },
            ),
            BlocProvider<ReportsCubit>(
              create: (context) {
                final repository = context.read<ReportRepository>();
                return ReportsCubit(
                  getSalesReport: GetSalesReport(repository),
                  getProfitReport: GetProfitReport(repository),
                  getLossesReport: GetLossesReport(repository),
                );
              },
            ),
            BlocProvider<SettingsCubit>(
              create: (context) {
                final settings = context.read<SettingsRepository>();
                final users = context.read<UserRepository>();
                return SettingsCubit(
                  getSettings: GetSettings(settings),
                  saveSettings: SaveSettings(settings),
                  getUsers: GetUsers(users),
                  saveUser: SaveUser(users),
                  setUserActive: SetUserActive(users),
                );
              },
            ),
          ],
          child: BlocListener<SettingsCubit, SettingsState>(
            listenWhen: (previous, current) =>
                previous.saved?.taxRateBasisPoints !=
                current.saved?.taxRateBasisPoints,
            listener: (context, state) {
              final rate = state.saved?.taxRateBasisPoints;
              if (rate != null) {
                context.read<CartBloc>().add(CartTaxRateChanged(rate));
              }
            },
            child: AppShell(onLogout: _logout),
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await _session.logout();
    } on ApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Signed out here, but API revocation failed: ${error.message}')),
        );
      }
    } on http.ClientException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Signed out here; the API could not revoke the session while offline.')),
        );
      }
    } on TimeoutException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Signed out here; API revocation timed out.')),
        );
      }
    }
  }
}

class _ConnectionError extends StatelessWidget {
  const _ConnectionError({required this.error, required this.onRetry});

  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: onRetry, child: const Text('Retry connection')),
            ],
          ),
        ),
      ),
    );
  }
}
