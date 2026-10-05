import '../../../../core/result/result.dart';
import '../entities/medicine.dart';
import '../repositories/medicine_repository.dart';

class GetMedicines {
  const GetMedicines(this._repository);

  final MedicineRepository _repository;

  Future<Result<List<Medicine>>> call() => _repository.list();
}
