import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart'; // 引入滑动插件
import 'package:flutter/services.dart'; // 控制状态栏

// --- 1. 数据模型 Models ---

enum CourseStatus { unapplied, applied, received }

class CourseEntry {
  String id;
  CourseStatus status;
  String studentName;
  DateTime teachingDate;
  String? subject;
  double? duration;
  double? salary;
  String? subName; // 代讲人
  double? subSalary; // 代讲费
  DateTime? applicationDate;
  DateTime? receivedDate;
  int createdAt; // 用于排序序号

  CourseEntry({
    required this.id,
    this.status = CourseStatus.unapplied,
    this.studentName = '',
    required this.teachingDate,
    this.subject,
    this.duration,
    this.salary,
    this.subName,
    this.subSalary,
    this.applicationDate,
    this.receivedDate,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'status': status.index,
    'studentName': studentName,
    'teachingDate': teachingDate.toIso8601String(),
    'subject': subject,
    'duration': duration,
    'salary': salary,
    'subName': subName,
    'subSalary': subSalary,
    'applicationDate': applicationDate?.toIso8601String(),
    'receivedDate': receivedDate?.toIso8601String(),
    'createdAt': createdAt,
  };

  factory CourseEntry.fromJson(Map<String, dynamic> json) {
    return CourseEntry(
      id: json['id'],
      status: CourseStatus.values[json['status']],
      studentName: json['studentName'] ?? '',
      teachingDate: DateTime.parse(json['teachingDate']),
      subject: json['subject'],
      duration: json['duration'] != null
          ? (json['duration'] as num).toDouble()
          : null,
      salary: json['salary'] != null
          ? (json['salary'] as num).toDouble()
          : null,
      subName: json['subName'],
      subSalary: json['subSalary'] != null
          ? (json['subSalary'] as num).toDouble()
          : null,
      applicationDate: json['applicationDate'] != null
          ? DateTime.parse(json['applicationDate'])
          : null,
      receivedDate: json['receivedDate'] != null
          ? DateTime.parse(json['receivedDate'])
          : null,
      createdAt: json['createdAt'] ?? 0,
    );
  }
}

class Institution {
  String id;
  String name;
  List<CourseEntry> entries;

  Institution({required this.id, required this.name, required this.entries});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  factory Institution.fromJson(Map<String, dynamic> json) {
    return Institution(
      id: json['id'],
      name: json['name'],
      entries: (json['entries'] as List)
          .map((e) => CourseEntry.fromJson(e))
          .toList(),
    );
  }
}

// --- 2. 颜色风格定义 ---
class AppColors {
  static const Color primaryGreen = Color(0xFF5A7957); // 鼠尾草绿
  static const Color accentGreen = Color(0xFF8AAB87); // 浅一点的绿
  static const Color bgCream = Color(0xFFF7F9F5); // 米色背景
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF4A5A48); // 深色文字
  static const Color subHighlight = Color(0xFFE3EBE1); // 代讲人高亮背景
  static const Color textGrey = Color(0xFFAAAAAA);
}

