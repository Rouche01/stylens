extension ExceptionFormat on String {
  String cleanException() {
    if (startsWith('Exception: ')) {
      return replaceFirst('Exception: ', '');
    }
    return this;
  }

  String formatFreeLimitErrorMsg() {
    if (contains('FREE_LIMIT_REACHED')) {
      return 'Free limit reached. Please upgrade to a Core plan for unlimited sessions.';
    }
    return this;
  }
}
