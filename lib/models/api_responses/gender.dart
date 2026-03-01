enum Gender {
  male('male'),
  female('female'),
  nonBinary('non-binary'),
  unspecified('unspecified');

  final String value;
  const Gender(this.value);

  factory Gender.fromValue(String value) {
    return Gender.values.firstWhere(
      (e) => e.value == value,
      orElse: () => Gender.unspecified,
    );
  }
}
