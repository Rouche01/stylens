import 'package:flutter_test/flutter_test.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_destination.dart';
import 'package:gostylens/core/navigation/deep_link/deep_link_parser.dart';

void main() {
  final parser = DeepLinkParser();

  test('parses paywall and billing hosts', () {
    expect(
      parser.parseUri(Uri.parse('gostylens://paywall'))?.target,
      DeepLinkTarget.paywall,
    );
    expect(
      parser.parseUri(Uri.parse('gostylens://billing'))?.target,
      DeepLinkTarget.billing,
    );
    expect(
      parser.parseUri(Uri.parse('gostylens:/paywall'))?.target,
      DeepLinkTarget.paywall,
    );
  });
}
