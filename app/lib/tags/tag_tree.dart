// © 2026 Tephra. All rights reserved.

import 'package:tephra_index/tephra_index.dart';

/// Tag tree sort modes.
enum TagSortMode { nameAZ, frequency }

/// Represents a node in the nested tag tree.
final class TagNode {
  TagNode({
    required this.segment,
    required this.fullTag,
    required this.count,
    List<TagNode>? children,
  }) : children = children ?? [];

  final String segment;
  final String fullTag;
  final int count;
  final List<TagNode> children;

  @override
  String toString() =>
      'TagNode(segment: $segment, fullTag: $fullTag, count: $count, children: ${children.length})';
}

/// Builds a hierarchical tag tree from a list of [TagCount]s.
List<TagNode> buildTagTree(
  List<TagCount> tags, {
  TagSortMode sortMode = TagSortMode.nameAZ,
}) {
  final countMap = <String, TagCount>{};
  for (final t in tags) {
    countMap[t.tagLower] = t;
  }

  // Intermediate node representation for building the trie.
  final rootChildren = <String, _TrieBuilderNode>{};

  for (final t in tags) {
    final lowerParts = t.tagLower.split('/');
    final displayParts = t.tag.split('/');

    Map<String, _TrieBuilderNode> currentMap = rootChildren;
    String currentPathLower = '';
    String currentPathDisplay = '';

    for (var i = 0; i < lowerParts.length; i++) {
      final lp = lowerParts[i];
      final dp = i < displayParts.length ? displayParts[i] : lp;

      currentPathLower = currentPathLower.isEmpty
          ? lp
          : '$currentPathLower/$lp';
      currentPathDisplay = currentPathDisplay.isEmpty
          ? dp
          : '$currentPathDisplay/$dp';

      final node = currentMap.putIfAbsent(
        lp,
        () => _TrieBuilderNode(
          segment: dp,
          fullTag: currentPathDisplay,
          pathLower: currentPathLower,
        ),
      );

      currentMap = node.children;
    }
  }

  // Convert builder nodes to TagNode recursively
  TagNode toTagNode(_TrieBuilderNode builder) {
    final tagCount = countMap[builder.pathLower];
    final count = tagCount?.count ?? 0;
    final displayTag = tagCount?.tag ?? builder.fullTag;
    final displaySegment = tagCount != null && tagCount.tag.contains('/')
        ? tagCount.tag.split('/').last
        : (tagCount?.tag ?? builder.segment);

    final children = builder.children.values.map(toTagNode).toList();
    _sortTagNodes(children, sortMode);

    return TagNode(
      segment: displaySegment,
      fullTag: displayTag,
      count: count,
      children: children,
    );
  }

  final result = rootChildren.values.map(toTagNode).toList();
  _sortTagNodes(result, sortMode);
  return result;
}

/// Builds a flat list of tag nodes from [tags].
List<TagNode> buildFlatTagList(
  List<TagCount> tags, {
  TagSortMode sortMode = TagSortMode.nameAZ,
}) {
  final list = tags
      .map((t) => TagNode(segment: t.tag, fullTag: t.tag, count: t.count))
      .toList();

  _sortTagNodes(list, sortMode);
  return list;
}

void _sortTagNodes(List<TagNode> nodes, TagSortMode sortMode) {
  nodes.sort((a, b) {
    switch (sortMode) {
      case TagSortMode.nameAZ:
        return a.segment.toLowerCase().compareTo(b.segment.toLowerCase());
      case TagSortMode.frequency:
        final cmp = b.count.compareTo(a.count);
        if (cmp != 0) return cmp;
        return a.segment.toLowerCase().compareTo(b.segment.toLowerCase());
    }
  });
}

final class _TrieBuilderNode {
  _TrieBuilderNode({
    required this.segment,
    required this.fullTag,
    required this.pathLower,
  });

  String segment;
  String fullTag;
  final String pathLower;
  final Map<String, _TrieBuilderNode> children = {};
}
