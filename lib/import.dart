import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowMaterialGrid: false,
      title: 'Bookmark Viewer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<BookmarkFolder> bookmarkFolders = [];

  Future<void> _pickAndProcessHTMLFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['html'],
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      setState(() {
        bookmarkFolders = parseHTMLFile(file);
      });
    } else {
      // User canceled the picker
    }
  }

  List<BookmarkFolder> parseHTMLFile(File file) {
    List<BookmarkFolder> bookmarkFolders = [];
    String htmlContent = file.readAsStringSync();
    dom.Document document = parse(htmlContent);

    var folders = document.querySelectorAll("dl > dt");
    for (var folder in folders) {
      var folderName = folder.querySelector('H3')?.text.trim();
      var subfolders = folder.querySelectorAll("dl");
      if (subfolders.isNotEmpty) {
        // This is a main folder
        List<BookmarkItem> items = [];
        var folderItems = folder.querySelectorAll("a");
        if (folderItems != null) {
          for (var item in folderItems) {
            var itemName = item.text.trim().replaceAll(RegExp(r'\s+'), ' ');
            var itemLink = item.attributes['href'];
            var addDate =
                _formatDate(int.parse(item.attributes['add_date'] ?? '0'));
            var modifiedDate =
                _formatDate(int.parse(item.attributes['last_modified'] ?? '0'));
            items.add(BookmarkItem(
                name: itemName,
                link: itemLink,
                addDate: addDate,
                modifiedDate: modifiedDate));
          }
        }
        bookmarkFolders
            .add(BookmarkFolder(name: folderName ?? '', items: items));
      } else {
        // This is a subfolder, skip it
        continue;
      }
    }
    return bookmarkFolders;
  }

  String _formatDate(int timestamp) {
    DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bookmark Viewer'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _pickAndProcessHTMLFile(context),
              child: Text('Select HTML File'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: bookmarkFolders.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(
                      bookmarkFolders[index].name,
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    leading: Icon(Icons.folder),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              FolderView(folder: bookmarkFolders[index]),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FolderView extends StatefulWidget {
  final BookmarkFolder folder;

  FolderView({required this.folder});

  @override
  _FolderViewState createState() => _FolderViewState();
}

class _FolderViewState extends State<FolderView> {
  bool _selectAll = false;

  void _openSelectedBookmarks() async {
    for (var item in widget.folder.items) {
      if (item.selected && item.link != null) {
        await launch(item.link!);
      }
    }
  }

  int getSelectedCount() {
    return widget.folder.items.where((item) => item.selected).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(
              child: Text(
                widget.folder.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8),
            Text(
              '(${getSelectedCount()})',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.open_in_browser),
            onPressed: _openSelectedBookmarks,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                if (value == 'selectAll') {
                  _selectAll = true;
                  for (var item in widget.folder.items) {
                    item.selected = true;
                  }
                } else if (value == 'deselectAll') {
                  _selectAll = false;
                  for (var item in widget.folder.items) {
                    item.selected = false;
                  }
                }
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'selectAll',
                child:Text('Select All'),
              ),
              PopupMenuItem<String>(
                value: 'deselectAll',
                child: Text('Deselect All'),
              ),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: widget.folder.items.length,
        itemBuilder: (context, index) {
          return Card(
            child: ListTile(
              title: Text(widget.folder.items[index].name),
              subtitle: Text(
                  "Added: ${widget.folder.items[index].addDate}  Modified: ${widget.folder.items[index].modifiedDate}"),
              trailing: Checkbox(
                value: _selectAll ? true : widget.folder.items[index].selected,
                onChanged: (value) {
                  setState(() {
                    widget.folder.items[index].selected = value ?? false;
                  });
                },
              ),
              onTap: () {
                setState(() {
                  widget.folder.items[index].selected =
                      !widget.folder.items[index].selected;
                });
              },
            ),
          );
        },
      ),
    );
  }
}

class BookmarkFolder {
  final String name;
  final List<BookmarkItem> items;

  BookmarkFolder({required this.name, required this.items});
}

class BookmarkItem {
  final String name;
  final String? link;
  final String? addDate;
  final String? modifiedDate;
  bool selected;

  BookmarkItem(
      {required this.name,
      this.link,
      this.addDate,
      this.modifiedDate,
      this.selected = false});
}

