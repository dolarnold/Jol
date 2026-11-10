bool isValidStudentEmail(String email) {
  return RegExp(
    r'^[^@\s]+@([a-z0-9-]+\.)+ac\.za$',
    caseSensitive: false,
  ).hasMatch(email.trim());
}
