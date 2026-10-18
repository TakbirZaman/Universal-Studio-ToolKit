import 'package:flutter/material.dart';

class PrintLayoutControls extends StatelessWidget {
  final String preset;
  final TextEditingController paperWidth, paperHeight, margin, spacing, dpi;
  final bool enabled, guides, resample;
  final ExpansibleController advanced;
  final ValueChanged<String> onPreset;
  final ValueChanged<bool> onGuides, onResample;
  final VoidCallback onChanged;
  const PrintLayoutControls({
    super.key,
    required this.preset,
    required this.paperWidth,
    required this.paperHeight,
    required this.margin,
    required this.spacing,
    required this.dpi,
    required this.enabled,
    required this.guides,
    required this.resample,
    required this.advanced,
    required this.onPreset,
    required this.onGuides,
    required this.onResample,
    required this.onChanged,
  });
  Widget number(
    TextEditingController controller,
    String label,
    double minimum,
    double maximum,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => onChanged(),
      validator: (value) {
        final number = double.tryParse(value ?? '');
        return number == null ||
                !number.isFinite ||
                number < minimum ||
                number > maximum
            ? 'Use $minimum–$maximum mm.'
            : null;
      },
    ),
  );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        initialValue: preset,
        key: ValueKey(preset),
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Paper size'),
        items: const [
          DropdownMenuItem(value: 'a4', child: Text('A4 · 210 × 297 mm')),
          DropdownMenuItem(value: 'a5', child: Text('A5 · 148 × 210 mm')),
          DropdownMenuItem(
            value: 'letter',
            child: Text('Letter · 215.9 × 279.4 mm'),
          ),
          DropdownMenuItem(value: 'photo', child: Text('4 × 6 inches')),
          DropdownMenuItem(value: 'custom', child: Text('Custom paper')),
        ],
        onChanged: enabled ? (value) => onPreset(value!) : null,
      ),
      if (preset == 'custom') ...[
        const SizedBox(height: 16),
        number(paperWidth, 'Paper width (mm)', 10, 1000),
        number(paperHeight, 'Paper height (mm)', 10, 1000),
      ],
      ExpansionTile(
        controller: advanced,
        maintainState: true,
        tilePadding: EdgeInsets.zero,
        title: const Text('Margins, spacing & resolution'),
        children: [
          number(margin, 'Paper margins (mm)', guides ? 1.5 : 0, 499),
          number(spacing, 'Space between photos (mm)', guides ? 3 : 0, 1000),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: guides,
            onChanged: enabled ? (value) => onGuides(value!) : null,
            title: const Text('Add cutting guides'),
            subtitle: const Text(
              'Small marks outside the photos. Needs 1.5 mm margins and 3 mm spacing.',
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: resample,
            onChanged: enabled ? onResample : null,
            title: const Text('Set photo sampling DPI'),
            subtitle: const Text(
              'Off: keep source pixels. Resampling cannot add missing detail.',
            ),
          ),
          if (resample)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: dpi,
                enabled: enabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Photo sampling DPI',
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                onChanged: (_) => onChanged(),
                validator: (value) {
                  final number = int.tryParse(value ?? '');
                  return number == null || number < 1 || number > 2400
                      ? 'Use 1–2400 DPI.'
                      : null;
                },
              ),
            ),
          const Text(
            'Photos are embedded as JPEG at quality 95. Exact photo boxes preserve aspect ratio; tiny white space may result from rounding.',
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'Print at Actual size / 100%, without Fit to page. Crop the photo to the chosen aspect ratio first. The preview validates layout, not your printer settings.',
      ),
    ],
  );
}
