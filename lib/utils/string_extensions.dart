extension ExceptionFormat on String {
  String cleanException() {
    var result = this;
    while (result.startsWith('Exception: ')) {
      result = result.replaceFirst('Exception: ', '');
    }
    return result;
  }

  String formatFreeLimitErrorMsg() {
    if (contains('FREE_LIMIT_REACHED')) {
      return 'Free limit reached. Please upgrade to a Core plan for unlimited sessions.';
    }
    return this;
  }
}
