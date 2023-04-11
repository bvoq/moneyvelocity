import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GDPData {
  GDPData({
    required this.country,
    required this.date,
    required this.gdpBillionUSD,
  });
  final String country;
  final DateTime date;
  final double gdpBillionUSD;

  @override
  String toString() {
    return "GDPData{country: $country, date: $date, gdpBillionUSD: $gdpBillionUSD}";
  }
}

class M2Data {
  M2Data({
    required this.country,
    required this.date,
    required this.amount,
    required this.currency,
  });
  final String country;
  final DateTime date;
  final double amount;
  final String currency;

  @override
  String toString() {
    return "M2Data{country: $country, date: $date, amount: $amount, currency: $currency}";
  }
}

class CurrencyConversion {
  CurrencyConversion({
    required this.fromCurrency,
    required this.toCurrency,
    required this.date,
    required this.factor,
  }) : assert(toCurrency == "USD");
  final String fromCurrency;
  final String toCurrency;
  final DateTime date;
  final double factor;
  @override
  String toString() {
    return "CurrencyConversion{fromCurrency: $fromCurrency, toCurrency: $toCurrency, date: $date, factor: $factor}";
  }
}

Map<String, List<GDPData>> gdpDatas = {};
Map<String, List<M2Data>> m2Datas = {};
Map<String, List<CurrencyConversion>> currencyConversionDatas = {};

double convertValueAtDateToUSD(String currency, DateTime date, double value) {
  assert(currencyConversionDatas.containsKey(currency));
  assert(currencyConversionDatas[currency]![0].toCurrency == "USD");

  int l = 0;
  int r = currencyConversionDatas[currency]!.length - 1;
  while (l < r) {
    int mid = (l + r) ~/ 2;
    // decide if go left or go right
    bool lower = false;
    if (currencyConversionDatas[currency]![mid].date.isAfter(date)) {
      lower = true;
    }

    if (lower) {
      l = mid + 1;
    } else {
      r = mid;
    }
  }
  debugPrint("chosen ${currencyConversionDatas[currency]![l].date} for $date ");
  return value * currencyConversionDatas[currency]![l].factor;
}

double getVelocityAtDate(DateTime date, String country) {
  assert(m2Datas.containsKey(country));
  assert(gdpDatas.containsKey(country));
  int lm2 = 0;
  int rm2 = m2Datas[country]!.length - 1;
  while (lm2 < rm2) {
    final int midm2 = (lm2 + rm2) ~/ 2;
    // decide if go left or go right
    bool lower = true;
    if (m2Datas[country]![midm2].date.isAfter(date)) {
      lower = false;
    }

    if (lower) {
      lm2 = midm2 + 1;
    } else {
      rm2 = midm2;
    }
  }
  final M2Data finalM2Data = m2Datas[country]![lm2];

  int lgdp = 0;
  int rgdp = gdpDatas[country]!.length - 1;
  while (lgdp < rgdp) {
    final int midgdp = (lgdp + rgdp) ~/ 2;
    // decide if go left or go right
    bool lower = true;

    if (gdpDatas[country]![midgdp].date.isAfter(date)) {
      lower = false;
    }

    if (lower) {
      lgdp = midgdp + 1;
    } else {
      rgdp = midgdp;
    }
  }
  final GDPData finalGDPData = gdpDatas[country]![lgdp];
  debugPrintSynchronously(
      "chosen ${finalM2Data.date} for $date and ${finalGDPData.date} for $date");
  return finalM2Data.amount / (finalGDPData.gdpBillionUSD * 1000 * 1000 * 1000);
}

List<List<Object>> obtainPlottingData() {
  final DateTime from = DateTime(1960, 1, 1);
  final DateTime until = DateTime(2020, 1, 3);

  final List<List<Object>> plottingData = [];
  int countryCount = 0;
  for (final country in m2Datas.keys) {
    if (++countryCount > 19) break;
    for (DateTime date = from;
        date.isBefore(until);
        date = date.add(const Duration(days: 366))) {
      final double velocity = getVelocityAtDate(date, country);
      final dateAsString = "${date.year}/${date.month}/${date.day}";
      plottingData.add([dateAsString, velocity, country]);
    }
  }
  return plottingData;
}

