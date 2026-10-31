import 'dart:async';

import 'package:http/http.dart' as http;

import '../error/failures.dart';
import '../result/result.dart';
import 'api_session.dart';

abstract class ApiRepository {
  const ApiRepository(this.api);

  final ApiSession api;

  Future<Result<T>> run<T>(Future<T> Function() action) async {
    try {
      return Ok<T>(await action());
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return Err<T>(UnauthorizedFailure(error.message));
      }
      if (error.statusCode == 400 || error.statusCode == 404 || error.statusCode == 409 ||
          error.statusCode == 422) {
        return Err<T>(ValidationFailure(error.message));
      }
      if (error.statusCode == 0) return Err<T>(NetworkFailure(error.message));
      return Err<T>(UnexpectedFailure(error.message));
    } on http.ClientException {
      return const Err<T>(NetworkFailure());
    } on TimeoutException {
      return const Err<T>(NetworkFailure());
    } on FormatException catch (error) {
      return Err<T>(UnexpectedFailure(error.message));
    }
  }
}
