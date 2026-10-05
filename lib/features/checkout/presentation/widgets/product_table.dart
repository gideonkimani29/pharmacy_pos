import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/cart_bloc.dart';
import '../bloc/product_search_bloc.dart';
import 'product_row.dart';

class ProductTable extends StatelessWidget {
  const ProductTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        side: const BorderSide(color: AppColors.border),
      ),
      child: const Column(
        children: [
          _HeaderRow(),
          Divider(height: 1),
          Expanded(child: _Body()),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        );
    return Container(
      color: AppColors.surfaceMuted,
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceLg, vertical: AppDimens.spaceMd),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text(AppStrings.columnMedicine, style: style)),
          Expanded(flex: 4, child: Text(AppStrings.columnGeneric, style: style)),
          SizedBox(
            width: AppDimens.tableStockColumnWidth,
            child: Center(child: Text(AppStrings.columnStock, style: style)),
          ),
          SizedBox(
            width: AppDimens.tableActionColumnWidth,
            child: Center(child: Text(AppStrings.columnAction, style: style)),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductSearchBloc, ProductSearchState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.products != current.products ||
          previous.failure != current.failure,
      builder: (context, state) {
        final isLoading = state.status == ProductSearchStatus.loading;

        if (state.products.isEmpty) {
          if (isLoading || state.status == ProductSearchStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == ProductSearchStatus.failure) {
            return _Message(
              icon: Icons.cloud_off_outlined,
              title: AppStrings.productsLoadFailed,
              detail: state.failure?.message,
              actionLabel: AppStrings.retry,
              onAction: () =>
                  context.read<ProductSearchBloc>().add(ProductSearchQueryChanged(state.query)),
            );
          }
          return _Message(
            icon: Icons.search_off_outlined,
            title: state.query.isEmpty ? AppStrings.noProducts : AppStrings.noResults(state.query),
          );
        }

        return Column(
          children: [
            SizedBox(
              height: AppDimens.spaceXs,
              child: isLoading ? const LinearProgressIndicator() : null,
            ),
            Expanded(
              child: ListView.separated(
                itemCount: state.products.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final product = state.products[index];
                  return ProductRow(
                    key: ValueKey(product.id),
                    product: product,
                    onAdd: () => context.read<CartBloc>().add(CartProductAdded(product)),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, this.detail, this.actionLabel, this.onAction});

  static const double _iconSize = 40;

  final IconData icon;
  final String title;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: _iconSize, color: AppColors.textSecondary),
          const SizedBox(height: AppDimens.spaceMd),
          Text(title, style: theme.textTheme.titleMedium),
          if (detail != null) ...[
            const SizedBox(height: AppDimens.spaceXs),
            Text(detail!, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppDimens.spaceLg),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
