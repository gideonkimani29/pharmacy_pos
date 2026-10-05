import 'package:equatable/equatable.dart';

import '../constants/app_strings.dart';

/// Typed domain failures. Data-layer code maps transport errors into these,
/// so presentation never sees Dio/HTTP types.
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = AppStrings.errorNetwork]);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = AppStrings.errorUnauthorized]);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = AppStrings.errorUnexpected]);
}
