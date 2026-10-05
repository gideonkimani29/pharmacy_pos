import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../checkout/domain/repositories/product_repository.dart';
import '../../../checkout/domain/usecases/search_products.dart';
import '../../domain/repositories/purchase_repository.dart';
import '../../domain/repositories/supplier_repository.dart';
import '../../domain/usecases/get_suppliers.dart';
import '../../domain/usecases/record_purchase.dart';
import '../bloc/purchase_form_cubit.dart';
import '../bloc/purchases_cubit.dart';
import '../widgets/purchase_form_view.dart';
import '../widgets/purchase_list_view.dart';

class PurchasesPage extends StatefulWidget {
  const PurchasesPage({super.key});

  @override
  State<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends State<PurchasesPage> {
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    // The shell builds this page each time the sidebar item is opened,
    // so the list refreshes on every visit.
    context.read<PurchasesCubit>().load();
  }

  void _closeForm() {
    setState(() => _creating = false);
    context.read<PurchasesCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: _creating
          ? BlocProvider<PurchaseFormCubit>(
              create: (context) => PurchaseFormCubit(
                getSuppliers: GetSuppliers(context.read<SupplierRepository>()),
                searchProducts: SearchProducts(context.read<ProductRepository>()),
                recordPurchase: RecordPurchase(context.read<PurchaseRepository>()),
              )..load(),
              child: PurchaseFormView(onClose: _closeForm),
            )
          : PurchaseListView(onNew: () => setState(() => _creating = true)),
    );
  }
}
