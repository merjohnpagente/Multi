import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AppCategory {
  animals,
  nature,
  places,
  food,
  vehicles,
  people,
  plants,
  documents,
  other;

  String get label {
    switch (this) {
      case AppCategory.animals:
        return 'Animals';
      case AppCategory.nature:
        return 'Nature';
      case AppCategory.places:
        return 'Places';
      case AppCategory.food:
        return 'Food';
      case AppCategory.vehicles:
        return 'Vehicles';
      case AppCategory.people:
        return 'People';
      case AppCategory.plants:
        return 'Plants';
      case AppCategory.documents:
        return 'Documents';
      case AppCategory.other:
        return 'Other';
    }
  }

  String get description {
    switch (this) {
      case AppCategory.animals:
        return 'Pets, wildlife and birds';
      case AppCategory.nature:
        return 'Landscapes and outdoors';
      case AppCategory.places:
        return 'Beaches, buildings and landmarks';
      case AppCategory.food:
        return 'Meals, fruit and drinks';
      case AppCategory.vehicles:
        return 'Cars, bikes and transport';
      case AppCategory.people:
        return 'Portraits and people';
      case AppCategory.plants:
        return 'Flowers, trees and leaves';
      case AppCategory.documents:
        return 'Paperwork and screenshots';
      case AppCategory.other:
        return 'Everything else';
    }
  }

  IconData get icon {
    switch (this) {
      case AppCategory.animals:
        return Icons.pets_outlined;
      case AppCategory.nature:
        return Icons.landscape_outlined;
      case AppCategory.places:
        return Icons.place_outlined;
      case AppCategory.food:
        return Icons.restaurant_outlined;
      case AppCategory.vehicles:
        return Icons.directions_car_outlined;
      case AppCategory.people:
        return Icons.people_outline_rounded;
      case AppCategory.plants:
        return Icons.local_florist_outlined;
      case AppCategory.documents:
        return Icons.description_outlined;
      case AppCategory.other:
        return Icons.auto_awesome_mosaic_outlined;
    }
  }

  Color get tint {
    switch (this) {
      case AppCategory.animals:
        return const Color(0xFFF59E0B);
      case AppCategory.nature:
        return const Color(0xFF0EA5E9);
      case AppCategory.places:
        return const Color(0xFF8B5CF6);
      case AppCategory.food:
        return const Color(0xFFEF4444);
      case AppCategory.vehicles:
        return const Color(0xFF3B82F6);
      case AppCategory.people:
        return const Color(0xFFEC4899);
      case AppCategory.plants:
        return AppColors.primary;
      case AppCategory.documents:
        return const Color(0xFF64748B);
      case AppCategory.other:
        return const Color(0xFF94A3B8);
    }
  }

  static AppCategory parse(String? value) {
    if (value == null || value.isEmpty) {
      return AppCategory.other;
    }
    return AppCategory.values.firstWhere(
      (AppCategory category) => category.name == value,
      orElse: () => AppCategory.other,
    );
  }
}
