import 'package:flutter/material.dart';
import '../app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar_back.dart';
import '../widgets/gradient_button.dart';

class ChangeUserTypeScreen extends StatefulWidget {
  const ChangeUserTypeScreen({super.key});

  @override
  State<ChangeUserTypeScreen> createState() => _ChangeUserTypeScreenState();
}

class _ChangeUserTypeScreenState extends State<ChangeUserTypeScreen> {
  late String _selectedUserType;

  @override
  void initState() {
    super.initState();
    _selectedUserType = AppState.userType;
  }

  void _save() {
    AppState.userType = _selectedUserType;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextLight : AppTheme.darkText;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const AppBarBack(title: 'Change user type'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select your user type',
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedUserType,
                decoration: InputDecoration(
                  labelText: 'User type',
                  labelStyle: TextStyle(color: Colors.grey[700]),
                  filled: true,
                  fillColor: AppTheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: AppState.userTypeOptions
                    .map((String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ))
                    .toList(),
                onChanged: (String? value) {
                  if (value != null) setState(() => _selectedUserType = value);
                },
              ),
              const SizedBox(height: 32),
              GradientButton(
                label: 'Save',
                onPressed: _save,
                expand: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
