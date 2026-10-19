import 'package:flutter/material.dart';

/// Optional visible marks use the same preview/save workflow as page arranging.
class PdfOverlayControls extends StatelessWidget {
  final bool enabled, pageNumbers, watermarkEnabled;
  final TextEditingController watermark, fontSize;
  final ExpansibleController advanced;
  final ValueChanged<bool> onPageNumbers, onWatermark;
  final VoidCallback onChanged;
  const PdfOverlayControls({
    super.key,
    required this.enabled,
    required this.pageNumbers,
    required this.watermarkEnabled,
    required this.watermark,
    required this.fontSize,
    required this.advanced,
    required this.onPageNumbers,
    required this.onWatermark,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => ExpansionTile(
    controller: advanced,
    maintainState: true,
    tilePadding: EdgeInsets.zero,
    title: const Text('Page numbers & watermark'),
    subtitle: Text(
      [
        if (pageNumbers) 'Page numbers on',
        if (watermarkEnabled) 'Watermark on',
        if (!pageNumbers && !watermarkEnabled) 'Optional visible marks',
      ].join(' · '),
    ),
    children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Add page numbers'),
        subtitle: const Text('Bottom centre, using the saved page order.'),
        value: pageNumbers,
        onChanged: enabled ? (value) => onPageNumbers(value!) : null,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Add a text watermark'),
        subtitle: const Text('A faint diagonal label on every saved page.'),
        value: watermarkEnabled,
        onChanged: enabled ? onWatermark : null,
      ),
      if (watermarkEnabled) ...[
        TextFormField(
          controller: watermark,
          enabled: enabled,
          maxLength: 80,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(
            labelText: 'Watermark text',
            helperText:
                'English letters, numbers and plain symbols in this version.',
          ),
          onChanged: (_) => onChanged(),
          validator: (value) =>
              value == null ||
                  value.trim().isEmpty ||
                  value.length > 80 ||
                  !value.codeUnits.every((c) => c >= 32 && c <= 126)
              ? 'Use 1–80 English letters, numbers or plain symbols.'
              : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: fontSize,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: const InputDecoration(
            labelText: 'Watermark text size (points)',
            helperText: 'Use a smaller size if the label does not fit a page.',
          ),
          onChanged: (_) => onChanged(),
          validator: (value) {
            final size = double.tryParse(value ?? '');
            return size == null || !size.isFinite || size < 6 || size > 96
                ? 'Use 6–96 points.'
                : null;
          },
        ),
        const SizedBox(height: 12),
      ],
      const Text(
        'Visible marks keep the underlying document content. Review the prepared pages before saving a copy.',
      ),
      const SizedBox(height: 12),
    ],
  );
}
