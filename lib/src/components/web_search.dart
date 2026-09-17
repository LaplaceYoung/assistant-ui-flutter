import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One search hit.
@immutable
class WebSearchResult {
  const WebSearchResult({required this.title, required this.domain});

  final String title;
  final String domain;
}

/// A web search in flight, then what it read — the `web-search` element.
class AssistantWebSearch extends StatelessWidget {
  const AssistantWebSearch({
    super.key,
    required this.query,
    required this.results,
    required this.visibleResults,
    this.searching = false,
  });

  final String query;
  final List<WebSearchResult> results;

  /// How many hits have been revealed, in order.
  final int visibleResults;

  /// Swaps the status line for a shimmering `Searching`.
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              decoration: auiField(theme, radius: 999),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.search, size: 12, color: auiFg(theme, 0.4)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      query,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        color: auiFg(theme, 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (searching)
              AuiShimmerLabel(
                text: 'Searching',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: auiFg(theme, 0.45),
                ),
              )
            else
              // Upstream prints a fixed "Read 3 sources"; the count here
              // follows the actual result list.
              Text(
                'Read ${results.length} sources',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: auiFg(theme, 0.45),
                ),
              ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 92),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final WebSearchResult result
                      in results.take(visibleResults))
                    _Result(result: result),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatefulWidget {
  const _Result({required this.result});

  final WebSearchResult result;

  @override
  State<_Result> createState() => _ResultState();
}

class _ResultState extends State<_Result> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        decoration: BoxDecoration(
          color: _hovered ? auiFg(theme, 0.03) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: <Widget>[
            Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: auiFg(theme, 0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.result.domain.isEmpty
                    ? '?'
                    : widget.result.domain[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  color: auiFg(theme, 0.45),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.result.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.3,
                  color: auiFg(theme, 0.9),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.result.domain,
              style: auiMono(context, color: auiFg(theme, 0.35)),
            ),
          ],
        ),
      ),
    );
  }
}
