import 'dart:math';
import 'dart:typed_data';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:pointycastle/export.dart' as pc;

/// A throwaway RSA key pair, generated fresh each test run. Used only to sign
/// *fake* Firebase tokens in tests, so no key material lives in the repository.
class TestKeyPair {
  TestKeyPair._(this.signing, this.verifying);

  /// Signs tokens (the "Google" side).
  final RSAPrivateKey signing;

  /// What the server uses to check them.
  final RSAPublicKey verifying;

  factory TestKeyPair.generate() {
    final random = pc.FortunaRandom()
      ..seed(pc.KeyParameter(Uint8List.fromList(
          List.generate(32, (_) => Random.secure().nextInt(256)))));
    final generator = pc.RSAKeyGenerator()
      ..init(pc.ParametersWithRandom(
          pc.RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64), random));
    final pair = generator.generateKeyPair();
    return TestKeyPair._(
      RSAPrivateKey.raw(pair.privateKey),
      RSAPublicKey.raw(pair.publicKey),
    );
  }
}

/// Created on first use (top-level finals are lazy), then shared.
final goodKeys = TestKeyPair.generate();
final otherKeys = TestKeyPair.generate();
