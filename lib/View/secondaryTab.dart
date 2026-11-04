import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smart_silent/View/nemaz.dart';
import 'package:smart_silent/View/meetings.dart';
import 'package:smart_silent/constants.dart';

import '../Provider/count_provider.dart';

class SecondaryTabBarDemo extends StatelessWidget {
  const SecondaryTabBarDemo({Key? key}) : super(key: key);
  static ValueNotifier<bool> isDataAvailable = ValueNotifier<bool>(false);

// build the app
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CountProvider>(context);
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.purple,
      ),
      debugShowCheckedModeBanner: false,
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.kSecondary,
            foregroundColor: AppColors.kPrimary,
            toolbarHeight: 0,
            elevation: 0,
            bottom: const TabBar(
              indicatorColor: AppColors.kPrimary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(
                  child: Text(
                    "Regular",
                    style: TextStyle(color: AppColors.kPrimary),
                  ),
                ),
                Tab(
                  child: Text(
                    "Prayer Timings",
                    style: TextStyle(color: AppColors.kPrimary),
                  ),
                ),
                // Tab(icon: Icon(Icons.camera_alt)),
                // Tab(icon: Icon(Icons.grade)),
                // Tab(icon: Icon(Icons.email)),
              ],
            ), // TabBar
          ),

          body: TabBarView(
            children: [
              Repeated(),
              Nemaz(),
            ],
          ), // TabBarView
        ), // Scaffold
      ), // DefaultTabController
    ); // MaterialApp
  }
}
