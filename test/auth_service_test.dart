import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectrack1/service/auth_service.dart';

void main() {
  group('AuthService bcrypt', () {
    test('hashPassword returns a bcrypt hash with embedded salt', () {
      final hash = AuthService.hashPassword('Secret123!');
      expect(AuthService.isBcryptHash(hash), isTrue);
      expect(hash, isNot(equals('Secret123!')));
    });

    test('same password yields different hashes (unique salts)', () {
      final a = AuthService.hashPassword('Secret123!');
      final b = AuthService.hashPassword('Secret123!');
      expect(a, isNot(equals(b)));
      expect(AuthService.verifyPassword('Secret123!', a), isTrue);
      expect(AuthService.verifyPassword('Secret123!', b), isTrue);
    });

    test('verifyPassword accepts correct password and rejects wrong one', () {
      final hash = AuthService.hashPassword('correct-horse');
      expect(AuthService.verifyPassword('correct-horse', hash), isTrue);
      expect(AuthService.verifyPassword('wrong-password', hash), isFalse);
    });
  });

  group('AuthService format detection', () {
    test('isBcryptHash recognizes common prefixes', () {
      expect(
        AuthService.isBcryptHash(
          r'$2a$12$R9h/cIPz0gi.URNNX3kh2OPST9/PgBkqquzi.Ss7KIUgO2t0jWMUW',
        ),
        isTrue,
      );
      expect(AuthService.isBcryptHash('not-a-hash'), isFalse);
      expect(AuthService.isBcryptHash(''), isFalse);
    });

    test('isLegacySha256Hash only matches 64 hex chars', () {
      final legacy = sha256
          .convert(
            utf8.encode('${AuthService.legacySha256Salt}password'),
          )
          .toString();
      expect(AuthService.isLegacySha256Hash(legacy), isTrue);
      expect(AuthService.isLegacySha256Hash('plaintext'), isFalse);
      expect(AuthService.isLegacySha256Hash('abc'), isFalse);
    });
  });

  group('AuthService legacy migration helpers', () {
    test('verifyPassword accepts legacy SHA-256 hashes', () {
      final legacy = sha256
          .convert(
            utf8.encode('${AuthService.legacySha256Salt}old-password'),
          )
          .toString();
      expect(AuthService.verifyPassword('old-password', legacy), isTrue);
      expect(AuthService.verifyPassword('other', legacy), isFalse);
      expect(AuthService.needsBcryptMigration(legacy), isTrue);
    });

    test('plaintext passwords are rejected (no fallback)', () {
      expect(AuthService.verifyPassword('secret', 'secret'), isFalse);
      expect(AuthService.needsBcryptMigration('secret'), isFalse);
    });

    test('empty password or hash is rejected', () {
      final hash = AuthService.hashPassword('x');
      expect(AuthService.verifyPassword('', hash), isFalse);
      expect(AuthService.verifyPassword('x', ''), isFalse);
    });

    test('needsBcryptMigration is false for bcrypt hashes', () {
      final hash = AuthService.hashPassword('migrate-me');
      expect(AuthService.needsBcryptMigration(hash), isFalse);
    });
  });
}
