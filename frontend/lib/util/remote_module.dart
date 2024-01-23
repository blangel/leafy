// RemoteModule is the API for all Remote Account implementations
import 'package:leafy/util/wallet.dart';

abstract class RemoteModule {
  Future<String?> getEncryptedSecondSeed();
  Future<bool> persistEncryptedSecondSeed(String encryptedSecondSeed, SecondSeedValidator validator);
}

abstract class SecondSeedValidator {
  bool validate(String encryptedSecondSeed);
}

class DefaultSecondSeedValidator implements SecondSeedValidator {

  static DefaultSecondSeedValidator create(String firstSeedMnemonic, String secondSeedMnemonic) {
    return DefaultSecondSeedValidator._(firstSeedMnemonic, secondSeedMnemonic);
  }

  final String _firstSeedMnemonic;

  final String _secondSeedMnemonic;

  DefaultSecondSeedValidator._(this._firstSeedMnemonic, this._secondSeedMnemonic);

  @override
  bool validate(String encryptedSecondSeed) {
    final decrypted = decryptLeafyData(_firstSeedMnemonic, encryptedSecondSeed);
    return (decrypted == _secondSeedMnemonic);
  }

}