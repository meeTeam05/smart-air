import 'package:flutter/material.dart';
import '../../design/palette.dart';
import '../../design/text_styles.dart';

class TextLinkButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const TextLinkButton({
    super.key,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: c.brand,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: AtmosphereTextStyles.body(c.brand).copyWith(
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
