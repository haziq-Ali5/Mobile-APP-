import 'package:flutter/material.dart';
import 'package:project/screens/register_screen.dart';
import 'package:project/widgets/custom.dart';
import 'package:project/widgets/welcomebutoon.dart';
import 'package:project/screens/login_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return CustomScarffold(
      child:Column(
        children:[
          Flexible(
            flex: 8,
            child: Container(
            padding: const EdgeInsets.symmetric(
              vertical:0,
              horizontal: 40.0),  
              child: Center (
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    children:[
                      TextSpan(
                        text: 'Welcome Back!\n', 
                        style: TextStyle(
                          fontSize: 45.0,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                      TextSpan(
                        text: 'We are glad to see you again.\n',
                        style: TextStyle(
                          fontSize: 20.0,
                          color: Colors.white,
                        ),
                      )
                    ],
                  ),                ),
              ),
            ),
          ),
          Flexible(
            flex: 2,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Row(
                children: [
                  Expanded(
                    child:WelcomeButton(
                    ButtonText: 'Sign in',
                    onTap: LoginScreen(),
                    color: Colors.transparent,
                    Textcolor: Colors.blue,)
                  ),
                  Expanded(
                    child: WelcomeButton(
                    ButtonText: 'Sign up',
                    onTap: RegisterScreen(),
                    color: Colors.blue,
                    Textcolor: Colors.white,)
                  )
                ],),
            )
            ),
        ]
      ),
      );
  }
}