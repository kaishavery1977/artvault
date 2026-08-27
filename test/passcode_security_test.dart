// Security-focused tests for the passcode hash format and brute-force
// throttle. These verify the migration away from salted SHA-256 toward
// PBKDF2-HMAC-SHA256 and the persisted lockout behaviour without needing a
// device or Firebase.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artvault/core/constants/app_constants.dart';
import 'package:artvault/data/repositories/auth_repository.dart';

import 'hive_test_harness.dart';

// A persistent secure-storage mock: writes are kept in memory so the
// stored passcode digest survives across calls within a test.
final Map<String, String> _secureStore = <String, String>{};

void _stubSecureStoragePersist() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'read') {
          return _secureStore[call.arguments['key'] as String];
        }
        if (call.method == 'write') {
          _secureStore[call.arguments['key'] as String] =
              call.arguments['value'] as String;
          return null;
        }
        if (call.method == 'delete') {
          _secureStore.remove(call.arguments['key'] as String);
          return null;
        }
        return null;
      });
}

// Reads the value currently held by the secure-storage mock.
Future<String?> _readStoredHash() async =>
    _secureStore[AppConstants.kPasscodeHash];

// Writes a value into the secure-storage mock.
Future<void> _writeStoredHash(String value) async {
  _secureStore[AppConstants.kPasscodeHash] = value;
}

// Builds a stored digest string for a known salt/iterations/digest so a
// test can simulate an existing v2 record (e.g. the RFC 6070 vectors).
String storedV2(String saltHex, int iterations, String digestHex) =>
    'v2:$saltHex:$iterations:$digestHex';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => initTestHive());
  setUp(() async {
    _secureStore.clear();
    await clearTestSettings();
    _stubSecureStoragePersist();
  });

  group('Passcode hash (PBKDF2-HMAC-SHA256)', () {
    test('matches the RFC 6070 vector for c=1', () async {
      // password="password", salt="salt", c=1.
      const saltHex = '73616c74';
      const dk =
          '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b';
      await _writeStoredHash(storedV2(saltHex, 1, dk));
      expect(await AuthRepository.instance.verifyPasscode('password'), isTrue);
      expect(await AuthRepository.instance.verifyPasscode('wrong'), isFalse);
    });

    test('matches the RFC 6070 vector for c=2', () async {
      const saltHex = '73616c74';
      const dk =
          'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43';
      await _writeStoredHash(storedV2(saltHex, 2, dk));
      expect(await AuthRepository.instance.verifyPasscode('password'), isTrue);
      expect(
        await AuthRepository.instance.verifyPasscode('password2'),
        isFalse,
      );
    });

    test(
      'setPasscode stores a salted v2 digest and verifies round-trip',
      () async {
        await AuthRepository.instance.setPasscode('1234');
        final stored = await _readStoredHash();
        expect(stored, startsWith('v2:'));
        expect(stored!.length, greaterThan(80));
        expect(
          stored,
          contains(':150000:'),
          reason: 'production iteration count must stay high',
        );
        expect(await AuthRepository.instance.passcodeSet, isTrue);
        expect(await AuthRepository.instance.verifyPasscode('1234'), isTrue);
        expect(await AuthRepository.instance.verifyPasscode('0000'), isFalse);
      },
    );

    test(
      'legacy v1 salted-SHA256 digests still verify and auto-upgrade',
      () async {
        // Old format: "<hex salt>:<sha256 of 'salt:pin'>".
        const salt = 'a1b2c3d4';
        await _writeStoredHash('$salt:${cryptoSha256('$salt:2468')}');
        expect(await AuthRepository.instance.verifyPasscode('2468'), isTrue);
        // Successful verify rewrites the stored hash as v2.
        final stored = await _readStoredHash();
        expect(stored, startsWith('v2:'));
        expect(await AuthRepository.instance.verifyPasscode('2468'), isTrue);
      },
    );

    test('clearing the passcode removes the digest', () async {
      await AuthRepository.instance.setPasscode('9876');
      await AuthRepository.instance.clearPasscode();
      expect(await AuthRepository.instance.passcodeSet, isFalse);
    });
  });

  group('Passcode brute-force throttle', () {
    test('stays quiet below the attempt threshold', () async {
      for (var i = 0; i < 4; i++) {
        expect(
          await AuthRepository.instance.registerPasscodeFailure(),
          Duration.zero,
        );
      }
    });

    test(
      'escalates exponentially after the threshold, capped at 10 minutes',
      () async {
        expect(
          await AuthRepository.instance.registerPasscodeFailure(),
          Duration.zero,
        ); // 1
        expect(
          await AuthRepository.instance.registerPasscodeFailure(),
          Duration.zero,
        ); // 2
        expect(
          await AuthRepository.instance.registerPasscodeFailure(),
          Duration.zero,
        ); // 3
        expect(
          await AuthRepository.instance.registerPasscodeFailure(),
          Duration.zero,
        ); // 4
        expect(
          await AuthRepository.instance.registerPasscodeFailure(),
          const Duration(seconds: 30),
        ); // 5 → first lockout
        expect(
          await AuthRepository.instance.registerPasscodeFailure(),
          const Duration(seconds: 60),
        ); // 6
        expect(
          await AuthRepository.instance.registerPasscodeFailure(),
          const Duration(seconds: 120),
        ); // 7
        expect(
          await AuthRepository.instance.registerPasscodeFailure(),
          const Duration(seconds: 240),
        ); // 8
        expect(
          await AuthRepository.instance.registerPasscodeFailure(),
          const Duration(seconds: 480),
        ); // 9
        expect(
          await AuthRepository.instance.registerPasscodeFailure(),
          const Duration(minutes: 10),
        ); // 10 → capped
        expect(
          await AuthRepository.instance.registerPasscodeFailure(),
          const Duration(minutes: 10),
        ); // 11 → stays capped
      },
    );

    test(
      'a live lockout is visible and survives (persisted timestamp)',
      () async {
        for (var i = 0; i < 5; i++) {
          await AuthRepository.instance.registerPasscodeFailure();
        }
        final remaining = await AuthRepository.instance.passcodeLockRemaining();
        expect(remaining, greaterThan(Duration.zero));
        expect(remaining, lessThanOrEqualTo(const Duration(seconds: 30)));
        expect(
          int.tryParse(_secureStore[AppConstants.kPasscodeFailures] ?? '') ?? 0,
          5,
        );
      },
    );

    test(
      'resetPasscodeAttempts clears the failure count and lockout',
      () async {
        for (var i = 0; i < 7; i++) {
          await AuthRepository.instance.registerPasscodeFailure();
        }
        await AuthRepository.instance.resetPasscodeAttempts();
        expect(
          await AuthRepository.instance.passcodeLockRemaining(),
          Duration.zero,
        );
        expect(
          int.tryParse(_secureStore[AppConstants.kPasscodeFailures] ?? '') ?? 0,
          0,
        );
        // Counter restarts from zero after a successful unlock.
        expect(
          await AuthRepository.instance.registerPasscodeFailure(),
          Duration.zero,
        );
      },
    );
  });
}

