enum UserRole {
  admin,
  jaegerMedlem,
  ejer,
  forvalter,
  bbDirektoer,
  jagtGaest,
  gaest,
}

extension UserRoleX on UserRole {
  String get dbValue {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.jaegerMedlem:
        return 'jaeger_medlem';
      case UserRole.ejer:
        return 'ejer';
      case UserRole.forvalter:
        return 'forvalter';
      case UserRole.bbDirektoer:
        return 'bb_direktoer';
      case UserRole.jagtGaest:
        return 'jagt_gaest';
      case UserRole.gaest:
        return 'gaest';
    }
  }

  String get label {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.jaegerMedlem:
        return 'Jæger Medlem';
      case UserRole.ejer:
        return 'Ejer';
      case UserRole.forvalter:
        return 'Forvalter';
      case UserRole.bbDirektoer:
        return 'B&B Direktør';
      case UserRole.jagtGaest:
        return 'Jagt Gæst';
      case UserRole.gaest:
        return 'Gæst';
    }
  }

  static UserRole fromDb(String? value) {
    switch (value) {
      case 'admin':
        return UserRole.admin;
      case 'jaeger_medlem':
        return UserRole.jaegerMedlem;
      case 'ejer':
        return UserRole.ejer;
      case 'forvalter':
        return UserRole.forvalter;
      case 'bb_direktoer':
        return UserRole.bbDirektoer;
      case 'jagt_gaest':
        return UserRole.jagtGaest;
      case 'member':
        return UserRole.jaegerMedlem;
      case 'guest':
        return UserRole.gaest;
      default:
        return UserRole.gaest;
    }
  }
}

class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final String? avatarUrl;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.avatarUrl,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      displayName:
          json['display_name'] as String? ?? json['full_name'] as String? ?? '',
      role: UserRoleX.fromDb(json['role'] as String?),
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'role': role.dbValue,
        'avatar_url': avatarUrl,
        'created_at': createdAt.toIso8601String(),
      };

  UserProfile copyWith({
    String? displayName,
    UserRole? role,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
    );
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isGuest => role == UserRole.gaest;

  bool get canAccessChat => true;
  bool get canAccessCalendar => true;

  bool get canSeeAllEvents => const [
        UserRole.admin,
        UserRole.jaegerMedlem,
        UserRole.ejer,
        UserRole.forvalter,
        UserRole.bbDirektoer,
      ].contains(role);

  bool get canCreateEvents => const [
        UserRole.admin,
        UserRole.jaegerMedlem,
        UserRole.ejer,
        UserRole.forvalter,
        UserRole.bbDirektoer,
      ].contains(role);

  bool get canEditAllEvents => const [
        UserRole.admin,
        UserRole.jaegerMedlem,
        UserRole.bbDirektoer,
      ].contains(role);

  bool get canEditOwnEvents => const [
        UserRole.ejer,
        UserRole.forvalter,
      ].contains(role);

  bool get canManageEvents => canEditAllEvents;

  bool get canEditMap => role == UserRole.admin;

  bool get canSeeTowers => role != UserRole.gaest;

  bool get canReserveTowers => const [
        UserRole.admin,
        UserRole.jaegerMedlem,
        UserRole.jagtGaest,
      ].contains(role);

  bool get canSeeLivePositions =>
      role == UserRole.admin || role == UserRole.forvalter;

  List<String> get chatRoleAccess => [role.dbValue];
}
