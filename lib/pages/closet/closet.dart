import 'package:flutter/material.dart';
import 'package:gostylens/core/config/dependency_injection.dart';
import 'package:gostylens/core/services/feature_flag_service.dart';
import 'package:gostylens/pages/closet/closet_browse.dart';
import 'package:gostylens/pages/closet/closet_waitlist.dart';

class ClosetPage extends StatefulWidget {
  const ClosetPage({super.key});

  @override
  State<ClosetPage> createState() => _ClosetPageState();
}

class _ClosetPageState extends State<ClosetPage> {
  late final FeatureFlagService _flags;
  bool _browseEnabled = false;

  @override
  void initState() {
    super.initState();
    _flags = locator<FeatureFlagService>();
    _flags.addListener(_onFlagsChanged);
    _loadBrowseFlag();
  }

  @override
  void dispose() {
    _flags.removeListener(_onFlagsChanged);
    super.dispose();
  }

  void _onFlagsChanged() => _loadBrowseFlag();

  Future<void> _loadBrowseFlag() async {
    final enabled = await _flags.closetBrowseEnabled();
    if (!mounted) return;
    if (_browseEnabled == enabled) return;
    setState(() => _browseEnabled = enabled);
  }

  @override
  Widget build(BuildContext context) {
    if (_browseEnabled) {
      return const ClosetBrowseView();
    }
    return const ClosetWaitlistView();
  }
}
