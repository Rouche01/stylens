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
  bool _browseEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBrowseFlag();
  }

  Future<void> _loadBrowseFlag() async {
    final enabled = await locator<FeatureFlagService>().closetBrowseEnabled();
    if (!mounted) return;
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
