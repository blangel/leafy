import 'package:google_sign_in/google_sign_in.dart';
import 'package:leafy/util/google_drive_util.dart';
import 'package:leafy/util/remote_module.dart';

class GoogleDriveRemoteAccount extends RemoteModule {

  static const _leafyGoogleDriveDirectoryName = 'Leafy Data';

  static const _leafyMnemonicFileName = 'mnemonic_phrase';

  static Future<GoogleDriveRemoteAccount> create(GoogleSignInAccount account) async {
    var util = await GoogleDriveUtil.create(account);
    return GoogleDriveRemoteAccount._(util);
  }

  final GoogleDriveUtil _driveApi;

  GoogleDriveRemoteAccount._(this._driveApi);

  @override
  Future<String?> getEncryptedSecondSeed() async {
    var mnemonicFiles = await _driveApi.getFileFromDirectory(_leafyGoogleDriveDirectoryName, _leafyMnemonicFileName);
    if (mnemonicFiles == null) {
      return null;
    }
    // TODO - what to do on multiple matches (could ask for passphrase and limit to what matches, then further limit to which correspond to valid bitcoin addresses) [currently, take first]
    var mnemonicFile = mnemonicFiles.first.item2!.first;
    if ((mnemonicFile.trashed != null) && mnemonicFile.trashed!) {
      await _driveApi.restore(mnemonicFile);
    }
    return _driveApi.getContent(mnemonicFile.id!);
  }

  @override
  Future<bool> persistEncryptedSecondSeed(String encryptedSecondSeed, SecondSeedValidator validator) async {
    final retrievedFileContent = await _driveApi.createAndRetrieveFile(_leafyGoogleDriveDirectoryName, _leafyMnemonicFileName, encryptedSecondSeed);
    return validator.validate(retrievedFileContent);
  }

}