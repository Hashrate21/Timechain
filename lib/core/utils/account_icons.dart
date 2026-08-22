import 'package:flutter/material.dart';

import '../../domain/entities/account.dart';
import '../theme/app_colors.dart';

class AccountIcons {
  static const assetKeys = [
    'account_balance',
    'account_balance_wallet',
    'savings',
    'payments',
    'trending_up',
    'show_chart',
    'candlestick_chart',
    'analytics',
    'pie_chart',
    'area_chart',
  ];

  static const liabilityKeys = [
    'credit_card',
    'account_balance_wallet',
    'receipt_long',
    'real_estate_agent',
    'home',
    'handyman',
  ];
  static const untrackedKeys = [
    'public_off',
    'account_balance_wallet',
    'savings',
    'trending_up',
    'payments',
  ];

  static List<String> keysFor(AccountType type) {
    switch (type) {
      case AccountType.asset:
        return assetKeys;
      case AccountType.liability:
        return liabilityKeys;
      case AccountType.untracked:
        return untrackedKeys;
    }
  }

  static IconData data(String key) {
    switch (key) {
      case 'account_balance':
        return Icons.account_balance_rounded;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet_rounded;
      case 'savings':
        return Icons.savings_rounded;
      case 'payments':
        return Icons.payments_rounded;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'show_chart':
        return Icons.show_chart_rounded;
      case 'candlestick_chart':
        return Icons.candlestick_chart_rounded;
      case 'analytics':
        return Icons.analytics_rounded;
      case 'pie_chart':
        return Icons.pie_chart_rounded;
      case 'area_chart':
        return Icons.area_chart_rounded;
      case 'credit_card':
        return Icons.credit_card_rounded;
      case 'receipt_long':
        return Icons.receipt_long_rounded;
      case 'real_estate_agent':
        return Icons.real_estate_agent_rounded;
      case 'home':
        return Icons.home_rounded;
      case 'handyman':
        return Icons.handyman_rounded;
      case 'public_off':
        return Icons.public_off_rounded;
      default:
        return Icons.account_balance_rounded;
    }
  }

  static Color colorFor(AccountType type) {
    switch (type) {
      case AccountType.asset:
        return AppColors
            .success /* your existing asset color — often success */;
      case AccountType.liability:
        return AppColors
            .primaryBlue /* your existing liability color — often primary */;
      case AccountType.untracked:
        return const Color(0xFF94A3B8);
    }
  }
}
