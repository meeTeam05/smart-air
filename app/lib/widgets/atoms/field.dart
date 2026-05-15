import 'package:flutter/material.dart';
import '../../design/palette.dart';
import '../../design/tokens.dart';
import '../../design/text_styles.dart';

class AtmosphereField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final String? errorText;

  const AtmosphereField({
    super.key,
    required this.label,
    this.controller,
    this.prefixIcon,
    this.suffixIcon,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AtmosphereTextStyles.body(c.ink),
        ),
        const SizedBox(height: AtmosphereTokens.space8),
        SizedBox(
          height: 56,
          child: TextFormField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            validator: validator,
            style: AtmosphereTextStyles.body(c.ink),
            decoration: InputDecoration(
              filled: true,
              fillColor: c.paper,
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, size: 20, color: c.ink3)
                  : null,
              suffixIcon: suffixIcon,
              errorText: errorText,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AtmosphereTokens.radiusInput),
                borderSide: BorderSide(color: c.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AtmosphereTokens.radiusInput),
                borderSide: BorderSide(color: c.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AtmosphereTokens.radiusInput),
                borderSide: BorderSide(color: c.brand, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AtmosphereTokens.radiusInput),
                borderSide: BorderSide(color: c.danger),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AtmosphereTokens.radiusInput),
                borderSide: BorderSide(color: c.danger, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AtmosphereTokens.space16,
                vertical: AtmosphereTokens.space16,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
