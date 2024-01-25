// RemoteModule is the API for all Remote Account implementations
import 'package:leafy/util/wallet.dart';

abstract class RemoteModule {
  // Retrieves the Second Seed encrypted value from the user's remote account. If found,
  // the data is encrypted and will need to be decrypted based on 'First Seed'.
  Future<String?> getEncryptedSecondSeed();
  // Persists 'encryptedSecondSeed' within the user's remote account.
  // Note, callers should first encrypt data based on 'First Seed'.
  Future<bool> persistEncryptedSecondSeed(String encryptedSecondSeed, SecondSeedValidator validator);
  // Persists 'encryptedData' within the user's remote account. Note, callers should
  // first encrypt data based on 'First Seed' Public Key.
  Future<bool> persistCompanionData(String companionId, String encryptedData);
  // Retrieves persisted data within the user's remote account on behalf of companionId. If found, the data
  // is encrypted and will need to be decrypted based on 'First Seed' Private Key.
  Future<String?> getCompanionData(String companionId);
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
    final decrypted = decryptLeafyData(_firstSeedMnemonic, encryptedSecondSeed, mnemonicLength);
    return (decrypted == _secondSeedMnemonic);
  }

}