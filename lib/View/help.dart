import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/container.dart';
import 'package:flutter/src/widgets/framework.dart';

import '../constants.dart';

class Help extends StatefulWidget {
  const Help({super.key});

  @override
  State<Help> createState() => _HelpState();
}

class _HelpState extends State<Help> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.kbg,
      appBar: AppBar(
        title: Text("How to use"),
        backgroundColor: AppColors.kSecondary,
        foregroundColor: AppColors.kPrimary,),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
                title: Text(
                  'Quick Schedule',
                  textScaleFactor: 1.5,
                ),
                // trailing: Icon(Icons.done),
                subtitle: Text(
                    'Tap (+) button then set minutes and tap on quick silent. It will create your fixed minute quick silent schedule.'),
                selected: true,
                ),
          ),
          SizedBox(
            height: 10,
          ),Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
                title: Text(
                  'Create Schedule',
                  textScaleFactor: 1.5,
                ),
                // trailing: Icon(Icons.done),
                subtitle: Text(
                    'Tap (+) button then set minutes and tap on Calendar or set daily.then add name and other fields according to your need and press save .It will create your schedule.'),
                selected: true,
                ),
          ),
          SizedBox(
            height: 10,
          ),Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
                title: Text(
                  'Update Schedule',
                  textScaleFactor: 1.5,
                ),
                // trailing: Icon(Icons.done),
                subtitle: Text(
                    'Tap on the specific schedule then edit the fields and press save .It will update your schedule.'),
                selected: true,
                ),
          ),
           SizedBox(
            height: 10,
          ),Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
                title: Text(
                  'Delete Schedule',
                  textScaleFactor: 1.5,
                ),
                // trailing: Icon(Icons.done),
                subtitle: Text(
                    'Long press on any schedule then press ok to delete your schedule.'),
                selected: true,
                ),
          ),
        ],
      ),
      );
  }
}