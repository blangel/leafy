
import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:leafy/util/google_signin_util.dart';
import 'package:tuple/tuple.dart';

const _googleDriveFolderMimeType = 'application/vnd.google-apps.folder';

const _googleDriveAppDataFolder = 'appDataFolder';

class GoogleDriveUtil {

  static Future<GoogleDriveUtil> create(GoogleSignInAccount account) async {
    final authenticateClient = await GoogleAuthClient.create(account);
    final googleDriveApi = DriveApi(authenticateClient);
    return GoogleDriveUtil._(googleDriveApi);
  }

  final DriveApi _driveApi;

  GoogleDriveUtil._(this._driveApi);

  Future<String> updateFile(File file, String data) async {
    List<int> dataBytes = utf8.encode(data);
    Stream<List<int>> dataStream = Stream.fromIterable([dataBytes]);
    var media = Media(dataStream, dataBytes.length);
    final updatedFile = await _driveApi.files.update(file, file.id!, uploadMedia: media);
    return getContent(updatedFile.id!);
  }

  Future<List<Tuple2<File, List<File>?>>?> getFileFromAppDirectory(String fileName, bool prefixMatch) async {
    return getFileFromDirectory(_googleDriveAppDataFolder, fileName, prefixMatch);
  }

  Future<List<Tuple2<File, List<File>?>>?> getFileFromDirectory(String directoryName, String fileName, bool prefixMatch) async {
    if (_googleDriveAppDataFolder == directoryName) {
      // see https://developers.google.com/drive/api/guides/appdata#search-files
      var response = await _driveApi.files.list(spaces: directoryName);
      List<Tuple2<File, List<File>?>> matches = [];
      if (response.files != null) {
        List<File> matchedFiles = [];
        for (var file in response.files!) {
          if (file.name == fileName
              || (prefixMatch && file.name != null && file.name!.startsWith(fileName))) {
            matchedFiles.add(file);
          }
        }
        if (matchedFiles.isNotEmpty) {
          matches.add(Tuple2(File()..id=directoryName..name=directoryName, matchedFiles));
        }
      }
      return matches;
    }
    var response = await _driveApi.files.list(q: "name='$directoryName' and mimeType='$_googleDriveFolderMimeType'");
    if (response.files == null || response.files!.isEmpty) {
      return null;
    } else {
      List<Tuple2<File, List<File>?>> matches = [];
      for (var folder in response.files!) {
        var files = await _getFilesInDirectory(folder, fileName);
        if (files != null) {
          matches.add(Tuple2(folder, files));
        }
      }
      return matches;
    }
  }

  Future<List<File>?> _getFilesInDirectory(File directory, String fileName) async {
    var response = await _driveApi.files.list(q: "'${directory.id}' in parents and name='$fileName'", $fields: "files(id, name, mimeType, trashed, parents)");
    if (response.files == null || response.files!.isEmpty) {
      return null;
    } else {
      return response.files!;
    }
  }

  Future<File> _getDirectoryOrCreate(String directoryName, String fileName) async {
    if (_googleDriveAppDataFolder == directoryName) {
      // name is the id; see https://developers.google.com/drive/api/guides/appdata
      return File()..id=_googleDriveAppDataFolder;
    }
    File directory;
    var directoryPair = await getFileFromDirectory(directoryName, fileName, false);
    if (directoryPair == null) {
      directory = File()
        ..name = directoryName
        ..mimeType = _googleDriveFolderMimeType;
      directory = await _driveApi.files.create(directory, useContentAsIndexableText: false, keepRevisionForever: true);
    } else {
      directory = directoryPair.first.item1;
    }
    return directory;
  }

  Future<String> createAndRetrieveFileFromAppDirectory(String fileName, String data) async {
    return createAndRetrieveFile(_googleDriveAppDataFolder, fileName, data);
  }

  Future<String> createAndRetrieveFile(String directoryName, String fileName, String data) async {
    final directory = await _getDirectoryOrCreate(directoryName, fileName);

    var file = File()
      ..name = fileName
      ..mimeType = 'text/plain'
      ..parents = [directory.id!];
    List<int> dataBytes = utf8.encode(data);
    Stream<List<int>> dataStream = Stream.fromIterable([dataBytes]);
    var media = Media(dataStream, dataBytes.length);
    final createdFile = await _driveApi.files.create(file, uploadMedia: media,
        useContentAsIndexableText: false, keepRevisionForever: true);
    return getContent(createdFile.id!);
  }

  Future<String> getContent(String fileId) async {
    final retrievedFileMedia = await _driveApi.files.get(fileId, downloadOptions: DownloadOptions.fullMedia) as Media;
    final retrievedFileStream = retrievedFileMedia.stream.transform(utf8.decoder);
    return await retrievedFileStream.join();
  }

  Future<void> restore(File trashed) async {
    await _restoreItem(trashed.id!);
  }

  Future<void> _restoreItem(String id) async {
    var item = await _driveApi.files.get(id, $fields: 'id,name,trashed,parents') as File;
    if (item.parents != null && item.parents!.isNotEmpty) {
      for (var parentId in item.parents!) {
        await _restoreItem(parentId);
      }
    }
    if (item.trashed == true) {
      await _driveApi.files.update(File()..trashed = false, id);
    }
  }

}