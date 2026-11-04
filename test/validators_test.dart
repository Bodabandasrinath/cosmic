import 'package:flutter_test/flutter_test.dart';
import 'package:cosmic/core/utils/validators.dart';

void main() {
  group('Validators Unit Tests', () {
    test('Indian Mobile Number Validator', () {
      // Valid numbers starting with 6, 7, 8, 9 and exactly 10 digits
      expect(Validators.validateIndianPhone('9876543210'), isNull);
      expect(Validators.validateIndianPhone('8123456789'), isNull);
      expect(Validators.validateIndianPhone('7001122334'), isNull);
      expect(Validators.validateIndianPhone('6234567890'), isNull);
      expect(Validators.validateIndianPhone('98765 43210'), isNull);

      // Invalid numbers
      expect(Validators.validateIndianPhone(''), isNotNull);
      expect(Validators.validateIndianPhone(null), isNotNull);
      expect(Validators.validateIndianPhone('5876543210'), isNotNull); // starts with 5
      expect(Validators.validateIndianPhone('987654321'), isNotNull);  // 9 digits
      expect(Validators.validateIndianPhone('98765432100'), isNotNull); // 11 digits
      expect(Validators.validateIndianPhone('abcdefghij'), isNotNull);
    });

    test('Email Validator', () {
      expect(Validators.validateEmail('user@cosmic.com'), isNull);
      expect(Validators.validateEmail('rahul.sharma@gmail.com'), isNull);
      expect(Validators.validateEmail(''), isNotNull);
      expect(Validators.validateEmail('invalid-email'), isNotNull);
      expect(Validators.validateEmail('user@'), isNotNull);
    });

    test('Password Validator', () {
      expect(Validators.validatePassword('secret123'), isNull);
      expect(Validators.validatePassword('123456'), isNull);
      expect(Validators.validatePassword('12345'), isNotNull); // <6
      expect(Validators.validatePassword(''), isNotNull);
    });

    test('Username Validator', () {
      expect(Validators.validateUsername('rahul_sharma'), isNull);
      expect(Validators.validateUsername('user.123'), isNull);
      expect(Validators.validateUsername('ab'), isNotNull); // <3
      expect(Validators.validateUsername('user with spaces'), isNotNull);
    });
  });
}