// --- 3. 主程序入口 ---
void main() {
  // 1. 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 设置状态栏样式：透明背景，深色图标(黑色)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // Android: 状态栏背景透明
      statusBarIconBrightness: Brightness.dark, // Android: 图标变黑
      statusBarBrightness: Brightness.light, // iOS: 告诉系统背景是亮的，它会自动把图标变黑
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '课时助手',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bgCream,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryGreen),
        fontFamilyFallback: const ['Round', 'Roboto'],

        // --- 核心修改在这里 ---
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, // 导航栏背景透明
          elevation: 0,
          centerTitle: true,
          // 强制设定 AppBar 覆盖下的状态栏样式
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark, // 安卓图标黑
            statusBarBrightness: Brightness.light, // iOS图标黑
          ),
          titleTextStyle: TextStyle(
            color: AppColors.textDark,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
          iconTheme: IconThemeData(color: AppColors.textDark),
        ),
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  List<Institution> institutions = [];
  List<Map<String, String>> shortcuts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final String? shortcutsStr = prefs.getString('my_shortcuts');
    if (shortcutsStr != null) {
      final List<dynamic> decoded = jsonDecode(shortcutsStr);
      setState(() {
        shortcuts = decoded.map((e) => Map<String, String>.from(e)).toList();
      });
    } else {
      shortcuts = [
        {'name': '淘宝', 'url': 'taobao://'},
        {'name': '支付宝', 'url': 'alipays://platformapi/startapp?appId=10000007'},
        {'name': '百度', 'url': 'https://www.baidu.com'},
      ];
    }

    final String? instStr = prefs.getString('my_institutions');
    if (instStr != null) {
      final List<dynamic> decoded = jsonDecode(instStr);
      setState(() {
        institutions = decoded.map((e) => Institution.fromJson(e)).toList();
      });
    } else {
      institutions = [
        Institution(id: '1', name: '去保研', entries: []),
        Institution(id: '2', name: '保研人', entries: []),
        Institution(id: '3', name: '保研岛', entries: []),
      ];
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('my_shortcuts', jsonEncode(shortcuts));
    await prefs.setString('my_institutions', jsonEncode(institutions));
    setState(() {});
  }

  // 新增逻辑：删除机构
  void _deleteInstitution(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除机构'),
        content: Text('确定要删除“${institutions[index].name}”及其所有数据吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                institutions.removeAt(index);
              });
              _saveData();
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 新增逻辑：重命名机构
  void _renameInstitution(int index) {
    TextEditingController c = TextEditingController(
      text: institutions[index].name,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改名称'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(labelText: '机构名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (c.text.isNotEmpty) {
                setState(() {
                  institutions[index].name = c.text;
                });
                _saveData();
                Navigator.pop(ctx);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedIndex == 0
          ? QuickJumpPage(
              shortcuts: shortcuts,
              onSave: (newList) {
                shortcuts = newList;
                _saveData();
              },
            )
          : CourseCalcPage(
              institutions: institutions,
              onUpdate: _saveData,
              onDeleteInst: _deleteInstitution, // 传入删除回调
              onEditInst: _renameInstitution, // 传入编辑回调
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primaryGreen.withOpacity(0.2),
        elevation: 5,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.rocket_launch_outlined),
            selectedIcon: Icon(
              Icons.rocket_launch,
              color: AppColors.primaryGreen,
            ),
            label: '快捷跳转',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate, color: AppColors.primaryGreen),
            label: '课程计算',
          ),
        ],
      ),
    );
  }
}

// ... QuickJumpPage 保持不变 ...
class QuickJumpPage extends StatelessWidget {
  final List<Map<String, String>> shortcuts;
  final Function(List<Map<String, String>>) onSave;

  const QuickJumpPage({
    super.key,
    required this.shortcuts,
    required this.onSave,
  });

  Future<void> _launchURL(BuildContext context, String urlString) async {
    if (!urlString.startsWith('http') && !urlString.contains('://')) {
      urlString = 'https://$urlString';
    }
    try {
      await launchUrl(
        Uri.parse(urlString),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法跳转: $urlString')));
      }
    }
  }

