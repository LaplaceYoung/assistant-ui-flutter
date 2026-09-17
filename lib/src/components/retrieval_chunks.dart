import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One retrieved passage.
@immutable
class RetrievalChunk {
  const RetrievalChunk({
    required this.id,
    required this.source,
    required this.locator,
    required this.score,
    required this.text,
  });

  final String id;
  final String source;

  /// Where in the source, e.g. `p. 12` or `lib/main.dart:40`.
  final String locator;

  /// Relevance, 0..1.
  final double score;

  final String text;
}

/// What a retrieval step found: the query, the count and each passage with its
/// score — the `retrieval-chunks` element.
class AssistantRetrievalChunks extends StatelessWidget {
  const AssistantRetrievalChunks({
    super.key,
    required this.query,
    required this.chunks,
    required this.visibleCount,
    this.searching = false,
  });

  final String query;
  final List<RetrievalChunk> chunks;

  /// How many passages have been revealed, in order.
  final int visibleCount;

  /// Swaps the count line for a shimmering `Retrieving`.
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
    final Color green =
        dark ? const Color(0xFF34D399) : const Color(0xFF059669);

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
                  Icon(
                    Icons.storage,
                    size: 12,
                    color: auiFg(theme, 0.4),
                  ),
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
                text: 'Retrieving',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: auiFg(theme, 0.45),
                ),
              )
            else
              Text(
                '${chunks.length} passages above threshold',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: auiFg(theme, 0.45),
                ),
              ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 112),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final (int index, RetrievalChunk chunk)
                      in chunks.take(visibleCount).indexed)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: index == visibleCount - 1 ? 0 : 6,
                      ),
                      child: _Chunk(
                        chunk: chunk,
                        blue: blue,
                        green: green,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chunk extends StatelessWidget {
  const _Chunk({required this.chunk, required this.blue, required this.green});

  final RetrievalChunk chunk;
  final Color blue;
  final Color green;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      decoration: auiPaper(theme, radius: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: Text(
                  chunk.source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                    color: auiFg(theme, 0.9),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                chunk.locator,
                style: auiMono(context, color: auiFg(theme, 0.3)),
              ),
              const SizedBox(width: 8),
              Text(
                chunk.score.toStringAsFixed(2),
                style: auiMono(
                  context,
                  color: chunk.score >= 0.8 ? green : auiFg(theme, 0.35),
                ).copyWith(
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            chunk.text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: auiFg(theme, 0.55),
            ),
          ),
          const SizedBox(height: 6),
          Semantics(
            label: '${chunk.source} relevance score',
            value: '${chunk.score.toStringAsFixed(2)} of 1.00',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 2,
                color: auiFg(theme, 0.06),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: math.max(0, math.min(1, chunk.score)),
                    child: ColoredBox(
                      color: blue.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
