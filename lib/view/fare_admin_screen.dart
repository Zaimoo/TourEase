import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tourease/models/fare_config.dart';
import 'package:tourease/services/use_firebase.dart';

/// Admin screen for updating fare rates when a new fare memo is issued.
/// Saves to Firestore `config/fares`; all users pick up the new rates on
/// their next app launch (or next route calculation) without an app update.
class FareAdminScreen extends StatefulWidget {
  const FareAdminScreen({super.key});

  @override
  State<FareAdminScreen> createState() => _FareAdminScreenState();
}

class _FareAdminScreenState extends State<FareAdminScreen> {
  final _fareService = UseFirebase<FareConfig>(
    fromJson: (data, id) => FareConfig.fromJson(data, id),
    toJson: (model) => model.toJson(),
  );

  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};

  bool _loading = true;
  bool _saving = false;

  // Field key -> human label, grouped for display.
  static const Map<String, List<(String, String)>> _groups = {
    'Jeepney': [
      ('jeepneyBaseFare', 'Base fare (₱)'),
      ('jeepneyBaseDistanceKm', 'Base distance (km)'),
      ('jeepneyPerKm', 'Per succeeding km (₱)'),
    ],
    'Habal-habal': [
      ('habalBaseFare', 'Base fare (₱)'),
      ('habalBaseDistanceKm', 'Base distance (km)'),
      ('habalTier1PerKm', 'Tier 1 per km (₱)'),
      ('habalTier1LimitKm', 'Tier 1 limit (km)'),
      ('habalTier2PerKm', 'Tier 2 per km (₱)'),
    ],
    'Sikad': [
      ('sikadBaseFare', 'Base fare (₱)'),
      ('sikadBaseDistanceKm', 'Base distance (km)'),
      ('sikadBlockSizeKm', 'Block size (km)'),
      ('sikadPerBlock', 'Per block (₱)'),
    ],
    'Display': [
      ('rangeSpread', 'Fare range spread (₱)'),
    ],
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    FareConfig config;
    try {
      config = await _fareService.getById('config', 'fares') ??
          FareConfig.defaults();
    } catch (e) {
      config = FareConfig.defaults();
    }
    final json = config.toJson();
    for (final entry in json.entries) {
      _controllers[entry.key] =
          TextEditingController(text: (entry.value as num).toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _resetToDefaults() async {
    final json = FareConfig.defaults().toJson();
    for (final entry in json.entries) {
      _controllers[entry.key]?.text = (entry.value as num).toString();
    }
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final data = <String, dynamic>{
      for (final entry in _controllers.entries)
        entry.key: double.parse(entry.value.text.trim()),
    };
    final config = FareConfig.fromJson(data, 'fares');

    try {
      await _fareService.addWithUid('config', 'fares', config);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fare rates updated for all users.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e')),
      );
    }
  }

  String? _validator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    final n = double.tryParse(value.trim());
    if (n == null) return 'Enter a number';
    if (n < 0) return 'Cannot be negative';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Manage Fares',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFFB6DCFE),
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _resetToDefaults,
              child: const Text('Reset',
                  style: TextStyle(color: Colors.black87)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFD8A8)),
                    ),
                    child: const Text(
                      'Update these when a new fare memo is issued. Changes '
                      'apply to all users without an app update.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final group in _groups.entries) ...[
                    Text(group.key,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    for (final field in group.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextFormField(
                          controller: _controllers[field.$1],
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]')),
                          ],
                          validator: _validator,
                          decoration: InputDecoration(
                            labelText: field.$2,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFA6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Save Fare Rates',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
