import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final jolThemeModeProvider =
    NotifierProvider<JolThemeModeController, ThemeMode>(
      JolThemeModeController.new,
    );

class JolThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
}
