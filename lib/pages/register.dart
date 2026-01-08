import 'package:flutter/material.dart';
import 'package:food_order/pages/login_page.dart';

class Register extends StatelessWidget {
  const Register({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return const LoginOrRegisterPage();
  }
}
