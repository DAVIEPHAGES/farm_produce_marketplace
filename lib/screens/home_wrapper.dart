import 'package:flutter/material.dart';
import 'home_page.dart';

class HomeWrapper extends StatelessWidget {
  final String userType;
  
  const HomeWrapper({
    super.key,
    required this.userType,
  });

  @override
  Widget build(BuildContext context) {
    
    return HomePage();
  }
}