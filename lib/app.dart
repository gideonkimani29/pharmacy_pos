import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/checkout/data/repositories/demo_customer_repository.dart';
import 'features/checkout/data/repositories/demo_product_repository.dart';
import 'features/checkout/data/repositories/demo_sale_repository.dart';
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
import 'features/customers/data/repositories/demo_customer_account_repository.dart';
import 'features/customers/domain/repositories/customer_account_repository.dart';
import 'features/customers/domain/usecases/get_customer_accounts.dart';
import 'features/customers/domain/usecases/receive_account_payment.dart';
import 'features/customers/domain/usecases/save_customer_account.dart';
import 'features/customers/domain/usecases/set_customer_active.dart';
import 'features/customers/presentation/bloc/customer_accounts_cubit.dart';
import 'features/dashboard/data/repositories/demo_dashboard_repository.dart';
import 'features/dashboard/domain/repositories/dashboard_repository.dart';
import 'features/dashboard/domain/usecases/get_dashboard_summary.dart';
import 'features/dashboard/presentation/bloc/dashboard_cubit.dart';
import 'features/medicines/data/repositories/demo_medicine_repository.dart';
import 'features/medicines/domain/repositories/medicine_repository.dart';
import 'features/medicines/domain/usecases/get_medicines.dart';
import 'features/medicines/domain/usecases/save_medicine.dart';
import 'features/medicines/domain/usecases/set_medicine_active.dart';
import 'features/medicines/presentation/bloc/medicines_cubit.dart';
import 'features/purchases/data/repositories/demo_purchase_repository.dart';
import 'features/purchases/data/repositories/demo_supplier_repository.dart';
import 'features/purchases/domain/repositories/purchase_repository.dart';
import 'features/purchases/domain/repositories/supplier_repository.dart';
import 'features/purchases/domain/usecases/get_purchases.dart';
import 'features/purchases/presentation/bloc/purchases_cubit.dart';
import 'features/shell/presentation/pages/app_shell.dart';
import 'features/stock/data/repositories/demo_stock_repository.dart';
import 'features/stock/domain/repositories/stock_repository.dart';
import 'features/stock/domain/usecases/adjust_stock.dart';
import 'features/stock/domain/usecases/get_stock_batches.dart';
import 'features/stock/presentation/bloc/stock_cubit.dart';

/// Composition root. Swap the Demo* repositories for the REST-backed ones here
/// and nothing above the data layer changes.
class PharmacyPosApp extends StatelessWidget {
  const PharmacyPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<ProductRepository>(create: (_) => DemoProductRepository()),
        RepositoryProvider<SaleRepository>(create: (_) => DemoSaleRepository()),
        RepositoryProvider<CustomerRepository>(create: (_) => DemoCustomerRepository()),
        RepositoryProvider<DashboardRepository>(create: (_) => DemoDashboardRepository()),
        RepositoryProvider<SupplierRepository>(create: (_) => DemoSupplierRepository()),
        RepositoryProvider<PurchaseRepository>(create: (_) => DemoPurchaseRepository()),
        RepositoryProvider<MedicineRepository>(create: (_) => DemoMedicineRepository()),
        RepositoryProvider<StockRepository>(create: (_) => DemoStockRepository()),
        RepositoryProvider<CustomerAccountRepository>(create: (_) => DemoCustomerAccountRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ProductSearchBloc>(
            create: (context) => ProductSearchBloc(
              searchProducts: SearchProducts(context.read<ProductRepository>()),
              findProductByBarcode: FindProductByBarcode(context.read<ProductRepository>()),
            ),
          ),
          BlocProvider<CartBloc>(
            create: (context) => CartBloc(submitSale: SubmitSale(context.read<SaleRepository>())),
          ),
          BlocProvider<CustomersCubit>(
            create: (context) =>
                CustomersCubit(getCustomers: GetCustomers(context.read<CustomerRepository>()))..load(),
          ),
          BlocProvider<DashboardCubit>(
            create: (context) => DashboardCubit(
              getDashboardSummary: GetDashboardSummary(context.read<DashboardRepository>()),
            ),
          ),
          BlocProvider<PurchasesCubit>(
            create: (context) =>
                PurchasesCubit(getPurchases: GetPurchases(context.read<PurchaseRepository>())),
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
        ],
        child: MaterialApp(
          title: AppStrings.appTitle,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const AppShell(),
        ),
      ),
    );
  }
}
