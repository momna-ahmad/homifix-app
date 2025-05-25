import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'splashScreen.dart' ;

void main() async {

  //for firebase setup
  WidgetsFlutterBinding.ensureInitialized() ;
  if(kIsWeb){
    await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: "AIzaSyDwyFdz1dIB9D1bkWQ3n-gWFCmXoGt-5ew",
          authDomain: "home-services-app-9287d.firebaseapp.com",
          projectId: "home-services-app-9287d",
          storageBucket: "home-services-app-9287d.firebasestorage.app",
          messagingSenderId: "817094934165",
          appId: "1:817094934165:web:963d021bb4926a7f26259c",
          measurementId: "G-5CPXW3DMRN" ,
        )
    ) ;
  }
  else{
    await Firebase.initializeApp() ;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HomiFix',
      theme: ThemeData(
        primaryColor: Color(0xFF4A90E2),
        scaffoldBackgroundColor: Color(0xFFF5F7FA),
        fontFamily: 'Roboto',
      ),
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
