import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/money.dart';
import '../bloc/purchase_form_cubit.dart';
import '../purchases_constants.dart';

/// Search box plus a result list. Tapping a result adds a new line.
class PurchaseProductSearch extends StatefulWidget {
  const PurchaseProductSearch({super.key});

  @override
  State<PurchaseProductSearch> createState() => _PurchaseProductSearchState();
}

class _PurchaseProductSearchState extends State<PurchaseProductSearch> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PurchaseFormCubit>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          onChanged: cubit.search,
          decoration: const InputDecoration(
            hintText: PurchasesStrings.searchProducts,
            prefixIcon: Icon(Icons.search),
          ),
        ),
        BlocBuilder<PurchaseFormCubit, PurchaseFormState>(
          buildWhen: (previous, current) =>
              previous.searchQuery != current.searchQuery ||
              previous.searchResults != current.searchResults ||
              previous.searching != current.searching,
          builder: (context, state) {
            if (state.searchQuery.isEmpty) return const SizedBox.shrink();

            if (state.searching && state.searchResults.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: AppDimens.spaceSm),
                child: LinearProgressIndicator(),
              );
            }
            if (state.searchResults.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: AppDimens.spaceSm),
                child: Text(
                  PurchasesStrings.noMatches(state.searchQuery),
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
              );
            }

            return Container(
              margin: const EdgeInsets.only(top: AppDimens.spaceSm),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              child: Column(
                children: [
                  for (final product in state.searchResults.take(PurchasesLayout.maxSearchResults))
                    ListTile(
                      dense: true,
                      title: Text(product.name),
                      subtitle: Text('${product.genericName}  ·  ${product.sku}'),
                      trailing: Text(Money.format(product.unitPriceMinor)),
                      leading: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                      onTap: () {
                        cubit.addProduct(product);
                        _controller.clear();
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
