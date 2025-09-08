/// Password validation helper
class PasswordValidation {
  static String? validatePasswords(String password, String? confirmPassword) {
    if (password.isEmpty) {
      return "Password cannot be empty";
    }
    if (confirmPassword != null && password != confirmPassword) {
      return "Passwords do not match";
    }
    if (password.length < 6) {
      return "Password must be at least 6 characters";
    }
    if (password.length > 128) {
      return "Password must be at most 128 characters";
    }
    return null;
  }
}