Future<bool> loadImportData() async {
  final String filesAsJson = await rootBundle.loadString('AssetManifest.json');

  final Map<String, dynamic> filesAsJsonMap =
      jsonDecode(filesAsJson) as Map<String, dynamic>;

  final Map<String, List<M2Data>> preM2Datas = {};

  await Future.forEach(
    filesAsJsonMap.keys,
    (String key) async {
      if (key.toLowerCase().contains("gdp")) {
        final csvStr = await rootBundle.loadString(key);
        const delimiter = ",";
        final rowsAsListOfValues = const CsvToListConverter()
            .convert(csvStr, fieldDelimiter: delimiter);
        if (rowsAsListOfValues.isEmpty) return;
        debugPrint("Found $key rowsAsListOfValues: $rowsAsListOfValues");
        rowsAsListOfValues.removeAt(0);

        final gdpData = rowsAsListOfValues
            .map(
              (e) => GDPData(
                country: e[0] as String,
                date: DateTime.parse(
                  "${(e[2] as String).replaceAll("T", " ")}.000",
                ),
                gdpBillionUSD: double.parse(e[3].toString()),
              ),
            )
            .toList();
        gdpDatas[rowsAsListOfValues[0][0] as String] = gdpData;
      }
      if (key.toLowerCase().contains("m2")) {
        final csvStr = await rootBundle.loadString(key);
        const delimiter = ",";
        final rowsAsListOfValues = const CsvToListConverter()
            .convert(csvStr, fieldDelimiter: delimiter);
        if (rowsAsListOfValues.isEmpty) return;
        debugPrint("Found $key m2: $rowsAsListOfValues");
        rowsAsListOfValues.removeAt(0);
        late double multiplier;
        late String currency;
        final String lastPattern = key.split("_").last.split(".").first;

        if (lastPattern.startsWith("thousand")) {
          multiplier = 1000;
          currency = lastPattern.substring("thousand".length);
        } else if (lastPattern.startsWith("million")) {
          multiplier = 1000 * 1000;
          currency = lastPattern.substring("million".length);
        } else if (lastPattern.startsWith("billion")) {
          multiplier = 1000 * 1000 * 1000;
          currency = lastPattern.substring("billion".length);
        } else {
          assert(false);
        }
        final m2Data = rowsAsListOfValues
            .map(
              (e) => M2Data(
                country: e[0] as String,
                date: DateTime.parse(
                  "${(e[2] as String).replaceAll("T", " ")}.000",
                ),
                amount: double.parse(e[3].toString()) * multiplier,
                currency: currency,
              ),
            )
            .toList();
        preM2Datas[rowsAsListOfValues[0][0] as String] = m2Data;
      }

      if (key.toLowerCase().contains("markets_historical")) {
        final currencySwap = key.split("_")[2];
        assert(key.lastIndexOf('usd') > 0);
        final fromCurrency = currencySwap
            .substring(0, currencySwap.lastIndexOf('usd'))
            .toUpperCase();
        const toCurrency = "USD";
        final csvStr = await rootBundle.loadString(key);
        const delimiter = ",";
        final rowsAsListOfValues = const CsvToListConverter()
            .convert(csvStr, fieldDelimiter: delimiter);
        if (rowsAsListOfValues.isEmpty) return;
        debugPrint("Found $key : $rowsAsListOfValues");
        rowsAsListOfValues.removeAt(0);
        final currencyConversionData = rowsAsListOfValues.map(
          (e) {
            final List<String> dateInDDMMYYYYformat =
                (e[1] as String).split('/');
            assert(dateInDDMMYYYYformat.length == 3);

            return CurrencyConversion(
              fromCurrency: fromCurrency,
              toCurrency: toCurrency,
              date: DateTime(
                int.parse(dateInDDMMYYYYformat[2]),
                int.parse(dateInDDMMYYYYformat[1]),
                int.parse(dateInDDMMYYYYformat[0]),
              ),
              factor: double.parse(e[5].toString()),
            );
          },
        ).toList();
        currencyConversionDatas[fromCurrency] = currencyConversionData;
      }
    },
  );
  preM2Datas.forEach((country, prem2datas) {
    for (final prem2data in prem2datas) {
      assert(
        currencyConversionDatas.containsKey(prem2data.currency),
        "Currency ${prem2data.currency} not found.",
      );
      assert(
        gdpDatas.containsKey(prem2data.country),
        "Currency ${prem2data.country} not found.",
      );
      final newValue = convertValueAtDateToUSD(
        prem2data.currency,
        prem2data.date,
        prem2data.amount,
      );
      m2Datas[country] ??= [];
      m2Datas[country]!.add(
        M2Data(
          country: prem2data.country,
          date: prem2data.date,
          amount: newValue,
          currency: "USD",
        ),
      );
    }
  });
  return true;
}
