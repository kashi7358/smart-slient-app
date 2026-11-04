import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smart_silent/View/daily.dart';
import 'package:smart_silent/View/help.dart';
// import 'package:smart_silent/View/daily.dart';
import 'package:smart_silent/View/meetings.dart';
// import 'package:smart_silent/View/secondaryTab.dart'; 
import 'package:smart_silent/View/setings.dart';
import 'package:smart_silent/constants.dart';
import 'package:store_redirect/store_redirect.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Provider/count_provider.dart';
import 'nemaz.dart';

class TabBarDemo extends StatelessWidget {
  const TabBarDemo({Key? key}) : super(key: key);
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
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Consumer<CountProvider>(builder: (context, value, child) {
              print("::value is ${isDataAvailable.value}");

              return Text(
                  provider.hasData ? 'Your Schedules' : 'Create Schedules');
            }),
            backgroundColor: AppColors.kSecondary,
            foregroundColor: AppColors.kPrimary,

            bottom: const TabBar(
              indicatorColor: AppColors.kPrimary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: [
                Tab(
                  child: Text(
                    "One Time",
                    style: TextStyle(color: AppColors.kPrimary),
                  ),
                ),
                Tab(
                  child: Text(
                    "Meetings",
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
          drawer: Drawer(
            child: ListView(
              padding: const EdgeInsets.all(0),
              children: [
                const DrawerHeader(
                  decoration: BoxDecoration(
                    color: Colors.white,
                  ), //BoxDecoration
                  child: Image(image: AssetImage('assets/launcher_icon.png')),
                ), //DrawerHeader
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text(' Settings '),
                  onTap: () {
                    Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => Settings()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help),
                  title: const Text(' Help '),
                  onTap: () {
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (context) => Help()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip),
                  title: const Text(' Privacy Policy '),
                  onTap: () {
                    Navigator.of(context);
                    _launchPrivacypolicy();
                  },
                ),
                Divider(
                  color: AppColors.kPrimary,
                ),
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text(' Share '),
                  onTap: () {
                    Share.share(
                        'Smart Silent - A Silent Scheduler App. Please visit https://play.google.com/store/apps/details?id=com.kawiish.smartsilentt and download and enjoy this awesome app.');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.star),
                  title: const Text(' Rate '),
                  onTap: () {
                    StoreRedirect.redirect(
                      androidAppId: "com.kawiish.smartsilentt",
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.start),
                  title: const Text('More Apps'),
                  onTap: () {
                    _launchPlayStore();
                  },
                ),
              ],
            ),
          ),

          body:  TabBarView(
            children: [
              OneTime(),
              Repeated(),
              Nemaz(),
            ],
          ), // TabBarView
        ), // Scaffold
      ), // DefaultTabController
    ); // MaterialApp
  }

  _launchPlayStore() async {
    final uri = Uri.parse(
        'https://play.google.com/store/apps/developer?id=Kashif+Mushtaq');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch Play Store: $e');
    }
  }

  _launchPrivacypolicy() async {
    final uri = Uri.parse('https://kawiish.com/smart-slient-privacy-policy/');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch Privacy Policy: $e');
    }
  }
}
