import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/money.dart';
import '../../domain/entities/sale_type.dart';
import '../bloc/cart_bloc.dart';
import '../bloc/product_search_bloc.dart';
import '../widgets/barcode_keyboard_listener.dart';
import '../widgets/cart_panel.dart';
import '../widgets/customer_selector.dart';
import '../widgets/discount_dialog.dart';
import '../widgets/payment_dialog.dart';
import '../widgets/product_search_field.dart';
import '../widgets/product_table.dart';
import '../widgets/sale_complete_dialog.dart';
import 'checkout_intents.dart';

/// New-sale tab: customer, catalog and cart. Hosted inside [PosPage].
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    context.read<ProductSearchBloc>().add(const ProductSearchStarted());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ---- actions -----------------------------------------------------------

  void _focusSearch() {
    _searchFocus.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
  }

  void _onSearchChanged(String query) {
    context.read<ProductSearchBloc>().add(ProductSearchQueryChanged(query));
  }

  void _onBarcodeDetected(String barcode) {
    // The scanner also typed the code into any focused field; clear it.
    _searchController.clear();
    context.read<ProductSearchBloc>().add(ProductBarcodeScanned(barcode));
  }

  Future<void> _checkout() async {
    final cart = context.read<CartBloc>();
    final state = cart.state;

    if (state.isEmpty) {
      cart.add(const CartNoticeRaised(AppStrings.noticeCartEmpty));
      return;
    }
    if (state.requiresPrescriptionCheck && !state.prescriptionVerified) {
      cart.add(const CartNoticeRaised(AppStrings.noticeRxNotVerified));
      return;
    }
    if (state.saleType == SaleType.credit && state.customer == null) {
      cart.add(const CartNoticeRaised(AppStrings.noticeCreditNeedsCustomer));
      return;
    }
    if (!state.canCheckout) return;

    if (state.saleType == SaleType.credit) {
      final confirmed = await _confirmCredit(state);
      if (mounted && confirmed) cart.add(const CartCheckoutSubmitted([]));
      return;
    }

    final payments = await PaymentDialog.show(context, totalMinor: state.totals.totalMinor);
    if (!mounted || payments == null || payments.isEmpty) return;
    cart.add(CartCheckoutSubmitted(payments));
  }

  Future<bool> _confirmCredit(CartState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.creditConfirmTitle),
        content: Text(
          AppStrings.creditConfirmBody(Money.format(state.totals.totalMinor), state.customer!.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.chargeToAccount),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _confirmClearCart() async {
    final cart = context.read<CartBloc>();
    if (cart.state.isEmpty || cart.state.isSubmitting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.clearConfirmTitle),
        content: const Text(AppStrings.clearConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(AppStrings.keepSale),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(AppStrings.clearConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed == true) cart.add(const CartCleared());
  }

  Future<void> _editDiscount() async {
    final cart = context.read<CartBloc>();
    final state = cart.state;
    if (state.isEmpty || state.isSubmitting) return;

    final discount = await DiscountDialog.show(
      context,
      subtotalMinor: state.subtotalMinor,
      currentMinor: state.discountMinor,
    );
    if (!mounted || discount == null) return;
    cart.add(CartDiscountChanged(discount));
  }

  // ---- listeners ---------------------------------------------------------

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onScanOutcome(BuildContext context, ProductSearchState state) {
    final outcome = state.scanOutcome;
    if (outcome == null) return;

    final failure = outcome.failure;
    final product = outcome.product;
    if (failure != null) {
      _showSnackBar(failure.message);
    } else if (product == null) {
      _showSnackBar(AppStrings.noticeBarcodeNotFound(outcome.barcode));
    } else {
      context.read<CartBloc>().add(CartProductAdded(product));
    }
    _searchController.clear();
    context.read<ProductSearchBloc>().add(const ProductSearchQueryChanged(''));
  }

  Future<void> _onSaleCompleted(BuildContext context, CartState state) async {
    final receipt = state.receipt;
    final cart = context.read<CartBloc>();
    if (receipt != null) await SaleCompleteDialog.show(this.context, receipt);
    cart.add(const CartSaleAcknowledged());
    if (mounted) _focusSearch();
  }

  // ---- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ProductSearchBloc, ProductSearchState>(
          listenWhen: (previous, current) =>
              current.scanOutcome != null && previous.scanOutcome != current.scanOutcome,
          listener: _onScanOutcome,
        ),
        BlocListener<CartBloc, CartState>(
          listenWhen: (previous, current) => current.notice != null && previous.notice != current.notice,
          listener: (context, state) => _showSnackBar(state.notice!.message),
        ),
        BlocListener<CartBloc, CartState>(
          listenWhen: (previous, current) =>
              previous.status != current.status && current.status == CartStatus.completed,
          listener: _onSaleCompleted,
        ),
      ],
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.f1): FocusSearchIntent(),
          SingleActivator(LogicalKeyboardKey.f2): PayIntent(),
          SingleActivator(LogicalKeyboardKey.escape): ClearCartIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            FocusSearchIntent: CallbackAction<FocusSearchIntent>(onInvoke: (_) {
              _focusSearch();
              return null;
            }),
            PayIntent: CallbackAction<PayIntent>(onInvoke: (_) {
              _checkout();
              return null;
            }),
            ClearCartIntent: CallbackAction<ClearCartIntent>(onInvoke: (_) {
              _confirmClearCart();
              return null;
            }),
          },
          child: Focus(
            autofocus: true,
            child: BarcodeKeyboardListener(
              onBarcode: _onBarcodeDetected,
              child: _SplitBody(
                searchController: _searchController,
                searchFocus: _searchFocus,
                onSearchChanged: _onSearchChanged,
                onCheckout: _checkout,
                onClear: _confirmClearCart,
                onEditDiscount: _editDiscount,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplitBody extends StatelessWidget {
  const _SplitBody({
    required this.searchController,
    required this.searchFocus,
    required this.onSearchChanged,
    required this.onCheckout,
    required this.onClear,
    required this.onEditDiscount,
  });

  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCheckout;
  final VoidCallback onClear;
  final VoidCallback onEditDiscount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cartWidth = (constraints.maxWidth * AppDimens.cartPanelFraction)
            .clamp(AppDimens.cartPanelMinWidth, AppDimens.cartPanelMaxWidth)
            .toDouble();

        return Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  const CustomerSelector(),
                  const SizedBox(height: AppDimens.spaceMd),
                  ProductSearchField(
                    controller: searchController,
                    focusNode: searchFocus,
                    onChanged: onSearchChanged,
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  const Expanded(child: ProductTable()),
                ],
              ),
            ),
            const SizedBox(width: AppDimens.spaceLg),
            SizedBox(
              width: cartWidth,
              child: CartPanel(
                onCheckout: onCheckout,
                onClear: onClear,
                onEditDiscount: onEditDiscount,
              ),
            ),
          ],
        );
      },
    );
  }
}
