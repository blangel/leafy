import 'package:google_sign_in/google_sign_in.dart';
import 'package:leafy/util/google_drive_util.dart';
import 'package:leafy/util/remote_module.dart';

class GoogleDriveRemoteAccount extends RemoteModule {

  static Future<GoogleDriveRemoteAccount> create(GoogleSignInAccount account) async {
    var util = await GoogleDriveUtil.create(account);
    return GoogleDriveRemoteAccount._(util);
  }

  final GoogleDriveUtil _driveApi;

  GoogleDriveRemoteAccount._(this._driveApi);

  @override
  Future<String?> getEncryptedSecondSeed() async {
    var mnemonicFile = await _driveApi.getMnemonicFile();
    if (mnemonicFile == null) {
      return null;
    }
    if ((mnemonicFile.trashed != null) && mnemonicFile.trashed!) {
      await _driveApi.restore(mnemonicFile);
    }
    return _driveApi.getContent(mnemonicFile.id!);
  }

  @override
  Future<bool> persistEncryptedSecondSeed(String encryptedSecondSeed, SecondSeedValidator validator) async {
    final retrievedFileContent = await _driveApi.createAndRetrieveMnemonicFile(encryptedSecondSeed);
    return validator.validate(retrievedFileContent);
  }

}