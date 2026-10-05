import '../../../../core/result/result.dart';
import '../entities/medicine.dart';
import '../repositories/medicine_repository.dart';

class SetMedicineActive {
  const SetMedicineActive(this._repository);

  final MedicineRepository _repository;

  Future<Result<Medicine>> call(String id, {required bool active}) =>
      _repository.setActive(id, active: active);
}
