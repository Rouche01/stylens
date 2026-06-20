enum DeepLinkTarget {
  capture,
  closet,
  history,
  session,
  paywall,
  billing,
}

class DeepLinkDestination {
  const DeepLinkDestination(this.target, {this.sessionId});

  final DeepLinkTarget target;
  final String? sessionId;

  static const capture = DeepLinkDestination(DeepLinkTarget.capture);
  static const closet = DeepLinkDestination(DeepLinkTarget.closet);
  static const history = DeepLinkDestination(DeepLinkTarget.history);
  static const paywall = DeepLinkDestination(DeepLinkTarget.paywall);
  static const billing = DeepLinkDestination(DeepLinkTarget.billing);

  static DeepLinkDestination session(String sessionId) =>
      DeepLinkDestination(DeepLinkTarget.session, sessionId: sessionId);
}