  void _showAddDialog(BuildContext context) {
    String name = '';
    String url = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '添加快捷方式',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: '名称'),
              onChanged: (v) => name = v,
            ),
            TextField(
              decoration: const InputDecoration(labelText: '链接/Scheme'),
              onChanged: (v) => url = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              if (name.isNotEmpty && url.isNotEmpty) {
                shortcuts.add({'name': name, 'url': url});
                onSave(shortcuts);
                Navigator.pop(ctx);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('快捷跳转')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.5,
        ),
        itemCount: shortcuts.length,
        itemBuilder: (context, index) {
          final item = shortcuts[index];
          // 给快捷跳转也加上滑动删除功能（可选）
          return Slidable(
            key: ValueKey(item['url']),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) {
                    shortcuts.removeAt(index);
                    onSave(shortcuts);
                  },
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  icon: Icons.delete,
                  label: '删除',
                  borderRadius: BorderRadius.circular(16),
                ),
              ],
            ),
            child: InkWell(
              onTap: () => _launchURL(context, item['url']!),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  item['name']!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ======================= 页面 2：课程计算 =======================
class CourseCalcPage extends StatefulWidget {
  final List<Institution> institutions;
  final VoidCallback onUpdate;
  final Function(int) onDeleteInst;
  final Function(int) onEditInst;

  const CourseCalcPage({
    super.key,
    required this.institutions,
    required this.onUpdate,
    required this.onDeleteInst,
    required this.onEditInst,
  });

  @override
  State<CourseCalcPage> createState() => _CourseCalcPageState();
}

class _CourseCalcPageState extends State<CourseCalcPage> {
  DateTime selectedMonth = DateTime.now();

  double _calcAmount(Institution inst, CourseStatus status) {
    double total = 0;
    for (var entry in inst.entries) {
      if (entry.status != status) continue;

      bool isSameMonth = false;
      if (status == CourseStatus.unapplied) {
        isSameMonth =
            entry.teachingDate.year == selectedMonth.year &&
            entry.teachingDate.month == selectedMonth.month;
      } else if (status == CourseStatus.applied) {
        if (entry.applicationDate == null) continue;
        isSameMonth =
            entry.applicationDate!.year == selectedMonth.year &&
            entry.applicationDate!.month == selectedMonth.month;
      } else if (status == CourseStatus.received) {
        if (entry.receivedDate == null) continue;
        isSameMonth =
            entry.receivedDate!.year == selectedMonth.year &&
            entry.receivedDate!.month == selectedMonth.month;
      }

      if (isSameMonth) {
        total += entry.salary ?? 0;
      }
    }
    return total;
  }

  void _showSearch() {
    showSearch(
      context: context,
      delegate: CourseSearchDelegate(widget.institutions, widget.onUpdate),
    );
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() => selectedMonth = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            left: 16,
            right: 16,
            bottom: 10,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.bgCream,
                AppColors.primaryGreen.withOpacity(0.15),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _pickMonth,
                    icon: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  Text(
                    DateFormat('yyyy年 MM月').format(selectedMonth),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                    ),
                  ),
                  IconButton(
                    onPressed: _showSearch,
                    icon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
              const Text(
                '我的薪酬',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          TextEditingController c = TextEditingController();
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('新增机构'),
              content: TextField(
                controller: c,
                decoration: const InputDecoration(labelText: '机构名称'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (c.text.isNotEmpty) {
                      widget.institutions.add(
                        Institution(
                          id: DateTime.now().toString(),
                          name: c.text,
                          entries: [],
                        ),
                      );
                      widget.onUpdate();
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        },
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: widget.institutions.length,
        itemBuilder: (context, index) {
          final inst = widget.institutions[index];
          final unapplied = _calcAmount(inst, CourseStatus.unapplied);
          final applied = _calcAmount(inst, CourseStatus.applied);
          final received = _calcAmount(inst, CourseStatus.received);

          return _buildInstitutionCard(
            index,
            inst,
            unapplied,
            applied,
            received,
          );
        },
      ),
    );
  }

  // 修改这里：增加 Slidable 滑动删除
  Widget _buildInstitutionCard(
    int index,
    Institution inst,
    double un,
    double ap,
    double re,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Slidable(
        key: ValueKey(inst.id),
        // 右侧操作按钮
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.5, // 按钮总宽度占比
          children: [
            SlidableAction(
              onPressed: (context) => widget.onEditInst(index),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              icon: Icons.edit,
              label: '编辑',
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(24),
              ),
            ),
            SlidableAction(
              onPressed: (context) => widget.onDeleteInst(index),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: '删除',
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(24),
              ),
            ),
          ],
        ),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InstitutionDetailPage(
                  institution: inst,
                  onUpdate: widget.onUpdate,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryGreen.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      inst.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem('待申请', un, Colors.orange),
                    _buildStatItem('审批中', ap, Colors.blue),
                    _buildStatItem('已付款', re, AppColors.primaryGreen),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '¥${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ======================= 页面 3：机构详情 =======================
class InstitutionDetailPage extends StatefulWidget {
  final Institution institution;
  final VoidCallback onUpdate;

  const InstitutionDetailPage({
    super.key,
    required this.institution,
    required this.onUpdate,
  });

  @override
  State<InstitutionDetailPage> createState() => _InstitutionDetailPageState();
}

class _InstitutionDetailPageState extends State<InstitutionDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _deleteEntry(CourseEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除词条'),
        content: const Text('确定要删除这条记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                widget.institution.entries.remove(entry);
              });
              widget.onUpdate();
              Navigator.pop(ctx);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.institution.name),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryGreen,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900),
          tabs: const [
            Tab(text: '未申请'),
            Tab(text: '已申请'),
            Tab(text: '已到账'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEntryEditor(null),
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEntryList(CourseStatus.unapplied),
          _buildEntryList(CourseStatus.applied),
          _buildEntryList(CourseStatus.received),
        ],
      ),
    );
  }

  Widget _buildEntryList(CourseStatus status) {
    final list = widget.institution.entries
        .where((e) => e.status == status)
        .toList();

    list.sort((a, b) {
      bool aSub = (a.subName != null && a.subName!.isNotEmpty);
      bool bSub = (b.subName != null && b.subName!.isNotEmpty);
      if (aSub != bSub) return aSub ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });

    if (list.isEmpty)
      return const Center(
        child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
      );

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final entry = list[index];
        bool isSubstitute = entry.subName != null && entry.subName!.isNotEmpty;

        // 修改这里：增加 Slidable 滑动删除
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Slidable(
            key: ValueKey(entry.id),
            endActionPane: ActionPane(
              motion: const ScrollMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) => _deleteEntry(entry),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  icon: Icons.delete,
                  label: '删除',
                  borderRadius: BorderRadius.circular(16),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EntryDetailPage(
                      entry: entry,
                      onUpdate: widget.onUpdate,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSubstitute
                      ? AppColors.subHighlight
                      : AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.bgCream,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.studentName.isEmpty
                                ? '未命名学员'
                                : entry.studentName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormat('yyyy.MM.dd').format(entry.teachingDate)} | ${entry.subject ?? '-'} | ${entry.duration ?? 0}课时',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '¥${entry.salary?.toStringAsFixed(0) ?? 0}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        if (isSubstitute)
                          Text(
                            '代: ${entry.subName}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textDark,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openEntryEditor(CourseEntry? entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EntryEditorPage(
          entry: entry,
          institutionId: widget.institution.id,
          onSave: (newEntry) {
            if (entry == null) {
              widget.institution.entries.add(newEntry);
            }
            widget.onUpdate();
            setState(() {});
          },
        ),
      ),
    );
  }
}

