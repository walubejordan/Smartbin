import 'package:flutter/material.dart';

import 'admin_wireframe.dart';
import 'collector_wireframe.dart';

/// Run for documentation screenshots:
/// `flutter run -t lib/project_documentation/wireframes/wireframe_main.dart -d chrome`
void main() {
  runApp(const WireframePreviewApp());
}

class WireframePreviewApp extends StatelessWidget {
  const WireframePreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
      ),
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('[Wireframe preview]'),
            bottom: const TabBar(
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.black,
              tabs: [
                Tab(text: 'Admin'),
                Tab(text: 'Collector'),
              ],
            ),
          ),
          body: const TabBarView(
            children: [
              AdminDashboardWireframe(),
              CollectorDashboardWireframe(),
            ],
          ),
        ),
      ),
    );
  }
}
