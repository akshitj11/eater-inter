import '../models.dart';

class VoiceCartCommand {
  const VoiceCartCommand({
    required this.quantity,
    required this.item,
    required this.spokenDish,
  });

  final int quantity;
  final MenuItem item;
  final String spokenDish;
}

class VoiceCartParseResult {
  const VoiceCartParseResult._({
    required this.command,
    required this.searchText,
    required this.message,
  });

  final VoiceCartCommand? command;
  final String searchText;
  final String message;

  bool get hasCommand => command != null;

  factory VoiceCartParseResult.command(VoiceCartCommand command) {
    return VoiceCartParseResult._(
      command: command,
      searchText: command.spokenDish,
      message: '',
    );
  }

  factory VoiceCartParseResult.fallback({
    required String searchText,
    required String message,
  }) {
    return VoiceCartParseResult._(
      command: null,
      searchText: searchText,
      message: message,
    );
  }
}

class VoiceCartParser {
  const VoiceCartParser();

  VoiceCartParseResult parse(String words, List<MenuItem> menuItems) {
    final normalized = _normalize(words);
    if (normalized.isEmpty) {
      return VoiceCartParseResult.fallback(
        searchText: '',
        message: 'Please say the quantity and dish name.',
      );
    }
    final parts = normalized.split(' ');
    final quantity = _quantityFor(parts.first);
    final dishWords = quantity == null ? parts : parts.skip(1).toList();
    final dish = dishWords.join(' ').trim();
    if (dish.isEmpty) {
      return VoiceCartParseResult.fallback(
        searchText: normalized,
        message: 'Please say a dish name after the quantity.',
      );
    }
    final item = _bestMatch(dish, menuItems);
    if (item == null) {
      return VoiceCartParseResult.fallback(
        searchText: dish,
        message: 'I could not find "$dish" on the menu.',
      );
    }
    return VoiceCartParseResult.command(
      VoiceCartCommand(
        quantity: quantity ?? 1,
        item: item,
        spokenDish: dish,
      ),
    );
  }

  MenuItem? _bestMatch(String dish, List<MenuItem> items) {
    final queryTokens = _tokens(dish).toSet();
    if (queryTokens.isEmpty) {
      return null;
    }
    MenuItem? bestItem;
    var bestScore = 0;
    for (final item in items) {
      final name = _normalize(item.name);
      final itemTokens = _tokens(name).toSet();
      var score = 0;
      if (name == dish) {
        score += 100;
      } else if (name.contains(dish)) {
        score += 60;
      } else if (dish.contains(name)) {
        score += 50;
      }
      score += queryTokens.intersection(itemTokens).length * 20;
      if (score > bestScore) {
        bestScore = score;
        bestItem = item;
      }
    }
    return bestScore >= 20 ? bestItem : null;
  }

  List<String> _tokens(String value) {
    return _normalize(value)
        .split(' ')
        .where((part) => part.isNotEmpty && !_fillerWords.contains(part))
        .toList();
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int? _quantityFor(String value) {
    return int.tryParse(value) ?? _numberWords[value];
  }

  static const _numberWords = {
    'a': 1,
    'an': 1,
    'one': 1,
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
  };

  static const _fillerWords = {
    'add',
    'order',
    'plate',
    'plates',
    'please',
    'of',
    'the',
  };
}
