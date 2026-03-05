/// Simple app-wide user type. Can be replaced with shared_preferences later.
class AppState {
  AppState._();

  static String userType = 'Regular User';

  static const String regularUser = 'Regular User';
  static const String technicalUser = 'Technical User';

  static const List<String> userTypeOptions = [regularUser, technicalUser];
}
