import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moneyvelocity/app/import_data.dart';
import 'package:moneyvelocity/app/plottingwidget.dart';
import 'package:moneyvelocity/l10n/l10n.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        appBarTheme: const AppBarTheme(color: Color(0xFF13B9FF)),
        colorScheme: ColorScheme.fromSwatch(
          accentColor: const Color(0xFF13B9FF),
        ),
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: FutureBuilder<bool>(
          future: loadImportData(),
          initialData: false,
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            if (snapshot.hasData &&
                snapshot.data is bool &&
                snapshot.data as bool) {
              final plottingData = obtainPlottingData();
              debugPrintSynchronously("Plotting data:\n $plottingData");
              return SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(40),
                  child: PlottingWidget(data: plottingData),
                ),
              );
            }
            return const Text("Loading data");
          },
        ),
      ),
    );
  }
}
