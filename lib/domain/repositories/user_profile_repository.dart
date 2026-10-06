import '../entities/user_profile.dart';

abstract interface class UserProfileRepository {
  Future<UserProfile?> load();
  Future<void> save(UserProfile profile);

  /// Persists a draft without enqueueing cloud backup.
  Future<void> saveLocalOnly(UserProfile profile) => save(profile);
  Future<void> clear();
}
