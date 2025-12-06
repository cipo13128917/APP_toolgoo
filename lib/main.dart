import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'QuickJump Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, String>> shortcuts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dataString = prefs.getString('my_shortcuts');

    if (dataString != null) {
      final List<dynamic> decoded = jsonDecode(dataString);
      setState(() {
        shortcuts = decoded.map((e) => Map<String, String>.from(e)).toList();
      });
    } else {
      setState(() {
        shortcuts = [
          {'name': '打开淘宝', 'url': 'taobao://'},
          {
            'name': '支付宝扫码',
            'url': 'alipays://platformapi/startapp?appId=10000007',
          },
        ];
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_shortcuts', jsonEncode(shortcuts));
  }

  void _addShortcut(String name, String url) {
    setState(() {
      shortcuts.add({'name': name, 'url': url});
    });
    _saveData();
  }

  void _deleteShortcut(int index) {
    setState(() {
      shortcuts.removeAt(index);
    });
    _saveData();
  }

  Future<void> _launchURL(String urlString) async {
    if (!urlString.startsWith('http') && !urlString.contains('://')) {
      urlString = 'https://$urlString';
    }

    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      // --- 核心修改在这里 ---
      // 把 context.mounted 改成了 mounted
      // 意思：如果当前页面(State)已经被销毁了，就直接退出，不要运行下面的代码
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法跳转: $urlString')));
    }
  }

  void _showAddDialog() {
    String inputName = '';
    String inputUrl = '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加新指令'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: '名称 (如: 蚂蚁森林)'),
                onChanged: (value) => inputName = value,
              ),
              TextField(
                decoration: const InputDecoration(labelText: '跳转链接 (Scheme)'),
                onChanged: (value) => inputUrl = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                if (inputName.isNotEmpty && inputUrl.isNotEmpty) {
                  _addShortcut(inputName, inputUrl);
                  Navigator.pop(context);
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的快捷指令'),
        centerTitle: true,
        // --- 修复点 2：使用 withValues 替代 withOpacity ---
        backgroundColor: Colors.blue.withValues(alpha: 0.1),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
      body: shortcuts.isEmpty
          ? const Center(child: Text('还没添加指令，点右下角添加吧！'))
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: shortcuts.length,
              itemBuilder: (context, index) {
                final item = shortcuts[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        item['name']!.isEmpty ? '?' : item['name']![0],
                      ),
                    ),
                    title: Text(item['name']!),
                    subtitle: Text(
                      item['url']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _launchURL(item['url']!),
                    onLongPress: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('删除此指令?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () {
                                _deleteShortcut(index);
                                Navigator.pop(ctx);
                              },
                              child: const Text(
                                '删除',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
