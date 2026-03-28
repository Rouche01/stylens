import 'dart:io';

class SessionUIState {
  String draftText;
  List<File> attachedImageFiles;

  SessionUIState({this.draftText = '', this.attachedImageFiles = const []});

  SessionUIState copyWith({String? draftText, List<File>? attachedImageFiles}) {
    return SessionUIState(
      draftText: draftText ?? this.draftText,
      attachedImageFiles: attachedImageFiles ?? this.attachedImageFiles,
    );
  }
}
