import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'reading_catalog.dart';
import 'reading_progress_store.dart';

class ReadingPage extends StatefulWidget {
  const ReadingPage({super.key});

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingBookmarkNode {
  _ReadingBookmarkNode({required this.title, required this.bookmark});

  final String title;
  final dynamic bookmark;
  final List<_ReadingBookmarkNode> children = <_ReadingBookmarkNode>[];
}

class _ReadingPageState extends State<ReadingPage> {
  static const List<ReadingBookEntry> _books = readingBooks;

  final PdfViewerController _controller = PdfViewerController();
  final TextEditingController _pageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ReadingProgressStore _progressStore = ReadingProgressStore();
  final Map<String, int> _bookPageMap = <String, int>{};
  final Map<String, DateTime> _bookLastOpenMap = <String, DateTime>{};

  late ReadingBookEntry _selectedBook;
  late Future<ByteData> _pdfBytesFuture;
  PdfTextSearchResult? _searchResult;
  List<_ReadingBookmarkNode> _bookmarks = <_ReadingBookmarkNode>[];
  bool _bookmarksLoading = false;
  bool _isReading = false;
  bool _isReady = false;
  bool _nightMode = false;
  PdfPageLayoutMode _pageLayoutMode = PdfPageLayoutMode.continuous;
  PdfScrollDirection _scrollDirection = PdfScrollDirection.vertical;
  double _zoomLevel = 1.0;
  int _currentPage = 1;
  int _pageCount = 0;
  int _restoredPage = 1;
  DateTime? _lastOpenedAt;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedBook = _books.first;
    _pdfBytesFuture = rootBundle.load(_selectedBook.assetPath);
    _loadReaderState();
  }

