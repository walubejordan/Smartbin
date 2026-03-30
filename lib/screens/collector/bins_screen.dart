import 'package:flutter/material.dart';

import '../bins_screen.dart';

/// Collector "My bins" with [BinsScreen.enableCollection] and map deep links.
class CollectorBinsScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final void Function(double lat, double lng)? onShowBinOnMap;
  final VoidCallback? onCollectionComplete;
  final GlobalKey<BinsScreenState>? binsListKey;

  const CollectorBinsScreen({
    super.key,
    required this.user,
    this.onShowBinOnMap,
    this.onCollectionComplete,
    this.binsListKey,
  });

  @override
  Widget build(BuildContext context) {
    return BinsScreen(
      key: binsListKey,
      user: user,
      onShowBinOnMap: onShowBinOnMap,
      enableCollection: true,
      onCollectionComplete: onCollectionComplete,
    );
  }
}
