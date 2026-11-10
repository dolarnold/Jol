import 'package:flutter_test/flutter_test.dart';
import 'package:jol/features/auth/student_email_validator.dart';

void main() {
  group('isValidStudentEmail', () {
    test('accepts university subdomains ending in .ac.za', () {
      expect(isValidStudentEmail('name@myuct.ac.za'), isTrue);
      expect(isValidStudentEmail('Name@dept.university.ac.za'), isTrue);
      expect(isValidStudentEmail(' name@myuct.ac.za '), isTrue);
    });

    test('rejects non-university and malformed addresses', () {
      expect(isValidStudentEmail('name@college.co.za'), isFalse);
      expect(isValidStudentEmail('name@example.com'), isFalse);
      expect(isValidStudentEmail('not an email'), isFalse);
      expect(isValidStudentEmail(''), isFalse);
    });
  });
}
