import 'package:flutter/material.dart';
import '../services/tariff_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TariffService _tariffService = TariffService();
  late TextEditingController _tariffController;
  late TextEditingController _quotaController;

  @override
  void initState() {
    super.initState();
    _tariffController = TextEditingController(
      text: _tariffService.tariffRate.toStringAsFixed(2),
    );
    _quotaController = TextEditingController(
      text: _tariffService.quotaUnits.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _tariffController.dispose();
    _quotaController.dispose();
    super.dispose();
  }

  void _showEditTariffDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text(
            "Configure Electricity Tariff",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter tariff rate in ₹ per kWh (used to calculate Estimated Bill):",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _tariffController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixText: "₹ ",
                  prefixStyle: const TextStyle(color: Colors.greenAccent, fontSize: 18),
                  suffixText: "/ kWh",
                  suffixStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black54,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.orange),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [5.0, 7.0, 8.5, 10.0].map((rate) {
                  return ActionChip(
                    backgroundColor: const Color(0xFF2C2C2E),
                    label: Text("₹$rate", style: const TextStyle(color: Colors.white, fontSize: 12)),
                    onPressed: () {
                      setState(() {
                        _tariffController.text = rate.toStringAsFixed(2);
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final double? parsed = double.tryParse(_tariffController.text);
                if (parsed != null && parsed >= 0) {
                  setState(() {
                    _tariffService.tariffRate = parsed;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Tariff rate updated to ₹${parsed.toStringAsFixed(2)}/kWh"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                Navigator.pop(ctx);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void _showEditQuotaDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: const Text(
            "Configure Monthly Quota",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter monthly electricity allocation (Default: 96 Units):",
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _quotaController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  suffixText: "Units",
                  suffixStyle: const TextStyle(color: Colors.white54),
                  filled: true,
                  fillColor: Colors.black54,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.orange),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final double? parsed = double.tryParse(_quotaController.text);
                if (parsed != null && parsed > 0) {
                  setState(() {
                    _tariffService.quotaUnits = parsed;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Monthly quota updated to ${parsed.toStringAsFixed(0)} Units"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                Navigator.pop(ctx);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          "Settings & Configuration",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: ValueListenableBuilder<double>(
        valueListenable: _tariffService.tariffRateNotifier,
        builder: (context, tariffRate, _) {
          return ValueListenableBuilder<double>(
            valueListenable: _tariffService.quotaUnitsNotifier,
            builder: (context, quotaUnits, _) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Section: Tariff & Billing
                  const Text(
                    "BILLING & TARIFF CONFIGURATION",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.currency_rupee, color: Colors.greenAccent),
                          title: const Text("Electricity Tariff Rate", style: TextStyle(color: Colors.white)),
                          subtitle: Text("₹${tariffRate.toStringAsFixed(2)} per kWh", style: const TextStyle(color: Colors.white70)),
                          trailing: const Icon(Icons.edit, color: Colors.orangeAccent, size: 20),
                          onTap: _showEditTariffDialog,
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        ListTile(
                          leading: const Icon(Icons.energy_savings_leaf, color: Colors.blueAccent),
                          title: const Text("Energy Consumption Quota", style: TextStyle(color: Colors.white)),
                          subtitle: Text("${quotaUnits.toStringAsFixed(0)} Units / Month", style: const TextStyle(color: Colors.white70)),
                          trailing: const Icon(Icons.edit, color: Colors.orangeAccent, size: 20),
                          onTap: _showEditQuotaDialog,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section: System & Hardware
                  const Text(
                    "SYSTEM & HARDWARE STATUS",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.wifi, color: Colors.greenAccent),
                          title: Text("WiFi & Cloud Sync", style: TextStyle(color: Colors.white)),
                          subtitle: Text("Connected to Firebase Realtime Database", style: TextStyle(color: Colors.white70)),
                          trailing: Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                        ),
                        Divider(color: Colors.white10, height: 1),
                        ListTile(
                          leading: Icon(Icons.memory, color: Colors.orangeAccent),
                          title: Text("Telemetry Meter", style: TextStyle(color: Colors.white)),
                          subtitle: Text("ESP32 Dual-Channel Node (esp32_01)", style: TextStyle(color: Colors.white70)),
                          trailing: Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                        ),
                        Divider(color: Colors.white10, height: 1),
                        ListTile(
                          leading: Icon(Icons.psychology, color: Colors.purpleAccent),
                          title: Text("Random Forest ML Engine", style: TextStyle(color: Colors.white)),
                          subtitle: Text("1-Hour & 24-Hour Multi-Horizon Models Active", style: TextStyle(color: Colors.white70)),
                          trailing: Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Section: About
                  const Text(
                    "ABOUT VOLTIX",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bolt, color: Colors.orange, size: 24),
                            SizedBox(width: 8),
                            Text(
                              "Voltix Smart Energy Platform",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "An IoT and Mobile Application Framework Using Random Forest for Real-Time Energy Monitoring and Predictive Load Optimization.",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white10, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Version", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                            const Text("1.0.0+1 (Release)", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}