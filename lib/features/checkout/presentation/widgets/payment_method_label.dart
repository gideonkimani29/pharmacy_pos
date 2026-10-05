import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../domain/entities/payment.dart';

extension PaymentMethodLabel on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.cash => AppStrings.methodCash,
        PaymentMethod.card => AppStrings.methodCard,
        PaymentMethod.mobile => AppStrings.methodMobile,
      };

  String? get referenceLabel => switch (this) {
        PaymentMethod.cash => null,
        PaymentMethod.card => AppStrings.referenceCard,
        PaymentMethod.mobile => AppStrings.referenceMobile,
      };

  IconData get icon => switch (this) {
        PaymentMethod.cash => Icons.payments_outlined,
        PaymentMethod.card => Icons.credit_card_outlined,
        PaymentMethod.mobile => Icons.phone_android_outlined,
      };
}
