import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum FieldType { email, password, text, number }

class CustomFormField extends StatefulWidget {
  final TextEditingController controller;
  final FieldType fieldType;
  final String hintText;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextStyle? hintStyle;
  final TextStyle? textStyle;
  final InputBorder? border;
  final Color? fillColor;
  final EdgeInsetsGeometry? contentPadding;

  const CustomFormField({
    super.key,
    required this.controller,
    required this.fieldType,
    required this.hintText,
    this.validator,
    this.onChanged,
    this.hintStyle,
    this.textStyle,
    this.border,
    this.fillColor,
    this.contentPadding,
  });

  @override
  State<CustomFormField> createState() => _CustomFormFieldState();
}

class _CustomFormFieldState extends State<CustomFormField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    bool isPassword = widget.fieldType == FieldType.password;
    List<TextInputFormatter>? inputFormatters;

    if (widget.fieldType == FieldType.number) {
      inputFormatters = [FilteringTextInputFormatter.digitsOnly];
    }

    return TextFormField(
      controller: widget.controller,
      obscureText: isPassword,
      keyboardType: widget.fieldType == FieldType.email
          ? TextInputType.emailAddress
          : widget.fieldType == FieldType.number
          ? TextInputType.number
          : TextInputType.text,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle:
            widget.hintStyle ??
            TextStyle(color: Colors.grey[500], fontWeight: FontWeight.w500),
        filled: true,
        fillColor:
            widget.fillColor ??
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
        border:
            widget.border ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
        contentPadding:
            widget.contentPadding ??
            const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        suffixIcon: !isPassword && widget.controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear, color: Colors.grey[600]),
                onPressed: () {
                  widget.controller.clear();
                  if (widget.onChanged != null) widget.onChanged!('');
                },
              )
            : null,
        enabledBorder:
            widget.border ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
        focusedBorder:
            widget.border ??
            OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
      ),
      style:
          widget.textStyle ??
          TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
      validator: widget.validator,
      onChanged: widget.onChanged,
    );
  }
}
