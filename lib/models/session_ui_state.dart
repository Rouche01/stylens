class SessionUIState {
  String draftText;

  SessionUIState({this.draftText = ''});

  SessionUIState copyWith({String? draftText}) {
    return SessionUIState(draftText: draftText ?? this.draftText);
  }
}