  Future<void> _loadReaderState() async {
    final snapshot = await _progressStore.loadState(_books);
    _bookPageMap
      ..clear()
      ..addAll(snapshot.bookPageMap);
    _bookLastOpenMap
      ..clear()
      ..addAll(snapshot.bookLastOpenMap);

    final recentBook = _mostRecentlyOpenedBook ?? _books.first;
    final savedPage = _bookPageMap[recentBook.assetPath] ?? 1;

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedBook = recentBook;
      _pdfBytesFuture = rootBundle.load(_selectedBook.assetPath);
      _restoredPage = savedPage < 1 ? 1 : savedPage;
      _nightMode = snapshot.nightMode;
      _lastOpenedAt = _bookLastOpenMap[_selectedBook.assetPath];
    });
  }

  @override
  void dispose() {
    _searchResult?.removeListener(_onSearchResultChanged);
    _searchResult?.clear();
    _searchResult?.dispose();
    _controller.dispose();
    _pageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchResultChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _jumpToPage() async {
    final page = int.tryParse(_pageController.text.trim());
    if (page == null || page < 1 || (_pageCount > 0 && page > _pageCount)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效页码')));
      return;
    }
    _controller.jumpToPage(page);
    await _saveLastPage(page);
    setState(() {
      _currentPage = page;
    });
  }

  Future<void> _saveLastPage(int page) async {
    _bookPageMap[_selectedBook.assetPath] = page;
    await _progressStore.saveLastPage(
      assetPath: _selectedBook.assetPath,
      page: page,
      writeLegacy: _selectedBook.assetPath == _books.first.assetPath,
    );
  }

  Future<void> _saveLastOpenedAt() async {
    final now = DateTime.now();
    _bookLastOpenMap[_selectedBook.assetPath] = now;
    await _progressStore.saveLastOpenedAt(
      assetPath: _selectedBook.assetPath,
      openedAt: now,
      writeLegacy: _selectedBook.assetPath == _books.first.assetPath,
    );
  }

  Future<void> _toggleNightMode() async {
    final value = !_nightMode;
    setState(() {
      _nightMode = value;
    });
    await _progressStore.saveNightMode(value);
  }

  void _setPageLayoutMode(PdfPageLayoutMode mode) {
    setState(() {
      _pageLayoutMode = mode;
    });
  }

  void _setScrollDirection(PdfScrollDirection direction) {
    setState(() {
      _scrollDirection = direction;
    });
  }

  void _zoomBy(double delta) {
    setState(() {
      _zoomLevel = (_zoomLevel + delta).clamp(0.8, 3.0);
      _controller.zoomLevel = _zoomLevel;
    });
  }

  void _resetZoom() {
    setState(() {
      _zoomLevel = 1.0;
      _controller.zoomLevel = _zoomLevel;
    });
  }

  ReadingBookEntry? get _mostRecentlyOpenedBook {
    ReadingBookEntry? pick;
    DateTime? maxTime;
    for (final book in _books) {
      final t = _bookLastOpenMap[book.assetPath];
      if (t == null) {
        continue;
      }
      if (maxTime == null || t.isAfter(maxTime)) {
        maxTime = t;
        pick = book;
      }
    }
    return pick;
  }

  int _lastPageFor(ReadingBookEntry book) {
    return _bookPageMap[book.assetPath] ?? 1;
  }

  void _openReading({ReadingBookEntry? book, int? page}) {
    final targetBook = book ?? _selectedBook;
    final targetPage = page ?? _lastPageFor(targetBook);

    setState(() {
      _selectedBook = targetBook;
      _pdfBytesFuture = rootBundle.load(targetBook.assetPath);
      _bookmarks = <_ReadingBookmarkNode>[];
      _isReading = true;
      if (targetPage > 0) {
        _restoredPage = targetPage;
        _currentPage = targetPage;
        _pageController.text = targetPage.toString();
      }
      _lastOpenedAt = DateTime.now();
    });
    _saveLastOpenedAt();
  }

  void _backToBookshelf() {
    setState(() {
      _isReading = false;
    });
  }

  Future<void> _showReaderSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void updateLayout(PdfPageLayoutMode mode) {
              setSheetState(() {
                _pageLayoutMode = mode;
              });
              _setPageLayoutMode(mode);
            }

            void updateScrollDirection(PdfScrollDirection direction) {
              setSheetState(() {
                _scrollDirection = direction;
              });
              _setScrollDirection(direction);
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.tune_outlined),
                      title: Text('阅读设置'),
                      subtitle: Text('阅读器版式、缩放与模式控制'),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _nightMode,
                      title: const Text('夜间模式'),
                      subtitle: const Text('适合暗光环境阅读'),
                      onChanged: (_) {
                        _toggleNightMode();
                        setSheetState(() {});
                      },
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    const Text(
                      '页面布局',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SegmentedButton<PdfPageLayoutMode>(
                      segments: const [
                        ButtonSegment<PdfPageLayoutMode>(
                          value: PdfPageLayoutMode.continuous,
                          label: Text('连续'),
                          icon: Icon(Icons.view_stream),
                        ),
                        ButtonSegment<PdfPageLayoutMode>(
                          value: PdfPageLayoutMode.single,
                          label: Text('单页'),
                          icon: Icon(Icons.crop_square_outlined),
                        ),
                      ],
                      selected: <PdfPageLayoutMode>{_pageLayoutMode},
                      onSelectionChanged: (selection) {
                        if (selection.isNotEmpty) {
                          updateLayout(selection.first);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '滚动方向',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SegmentedButton<PdfScrollDirection>(
                      segments: const [
                        ButtonSegment<PdfScrollDirection>(
                          value: PdfScrollDirection.vertical,
                          label: Text('纵向'),
                          icon: Icon(Icons.swap_vert),
                        ),
                        ButtonSegment<PdfScrollDirection>(
                          value: PdfScrollDirection.horizontal,
                          label: Text('横向'),
                          icon: Icon(Icons.swap_horiz),
                        ),
                      ],
                      selected: <PdfScrollDirection>{_scrollDirection},
                      onSelectionChanged: (selection) {
                        if (selection.isNotEmpty) {
                          updateScrollDirection(selection.first);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '缩放',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: '缩小',
                          onPressed: () {
                            _zoomBy(-0.15);
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.remove),
                        ),
                        Expanded(
                          child: Slider(
                            value: _zoomLevel,
                            min: 0.8,
                            max: 3.0,
                            divisions: 22,
                            label: '${(_zoomLevel * 100).round()}%',
                            onChanged: (value) {
                              setSheetState(() {
                                _zoomLevel = value;
                              });
                              _controller.zoomLevel = value;
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: '放大',
                          onPressed: () {
                            _zoomBy(0.15);
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.add),
                        ),
                        Text('${(_zoomLevel * 100).round()}%'),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            _resetZoom();
                            setSheetState(() {});
                          },
                          child: const Text('重置'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.check),
                        label: const Text('完成'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _startSearch(String query) {
    final text = query.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入搜索内容')));
      return;
    }

    _searchResult?.removeListener(_onSearchResultChanged);
    _searchResult?.clear();
    _searchResult?.dispose();

    final result = _controller.searchText(text);
    result.addListener(_onSearchResultChanged);
    setState(() {
      _searchResult = result;
    });
  }

  void _clearSearch() {
    _searchResult?.removeListener(_onSearchResultChanged);
    _searchResult?.clear();
    _searchResult?.dispose();
    setState(() {
      _searchResult = null;
      _searchController.clear();
    });
  }

  Future<void> _showSearchDialog() async {
    _searchController.text = _searchController.text.trim();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('搜索正文'),
          content: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            autofocus: true,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: '输入关键词',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _searchController.text),
              child: const Text('搜索'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      _startSearch(result);
    }
  }

  List<_ReadingBookmarkNode> _extractBookmarks(dynamic document) {
    dynamic rawBookmarks;
    try {
      rawBookmarks = document.bookmarks;
    } catch (_) {
      return <_ReadingBookmarkNode>[];
    }

    final nodes = <_ReadingBookmarkNode>[];

    void visit(dynamic bookmark, List<_ReadingBookmarkNode> sink) {
      if (bookmark == null) {
        return;
      }

      String title = '未命名书签';
      try {
        final dynamic maybeTitle =
            bookmark.title ?? bookmark.name ?? bookmark.text;
        if (maybeTitle != null && maybeTitle.toString().trim().isNotEmpty) {
          title = maybeTitle.toString().trim();
        }
      } catch (_) {
        // keep fallback title
      }

      final node = _ReadingBookmarkNode(title: title, bookmark: bookmark);
      sink.add(node);

      dynamic children;
      try {
        children = bookmark.children ?? bookmark.bookmarks;
      } catch (_) {
        children = null;
      }

      if (children is Iterable) {
        for (final child in children) {
          visit(child, node.children);
        }
      }
    }

    if (rawBookmarks is Iterable) {
      for (final item in rawBookmarks) {
        visit(item, nodes);
      }
    } else {
      visit(rawBookmarks, nodes);
    }

    return nodes;
  }

  String _bookmarkPreview(dynamic bookmark) {
    try {
      final pageIndex = bookmark.pageIndex ?? bookmark.pageNumber;
      if (pageIndex != null) {
        return '第${pageIndex.toString()}页';
      }
    } catch (_) {
      // ignore
    }
    return '目录项';
  }

  Future<void> _showBookmarkSheet() async {
    if (_bookmarksLoading) {
      return;
    }
    if (_bookmarks.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前 PDF 没有可用目录/书签')));
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        Widget buildNode(_ReadingBookmarkNode node, int depth) {
          return Padding(
            padding: EdgeInsets.only(left: 12.0 * depth),
            child: ListTile(
              dense: true,
              leading: Icon(
                depth == 0
                    ? Icons.bookmark_outline
                    : Icons.subdirectory_arrow_right,
              ),
              title: Text(
                node.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(_bookmarkPreview(node.bookmark)),
              onTap: () {
                Navigator.pop(sheetContext);
                try {
                  _controller.jumpToBookmark(node.bookmark);
                } catch (_) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('该目录项无法跳转')));
                }
              },
            ),
          );
        }

        List<Widget> buildTree(
          List<_ReadingBookmarkNode> nodes, [
          int depth = 0,
        ]) {
          final items = <Widget>[];
          for (final node in nodes) {
            items.add(buildNode(node, depth));
            if (node.children.isNotEmpty) {
              items.addAll(buildTree(node.children, depth + 1));
            }
          }
          return items;
        }

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                leading: Icon(Icons.format_list_bulleted_outlined),
                title: Text('目录 / 书签'),
                subtitle: Text('点击任一条目可跳转'),
              ),
              ...buildTree(_bookmarks),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _loadBookmarks(dynamic document) {
    setState(() {
      _bookmarksLoading = true;
    });

    try {
      final nodes = _extractBookmarks(document);
      if (mounted) {
        setState(() {
          _bookmarks = nodes;
          _bookmarksLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _bookmarks = <_ReadingBookmarkNode>[];
          _bookmarksLoading = false;
        });
      }
    }
  }

  double get _readingProgress {
    if (_pageCount <= 0) {
      return 0;
    }
    return (_currentPage / _pageCount).clamp(0.0, 1.0);
  }

  String get _progressLabel {
    if (_pageCount <= 0) {
      return '上次阅读：第$_restoredPage页';
    }
    final percent = (_readingProgress * 100).round();
    return '上次阅读：第$_restoredPage页 · 进度 $percent%';
  }

  String get _lastOpenedLabel {
    final value = _lastOpenedAt;
    if (value == null) {
      return '尚未记录';
    }
    return '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  ThemeData _buildReaderTheme(BuildContext context) {
    if (!_nightMode) {
      return Theme.of(context);
    }

    final darkScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF7AB9B0),
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFF7AB9B0),
          secondary: const Color(0xFF4C8D87),
          surface: const Color(0xFF101614),
          surfaceContainerHighest: const Color(0xFF1A2220),
          onSurface: const Color(0xFFE7F0EC),
          outline: const Color(0xFF35524A),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: darkScheme,
      scaffoldBackgroundColor: const Color(0xFF0C1110),
      iconTheme: const IconThemeData(color: Color(0xFFE7F0EC)),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Color(0xFF101614),
        foregroundColor: Color(0xFFE7F0EC),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF101614),
        surfaceTintColor: Color(0xFF101614),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF101614),
        surfaceTintColor: Color(0xFF101614),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF35524A),
        thickness: 0.8,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: Color(0xFFE7F0EC),
        textColor: Color(0xFFE7F0EC),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFF101614),
        border: OutlineInputBorder(),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF18211F),
        labelStyle: const TextStyle(color: Color(0xFFE7F0EC)),
        side: const BorderSide(color: Color(0xFF35524A)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: Color(0xFF101614),
        surfaceTintColor: Color(0xFF101614),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF101614),
      ),
    );
  }

  Widget _buildViewer(BuildContext context, Uint8List bytes) {
    final viewer = SfPdfViewer.memory(
      bytes,
      controller: _controller,
      canShowScrollHead: true,
      canShowScrollStatus: true,
      canShowPaginationDialog: false,
      initialPageNumber: _restoredPage,
      pageLayoutMode: _pageLayoutMode,
      scrollDirection: _scrollDirection,
      onDocumentLoaded: (details) {
        _loadBookmarks(details.document);
        setState(() {
          _pageCount = details.document.pages.count;
          _isReady = true;
          _errorMessage = null;
          _controller.zoomLevel = _zoomLevel;
        });
        if (_restoredPage > 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _controller.jumpToPage(_restoredPage);
          });
        }
      },
      onPageChanged: (details) {
        setState(() {
          _currentPage = details.newPageNumber;
          _pageController.text = details.newPageNumber.toString();
        });
        _saveLastPage(details.newPageNumber);
      },
      onDocumentLoadFailed: (details) {
        setState(() {
          _errorMessage = details.description;
          _isReady = false;
        });
      },
    );

    if (_nightMode) {
      return Theme(data: _buildReaderTheme(context), child: viewer);
    }
    return viewer;
  }

  Widget _buildBookshelfHome(BuildContext context) {
    final recentBook = _mostRecentlyOpenedBook ?? _selectedBook;
    final recentPage = _lastPageFor(recentBook);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 110,
                    height: 150,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white.withValues(alpha: 0.14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Center(
                            child: Icon(
                              Icons.menu_book_rounded,
                              size: 54,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'PDF',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedBook.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _selectedBook.subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _progressLabel,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: _pageCount > 0 ? _readingProgress : 0,
                            minHeight: 8,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.18,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                              ),
                              onPressed: () => _openReading(
                                book: _selectedBook,
                                page: _lastPageFor(_selectedBook),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('继续阅读'),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              onPressed: _showBookmarkSheet,
                              icon: const Icon(Icons.list_alt_outlined),
                              label: const Text('目录'),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              onPressed: _showReaderSettingsSheet,
                              icon: const Icon(Icons.tune_outlined),
                              label: const Text('设置'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '书架',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _books.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.86,
              ),
              itemBuilder: (context, index) {
                final book = _books[index];
                final lastPage = _lastPageFor(book);
                return _BookshelfBookCard(
                  book: book,
                  lastPage: lastPage,
                  onTap: () => _openReading(book: book, page: lastPage),
                );
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.history_rounded),
                title: const Text('最近阅读'),
                subtitle: Text(
                  '${recentBook.title} · 第$recentPage页 · $_lastOpenedLabel',
                ),
                trailing: FilledButton(
                  onPressed: () =>
                      _openReading(book: recentBook, page: recentPage),
                  child: const Text('继续'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.schedule_outlined),
                title: const Text('最近阅读进度'),
                subtitle: Text(_progressLabel),
                trailing: Text(
                  _pageCount > 0 ? '共 $_pageCount 页' : '加载后显示总页数',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.search_outlined),
                title: const Text('全文搜索'),
                subtitle: const Text('在书内快速查找关键词'),
                onTap: () {
                  _openReading(
                    book: _selectedBook,
                    page: _lastPageFor(_selectedBook),
                  );
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _showSearchDialog();
                  });
                },
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: Icon(
                  _nightMode ? Icons.dark_mode : Icons.light_mode_outlined,
                ),
                title: const Text('阅读模式'),
                subtitle: Text(_nightMode ? '夜间模式已开启' : '当前为浅色模式'),
                trailing: Switch(
                  value: _nightMode,
                  onChanged: (_) => _toggleNightMode(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.tune_outlined),
                title: const Text('阅读设置'),
                subtitle: Text(
                  '${_pageLayoutMode.name == 'single' ? '单页' : '连续'} · ${_scrollDirection.name == 'horizontal' ? '横向' : '纵向'} · ${(_zoomLevel * 100).round()}%',
                ),
                onTap: _showReaderSettingsSheet,
              ),
            ),
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('说明'),
                subtitle: const Text('PDF 已内置进安装包，点封面即可打开阅读器。'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(_isReading ? '阅读' : '书架'),
        leading: _isReading
            ? IconButton(
                tooltip: '返回书架',
                onPressed: _backToBookshelf,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        actions: [
          if (_isReading)
            IconButton(
              tooltip: '搜索',
              onPressed: _showSearchDialog,
              icon: const Icon(Icons.search),
            ),
          if (_isReading)
            IconButton(
              tooltip: '目录',
              onPressed: _showBookmarkSheet,
              icon: const Icon(Icons.menu_book_outlined),
            ),
          if (_isReading)
            IconButton(
              tooltip: _nightMode ? '关闭夜间模式' : '打开夜间模式',
              onPressed: _toggleNightMode,
              icon: Icon(
                _nightMode ? Icons.dark_mode : Icons.light_mode_outlined,
              ),
            ),
          if (!_isReading)
            IconButton(
              tooltip: '打开阅读器',
              onPressed: () => _openReading(
                book: _selectedBook,
                page: _lastPageFor(_selectedBook),
              ),
              icon: const Icon(Icons.open_in_new_outlined),
            ),
          if (_isReading)
            IconButton(
              tooltip: '刷新',
              onPressed: () {
                setState(() {
                  _isReady = false;
                  _errorMessage = null;
                  _pdfBytesFuture = rootBundle.load(_selectedBook.assetPath);
                });
              },
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      body: _isReading
          ? SafeArea(
              child: FutureBuilder<ByteData>(
                future: _pdfBytesFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 64,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'PDF 资源加载失败',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedBook.assetPath,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final bytes = snapshot.data!.buffer.asUint8List();

                  return Column(
                    children: [
                      _ReaderToolbar(
                        assetPath: _selectedBook.assetPath,
                        currentPage: _currentPage,
                        pageCount: _pageCount,
                        pageController: _pageController,
                        onJumpToPage: _jumpToPage,
                        searchResult: _searchResult,
                        onPreviousSearch: _searchResult?.previousInstance,
                        onNextSearch: _searchResult?.nextInstance,
                        onClearSearch: _clearSearch,
                        hasBookmarks: _bookmarks.isNotEmpty,
                      ),
                      Expanded(child: _buildViewer(context, bytes)),
                      if (!_isReady)
                        const LinearProgressIndicator(minHeight: 2),
                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            )
          : _buildBookshelfHome(context),
    );

    if (_nightMode) {
      return Theme(data: _buildReaderTheme(context), child: scaffold);
    }

    return scaffold;
  }
}

class _BookshelfBookCard extends StatelessWidget {
  const _BookshelfBookCard({
    required this.book,
    required this.lastPage,
    required this.onTap,
  });

  final ReadingBookEntry book;
  final int lastPage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: book.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: book.colors.first.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PDF',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Icon(book.icon, color: Colors.white, size: 28),
                ],
              ),
              const Spacer(),
              Text(
                book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                book.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lastPage > 1 ? '最近到第$lastPage页' : '从头阅读',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderToolbar extends StatelessWidget {
  const _ReaderToolbar({
    required this.assetPath,
    required this.currentPage,
    required this.pageCount,
    required this.pageController,
    required this.onJumpToPage,
    required this.searchResult,
    required this.onPreviousSearch,
    required this.onNextSearch,
    required this.onClearSearch,
    required this.hasBookmarks,
  });

  final String assetPath;
  final int currentPage;
  final int pageCount;
  final TextEditingController pageController;
  final VoidCallback onJumpToPage;
  final PdfTextSearchResult? searchResult;
  final VoidCallback? onPreviousSearch;
  final VoidCallback? onNextSearch;
  final VoidCallback onClearSearch;
  final bool hasBookmarks;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    assetPath,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 12),
                Text('$currentPage${pageCount > 0 ? '/$pageCount' : ''}'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 84,
                  child: TextField(
                    controller: pageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '页码',
                    ),
                    onSubmitted: (_) => onJumpToPage(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: onJumpToPage, child: const Text('跳转')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (searchResult != null) ...[
                  IconButton(
                    tooltip: '上一个结果',
                    onPressed:
                        searchResult!.hasResult &&
                            searchResult!.currentInstanceIndex > 0
                        ? onPreviousSearch
                        : null,
                    icon: const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: '下一个结果',
                    onPressed: searchResult!.hasResult ? onNextSearch : null,
                    icon: const Icon(Icons.arrow_downward),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    searchResult!.hasResult
                        ? '${searchResult!.currentInstanceIndex + 1}/${searchResult!.totalInstanceCount}'
                        : '搜索中...',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onClearSearch,
                    child: const Text('清除搜索'),
                  ),
                ] else ...[
                  const Spacer(),
                  Text(
                    hasBookmarks ? '已加载目录，可点右上角进入' : '正在尝试读取目录/书签',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