String cryptoSha256(String input) => _sha256(
  utf8.encode(input),
).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

// Minimal sha256 for the legacy-digest test fixture (avoids importing a
// hashing package just to build one test string).
List<int> _sha256(List<int> msg) {
  final m = List<int>.from(msg);
  final bitLen = m.length * 8;
  m.add(0x80);
  while (m.length % 64 != 56) {
    m.add(0);
  }
  void addLen(int value) {
    for (var i = 0; i < 8; i++) {
      m.add((value >> ((7 - i) * 8)) & 0xff);
    }
  }

  addLen(bitLen);
  const k = [
    0x428a2f98,
    0x71374491,
    0xb5c0fbcf,
    0xe9b5dba5,
    0x3956c25b,
    0x59f111f1,
    0x923f82a4,
    0xab1c5ed5,
    0xd807aa98,
    0x12835b01,
    0x243185be,
    0x550c7dc3,
    0x72be5d74,
    0x80deb1fe,
    0x9bdc06a7,
    0xc19bf174,
    0xe49b69c1,
    0xefbe4786,
    0x0fc19dc6,
    0x240ca1cc,
    0x2de92c6f,
    0x4a7484aa,
    0x5cb0a9dc,
    0x76f988da,
    0x983e5152,
    0xa831c66d,
    0xb00327c8,
    0xbf597fc7,
    0xc6e00bf3,
    0xd5a79147,
    0x06ca6351,
    0x14292967,
    0x27b70a85,
    0x2e1b2138,
    0x4d2c6dfc,
    0x53380d13,
    0x650a7354,
    0x766a0abb,
    0x81c2c92e,
    0x92722c85,
    0xa2bfe8a1,
    0xa81a664b,
    0xc24b8b70,
    0xc76c51a3,
    0xd192e819,
    0xd6990624,
    0xf40e3585,
    0x106aa070,
    0x19a4c116,
    0x1e376c08,
    0x2748774c,
    0x34b0bcb5,
    0x391c0cb3,
    0x4ed8aa4a,
    0x5b9cca4f,
    0x682e6ff3,
    0x748f82ee,
    0x78a5636f,
    0x84c87814,
    0x8cc70208,
    0x90befffa,
    0xa4506ceb,
    0xbef9a3f7,
    0xc67178f2,
  ];
  var h = [
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];
  for (var i = 0; i < m.length; i += 64) {
    final w = List<int>.filled(64, 0);
    for (var t = 0; t < 16; t++) {
      w[t] =
          (m[i + t * 4] << 24) |
          (m[i + t * 4 + 1] << 16) |
          (m[i + t * 4 + 2] << 8) |
          m[i + t * 4 + 3];
    }
    for (var t = 16; t < 64; t++) {
      final s0 = _rotr(w[t - 15], 7) ^ _rotr(w[t - 15], 18) ^ (w[t - 15] >>> 3);
      final s1 = _rotr(w[t - 2], 17) ^ _rotr(w[t - 2], 19) ^ (w[t - 2] >>> 10);
      w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & 0xffffffff;
    }
    var a = h[0], b = h[1], c = h[2], d = h[3];
    var e = h[4], f = h[5], g = h[6], hh = h[7];
    for (var t = 0; t < 64; t++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ (~e & g);
      final temp1 = (hh + s1 + ch + k[t] + w[t]) & 0xffffffff;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (s0 + maj) & 0xffffffff;
      hh = g;
      g = f;
      f = e;
      e = (d + temp1) & 0xffffffff;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & 0xffffffff;
    }
    h[0] = (h[0] + a) & 0xffffffff;
    h[1] = (h[1] + b) & 0xffffffff;
    h[2] = (h[2] + c) & 0xffffffff;
    h[3] = (h[3] + d) & 0xffffffff;
    h[4] = (h[4] + e) & 0xffffffff;
    h[5] = (h[5] + f) & 0xffffffff;
    h[6] = (h[6] + g) & 0xffffffff;
    h[7] = (h[7] + hh) & 0xffffffff;
  }
  return h
      .expand(
        (x) => [(x >> 24) & 0xff, (x >> 16) & 0xff, (x >> 8) & 0xff, x & 0xff],
      )
      .toList();
}

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & 0xffffffff;
