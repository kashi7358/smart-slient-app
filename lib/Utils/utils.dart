// import 'package:another_flushbar/flushbar.dart';
// import 'package:another_flushbar/flushbar_route.dart';
// import 'package:flutter/material.dart';

// import '../constants.dart';

// class Utils {
//   static flushBarErrorMessageWithAction(
//       String message, VoidCallback _onpress, BuildContext context) {
//     showFlushbar(
//         context: context,
//         flushbar: Flushbar(
//           positionOffset: 50,
//           padding: EdgeInsets.all(26),
//           borderRadius: BorderRadius.circular(20),
//           backgroundColor: AppColors.kSecondary,
//           messageColor: AppColors.kPrimary,
//           message: message,
//           duration: Duration(seconds: 5),
//           flushbarPosition: FlushbarPosition.TOP,
//           mainButton: IconButton(
//             icon: Icon(
//               Icons.login_outlined,
//             ),
//             onPressed: _onpress,
//           ),
//         )..show(context));
//   }
// }



// class CustomSnackbar {
//   static void showSnackbar(String message, String actionText, VoidCallback onActionPressed) {
//     final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

//     WidgetsBinding.instance!.addPostFrameCallback((_) {
//       OverlayState? overlayState = navigatorKey.currentState?.overlay;
//       OverlayEntry? overlayEntry;
//       overlayEntry = OverlayEntry(
//         builder: (BuildContext context) {
//           return Positioned(
//             bottom: 16.0,
//             left: 16.0,
//             right: 16.0,
//             child: Material(
//               elevation: 4.0,
//               borderRadius: BorderRadius.circular(8.0),
//               child: Container(
//                 padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         message,
//                         style: TextStyle(fontSize: 16.0),
//                       ),
//                     ),
//                     TextButton(
//                       onPressed: () {
//                         overlayEntry!.remove();
//                         onActionPressed();
//                       },
//                       child: Text(actionText),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           );
//         },
//       );
//       overlayState?.insert(overlayEntry);
//     });
//   }
// }



// check this out if cahnages goes there

