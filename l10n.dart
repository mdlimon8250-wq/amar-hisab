import 'package:flutter/material.dart';

/// Category keys are stored in the database (language independent) and
/// translated only when displayed.
const incomeCategories = ['salary', 'business', 'gift', 'other'];
const expenseCategories = [
  'food', 'transport', 'shopping', 'bills', 'health', 'education', 'rent', 'other',
];

const _catNames = <String, List<String>>{
  'salary': ['বেতন', 'Salary'],
  'business': ['ব্যবসা', 'Business'],
  'gift': ['উপহার', 'Gift'],
  'other': ['অন্যান্য', 'Other'],
  'food': ['খাবার', 'Food'],
  'transport': ['যাতায়াত', 'Transport'],
  'shopping': ['কেনাকাটা', 'Shopping'],
  'bills': ['বিল', 'Bills'],
  'health': ['চিকিৎসা', 'Health'],
  'education': ['শিক্ষা', 'Education'],
  'rent': ['ভাড়া', 'Rent'],
};

/// Labels used by version 1 of the app (stored as display text) -> new keys.
const legacyCategoryMap = <String, String>{
  'বেতন': 'salary', 'Salary': 'salary',
  'ব্যবসা': 'business', 'Business': 'business',
  'উপহার': 'gift', 'Gift': 'gift',
  'অন্যান্য': 'other', 'Other': 'other',
  'খাবার': 'food', 'Food': 'food',
  'যাতায়াত': 'transport', 'Transport': 'transport',
  'কেনাকাটা': 'shopping', 'Shopping': 'shopping',
  'বিল': 'bills', 'Bills': 'bills',
  'চিকিৎসা': 'health', 'Health': 'health',
};

String categoryLabel(String key, bool en) {
  final n = _catNames[key];
  if (n == null) return key; // unknown / custom text is shown as is
  return en ? n[1] : n[0];
}

const accountKinds = ['personal', 'family', 'business'];

String kindLabel(String kind, bool en) {
  switch (kind) {
    case 'family':
      return en ? 'Family' : 'পরিবার';
    case 'business':
      return en ? 'Business' : 'ব্যবসা';
    default:
      return en ? 'Personal' : 'ব্যক্তিগত';
  }
}

IconData kindIcon(String kind) {
  switch (kind) {
    case 'family':
      return Icons.family_restroom;
    case 'business':
      return Icons.storefront_outlined;
    default:
      return Icons.person_outline;
  }
}

const _seedNames = {'ব্যক্তিগত': 'Personal', 'ব্যবসা': 'Business', 'পরিবার': 'Family'};

/// The three accounts seeded by the app are stored in Bengali; show them in
/// English when the UI language is English. User-named accounts are untouched.
String accountDisplayName(String name, bool en) =>
    en ? (_seedNames[name] ?? name) : name;
