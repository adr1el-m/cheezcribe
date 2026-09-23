import 'package:flutter/material.dart';

const ink = Color(0xFF10171B);
const surface = Color(0xFF1C252B);
const mint = Color(0xFFC6F590);
const muted = Color(0xFF9DAAB0);
const line = Color(0xFF334047);
const coral = Color(0xFFFFB8A0);

final studioTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: ink,
  colorScheme: const ColorScheme.dark(
    primary: mint,
    onPrimary: ink,
    surface: surface,
    onSurface: Color(0xFFF2F5F3),
    secondary: coral,
  ),
  appBarTheme: const AppBarTheme(backgroundColor: ink, centerTitle: false),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: surface,
    labelStyle: const TextStyle(color: muted),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: line)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: line)),
  ),
  filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
    minimumSize: const Size(0, 56),
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  )),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: ink,
    indicatorColor: surface,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
  ),
);
