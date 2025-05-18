import 'package:flutter/material.dart';


class WelcomeButton extends StatelessWidget {
  const WelcomeButton({super.key,this.ButtonText,this.onTap,this.color,this.Textcolor});
  final String? ButtonText;
  final Widget? onTap;
  final Color? color;
  final Color? Textcolor;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder:(e) => onTap!));
      },
      child: Container(
        padding: const EdgeInsets.all(30.0),
        decoration: BoxDecoration(
          color: color!,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20.0),
          ),
        
        ),
          child: Text(
            ButtonText!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Textcolor!,
              fontSize: 20.0,
            ),
          ),
        ),
    );
  }
}