import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dépenses')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_down, size: 64, color: AppColors.s200),
            SizedBox(height: 12),
            Text('Module Dépenses', style: TextStyle(color: AppColors.s400, fontSize: 16)),
            SizedBox(height: 4),
            Text('Livrable 4 — en cours de développement',
                style: TextStyle(color: AppColors.s300, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
