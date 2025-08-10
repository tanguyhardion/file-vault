/// Password validation helper
class PasswordValidation {
  static String? validatePasswords(String password, String? confirmPassword) {
    if (password.isEmpty) {
      return "Password cannot be empty";
    }
    if (confirmPassword != null && password != confirmPassword) {
      return "Passwords do not match";
    }
    return null;
  }
}