// ... EntryDetailPage, EntryEditorPage, CourseSearchDelegate 保持不变 ...
// (为了节省篇幅，这里复用之前代码，如果你需要完整的请告诉我，我可以再贴一次)
class EntryDetailPage extends StatelessWidget {
  final CourseEntry entry;
  final VoidCallback onUpdate;

  const EntryDetailPage({
    super.key,
    required this.entry,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('课时详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => EntryEditorPage(
                    entry: entry,
                    institutionId: '',
                    onSave: (e) => onUpdate(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildDetailCard([
              _buildRow('状态', _statusStr(entry.status)),
              _buildRow('学员姓名', entry.studentName),
              _buildRow(
                '授课时间',
                DateFormat('yyyy.MM.dd').format(entry.teachingDate),
              ),
              _buildRow('科目', entry.subject),
              _buildRow('课时', '${entry.duration ?? 0}'),
              _buildRow('薪资', '¥${entry.salary ?? 0}'),
              if (entry.subName != null && entry.subName!.isNotEmpty) ...[
                const Divider(),
                _buildRow('代讲人', entry.subName),
                _buildRow('代讲费', '¥${entry.subSalary ?? 0}'),
              ],
              if (entry.status == CourseStatus.applied ||
                  entry.status == CourseStatus.received) ...[
                const Divider(),
                _buildRow(
                  '申请时间',
                  entry.applicationDate != null
                      ? DateFormat('yyyy.MM.dd').format(entry.applicationDate!)
                      : '-',
                ),
              ],
              if (entry.status == CourseStatus.received) ...[
                _buildRow(
                  '到账时间',
                  entry.receivedDate != null
                      ? DateFormat('yyyy.MM.dd').format(entry.receivedDate!)
                      : '-',
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  String _statusStr(CourseStatus s) => s == CourseStatus.unapplied
      ? '待申请'
      : (s == CourseStatus.applied ? '审批中' : '已付款');

  Widget _buildDetailCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value ?? '-',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class EntryEditorPage extends StatefulWidget {
  final CourseEntry? entry;
  final String institutionId;
  final Function(CourseEntry) onSave;

  const EntryEditorPage({
    super.key,
    this.entry,
    required this.institutionId,
    required this.onSave,
  });

  @override
  State<EntryEditorPage> createState() => _EntryEditorPageState();
}

class _EntryEditorPageState extends State<EntryEditorPage> {
  late CourseStatus _status;
  final _studentCtrl = TextEditingController();
  final _subjectCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _subNameCtrl = TextEditingController();
  final _subSalaryCtrl = TextEditingController();

  DateTime _teachingDate = DateTime.now();
  DateTime? _appDate;
  DateTime? _recDate;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      final e = widget.entry!;
      _status = e.status;
      _studentCtrl.text = e.studentName;
      _subjectCtrl.text = e.subject ?? '';
      _durationCtrl.text = e.duration?.toString() ?? '';
      _salaryCtrl.text = e.salary?.toString() ?? '';
      _subNameCtrl.text = e.subName ?? '';
      _subSalaryCtrl.text = e.subSalary?.toString() ?? '';
      _teachingDate = e.teachingDate;
      _appDate = e.applicationDate;
      _recDate = e.receivedDate;
    } else {
      _status = CourseStatus.unapplied;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? '新增课时' : '编辑课时'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              '保存',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSectionTitle('基本信息'),
            _buildDropdown(),
            _buildInput('学员姓名', _studentCtrl),
            _buildDatePicker(
              '授课时间',
              _teachingDate,
              (d) => setState(() => _teachingDate = d),
            ),
            Row(
              children: [
                Expanded(child: _buildInput('科目', _subjectCtrl)),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInput('课时', _durationCtrl, isNumber: true),
                ),
              ],
            ),
            _buildInput('薪资 (元)', _salaryCtrl, isNumber: true),

            const SizedBox(height: 20),
            _buildSectionTitle('代讲信息 (选填)'),
            Row(
              children: [
                Expanded(child: _buildInput('代讲人', _subNameCtrl)),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInput('代讲费', _subSalaryCtrl, isNumber: true),
                ),
              ],
            ),

            if (_status == CourseStatus.applied ||
                _status == CourseStatus.received) ...[
              const SizedBox(height: 20),
              _buildSectionTitle('进度信息'),
              _buildDatePicker(
                '申请时间',
                _appDate ?? DateTime.now(),
                (d) => setState(() => _appDate = d),
              ),
            ],
            if (_status == CourseStatus.received) ...[
              _buildDatePicker(
                '到账时间',
                _recDate ?? DateTime.now(),
                (d) => setState(() => _recDate = d),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CourseStatus>(
          value: _status,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: CourseStatus.unapplied, child: Text('未申请')),
            DropdownMenuItem(value: CourseStatus.applied, child: Text('已申请')),
            DropdownMenuItem(value: CourseStatus.received, child: Text('已到账')),
          ],
          onChanged: (v) {
            setState(() {
              _status = v!;
              if (_status == CourseStatus.applied && _appDate == null)
                _appDate = DateTime.now();
              if (_status == CourseStatus.received && _recDate == null)
                _recDate = DateTime.now();
            });
          },
        ),
      ),
    );
  }

  Widget _buildInput(
    String label,
    TextEditingController ctrl, {
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildDatePicker(
    String label,
    DateTime date,
    Function(DateTime) onPick,
  ) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (d != null) onPick(d);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.black54)),
            Text(
              DateFormat('yyyy.MM.dd').format(date),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final newEntry = CourseEntry(
      id: widget.entry?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      status: _status,
      studentName: _studentCtrl.text,
      teachingDate: _teachingDate,
      subject: _subjectCtrl.text,
      duration: double.tryParse(_durationCtrl.text),
      salary: double.tryParse(_salaryCtrl.text),
      subName: _subNameCtrl.text,
      subSalary: double.tryParse(_subSalaryCtrl.text),
      applicationDate: _status != CourseStatus.unapplied ? _appDate : null,
      receivedDate: _status == CourseStatus.received ? _recDate : null,
      createdAt:
          widget.entry?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
    );

    if (widget.entry != null) {
      widget.entry!.status = newEntry.status;
      widget.entry!.studentName = newEntry.studentName;
      widget.entry!.teachingDate = newEntry.teachingDate;
      widget.entry!.subject = newEntry.subject;
      widget.entry!.duration = newEntry.duration;
      widget.entry!.salary = newEntry.salary;
      widget.entry!.subName = newEntry.subName;
      widget.entry!.subSalary = newEntry.subSalary;
      widget.entry!.applicationDate = newEntry.applicationDate;
      widget.entry!.receivedDate = newEntry.receivedDate;
    }

    widget.onSave(newEntry);
    Navigator.pop(context);
  }
}

class CourseSearchDelegate extends SearchDelegate {
  final List<Institution> institutions;
  final VoidCallback onUpdate;

  CourseSearchDelegate(this.institutions, this.onUpdate);

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    if (query.isEmpty) return Container();

    List<CourseEntry> results = [];
    for (var inst in institutions) {
      for (var entry in inst.entries) {
        if (entry.studentName.contains(query)) {
          results.add(entry);
        }
      }
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final entry = results[index];
        return ListTile(
          title: Text(entry.studentName),
          subtitle: Text(
            '${DateFormat('MM.dd').format(entry.teachingDate)} - ${entry.subject}',
          ),
          trailing: Text('¥${entry.salary ?? 0}'),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    EntryDetailPage(entry: entry, onUpdate: onUpdate),
              ),
            );
          },
        );
      },
    );
  }
}
