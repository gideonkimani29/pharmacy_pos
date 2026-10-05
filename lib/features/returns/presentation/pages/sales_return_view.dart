import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/empty_state.dart';

class SalesReturnView extends StatelessWidget {
  const SalesReturnView({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.undo,
      title: AppStrings.salesReturnTitle,
      message: AppStrings.salesReturnHint,
    );
  }
}
