import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ScannerScreen(),
    );
  }
}

class ScannerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scan Product')),
      body: MobileScanner(
        onDetect: (barcode, args) {
          final String? code = barcode.rawValue;
          if (code != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ResultScreen(barcode: code),
              ),
            );
          }
        },
      ),
    );
  }
}

class ResultScreen extends StatefulWidget {
  final String barcode;
  ResultScreen({required this.barcode});

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Map data = {};
  bool loading = true;
  double score = 0;
  List<String> badIngredients = [];

  @override
  void initState() {
    super.initState();
    fetchProduct();
  }

  Future<void> fetchProduct() async {
    final url =
        "https://world.openfoodfacts.org/api/v0/product/${widget.barcode}.json";
    final res = await http.get(Uri.parse(url));
    final jsonData = json.decode(res.body);

    if (jsonData["status"] == 1) {
      final product = jsonData["product"];
      final ingredientsText = product["ingredients_text"] ?? "";

      calculateScore(ingredientsText);

      setState(() {
        data = product;
        loading = false;
      });
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  void calculateScore(String ingredients) {
    List<String> list = ingredients.split(",");
    List<String> risky = [
      "e",
      "palm",
      "sugar",
      "sweet",
      "color",
      "preserv",
      "emuls"
    ];

    int total = list.length;
    int bad = 0;

    for (var ing in list) {
      String lower = ing.toLowerCase();
      if (risky.any((r) => lower.contains(r))) {
        bad++;
        badIngredients.add(ing.trim());
      }
    }

    score = total == 0 ? 0 : ((total - bad) / total) * 100;
  }

  String getStatus() {
    if (score >= 80) return "SAFE";
    if (score >= 50) return "MEDIUM";
    return "UNSAFE";
  }

  Color getColor() {
    if (score >= 80) return Colors.green;
    if (score >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (data.isEmpty) {
      return Scaffold(body: Center(child: Text("Product not found")));
    }

    return Scaffold(
      appBar: AppBar(title: Text(data["product_name"] ?? "Product")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (data["image_url"] != null)
              Image.network(data["image_url"]),
            SizedBox(height: 20),
            Text(
              "${score.toStringAsFixed(1)}%",
              style: TextStyle(fontSize: 30, color: getColor()),
            ),
            Text(getStatus(), style: TextStyle(fontSize: 24)),
            SizedBox(height: 20),
            Text("Problematic Ingredients:"),
            ...badIngredients.map((e) => Text("• $e")).toList(),
          ],
        ),
      ),
    );
  }
}
