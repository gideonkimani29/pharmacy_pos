import 'package:equatable/equatable.dart';

enum UserRole { admin, pharmacist, cashier }

/// A person who can sign in. Passwords never exist in this app: the Go API
/// invites the user by email and they set their own.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    this.lastSignInAt,
  });

  final String id;
  final String name;
  final String email;

  /// Empty when not given.
  final String phone;
  final UserRole role;
  final bool isActive;
  final DateTime? lastSignInAt;

  AppUser copyWith({bool? isActive}) {
    return AppUser(
      id: id,
      name: name,
      email: email,
      phone: phone,
      role: role,
      isActive: isActive ?? this.isActive,
      lastSignInAt: lastSignInAt,
    );
  }

  @override
  List<Object?> get props => [id, name, email, phone, role, isActive, lastSignInAt];
}

class UserDraft extends Equatable {
  const UserDraft({required this.name, required this.email, required this.phone, required this.role});

  final String name;
  final String email;
  final String phone;
  final UserRole role;

  @override
  List<Object?> get props => [name, email, phone, role];
}
