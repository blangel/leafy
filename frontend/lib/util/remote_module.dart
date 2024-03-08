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
  // first encrypt data based on 'First Seed'.
  Future<bool> persistCompanionData(String companionId, String encryptedData);
  // Retrieves persisted data within the user's remote account on behalf of companionId. If found, the data
  // is encrypted and will need to be decrypted based on 'First Seed'.
  Future<String?> getCompanionData(String companionId);
  // Retrieves companion ids for any with persisted data within the user's remote account.
  Future<List<String>> getCompanionIds();
  // Retrieves the implementation's provider.
  RemoteModuleProvider getProvider();
}

abstract class SecondSeedValidator {
  bool validate(String encryptedSecondSeed);
}

enum RemoteModuleProvider {
  google,
  apple;

  static RemoteModuleProvider? fromName(String? name) {
    if (name == null) {
      return null;
    }
    switch (name) {
      case "google":
        return google;
      case "apple":
        return apple;
      default:
        return null;
    }
  }

  String getDisplayName() {
    switch (this) {
      case google:
        return "Google Drive";
      case apple:
        return "Apple iCloud";
      default:
        throw AssertionError("unimplemented RemoteModuleProvider type: $name");
    }
  }

  String getDisplayShortName() {
    switch (this) {
      case google:
        return "GDrive";
      case apple:
        return "iCloud";
      default:
        throw AssertionError("unimplemented RemoteModuleProvider type: $name");
    }
  }
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