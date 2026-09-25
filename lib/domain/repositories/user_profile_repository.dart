
import '../entities/user_profile.dart';

abstract interface class UserProfileRepository {
  Future<UserProfile?> load();
  Future<void> save(UserProfile profile);
  Future<void> clear();
}
