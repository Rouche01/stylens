import 'dart:io';
import 'package:gostylens/models/remote_image.dart';

class AppImage {
  final File? localFile;
  final RemoteImage? remoteImage;

  AppImage({this.localFile, this.remoteImage});
}
