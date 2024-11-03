// lib/icons.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class CategoryIcons {
  static final Map<String, IconData> icons = {
    '식비': FontAwesomeIcons.utensils,
    '교통비': FontAwesomeIcons.bus,
    '쇼핑': FontAwesomeIcons.shoppingBag,
    '엔터테인먼트': FontAwesomeIcons.film,
    '기타 지출': FontAwesomeIcons.coins,
    '급여': FontAwesomeIcons.wallet,
    '보너스': FontAwesomeIcons.gift,
    '기타 수입': FontAwesomeIcons.moneyBill,
    // 필요한 경우 카테고리와 아이콘을 추가하세요.
  };
}
