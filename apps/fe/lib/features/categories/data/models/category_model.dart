import 'package:flutter/material.dart';

/// Category model matching `CategoryResponseDto` from `GET /api/v1/categories`.
class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.icon,
    this.parentId,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? icon;
  final String? parentId;
  final bool isActive;

  IconData get iconData {
    switch (icon ?? slug) {
      case 'devices':
      case 'electronics':
        return Icons.devices_rounded;
      case 'laptop_mac':
      case 'computers-accessories':
        return Icons.laptop_mac_rounded;
      case 'smartphone':
      case 'phones-tablets':
        return Icons.smartphone_rounded;
      case 'menu_book':
      case 'books':
      case 'books-stationery':
        return Icons.menu_book_rounded;
      case 'checkroom':
      case 'fashion':
        return Icons.checkroom_rounded;
      case 'chair':
      case 'home-living':
        return Icons.chair_outlined;
      case 'sports_esports':
      case 'sports-hobbies':
        return Icons.sports_esports_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] as String?) ?? '',
      slug: (json['slug'] as String?) ?? '',
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      parentId: json['parentId']?.toString(),
      isActive: (json['isActive'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      '_id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'icon': icon,
      'parentId': parentId,
      'isActive': isActive,
    };
  }
}
