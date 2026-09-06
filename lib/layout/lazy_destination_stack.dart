import 'package:flutter/material.dart';
import '../app_entries/app_entry.dart';

/// Keeps visited pages alive by ID, including temporarily hidden destinations.
class LazyDestinationStack extends StatefulWidget {
  const LazyDestinationStack({
    super.key,
    required this.entries,
    required this.selectedId,
  });
  final List<AppEntry> entries;
  final String selectedId;

  @override
  State<LazyDestinationStack> createState() => _LazyDestinationStackState();
}

class _LazyDestinationStackState extends State<LazyDestinationStack> {
  final Set<String> _visited = {};

  @override
  Widget build(BuildContext context) {
    _visited.add(widget.selectedId);
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final entry in widget.entries)
          if (_visited.contains(entry.id))
            Offstage(
              key: ValueKey(entry.id),
              offstage: entry.id != widget.selectedId,
              child: TickerMode(
                enabled: entry.id == widget.selectedId,
                child: ExcludeFocus(
                  excluding: entry.id != widget.selectedId,
                  child: entry.builder(context),
                ),
              ),
            ),
      ],
    );
  }
}
