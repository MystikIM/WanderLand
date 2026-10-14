import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/front_controller.dart';
import '../controllers/settings_controller.dart';
import '../domain/quotes.dart';
import 'little_scope.dart';

class QuoteCard extends StatefulWidget {
  const QuoteCard({super.key});
  @override
  State<QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<QuoteCard> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final now = context.watch<FrontController>().clock();
    final level = currentLittleLevel(context);
    if (!s.quotes.enabled || _hidden) return const SizedBox.shrink();

    final todays = chooseTodaysQuote(s.quotes, now);
    if (!identical(todays, s.quotes)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => s.setQuotes(todays));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(quoteText(level, todays.lastIndex),
                  key: const Key('quote-text'),
                  style: Theme.of(context).textTheme.bodyLarge),
              TextButton(
                key: const Key('quote-next'),
                onPressed: () => s.setQuotes(nextQuote(todays)),
                child: const Text('Another one'),
              ),
            ]),
          ),
          IconButton(
            key: const Key('quote-dismiss'),
            icon: const Icon(Icons.close),
            tooltip: 'Hide for now',
            onPressed: () => setState(() => _hidden = true),
          ),
        ]),
      ),
    );
  }
}
