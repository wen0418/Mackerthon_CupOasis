import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'machine_detail_page.dart';
import 'qr_scan_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 🚨 統一管理你的後端 IP (請確認是你目前手機熱點的 IP)
  final String apiBaseUrl = 'http://10.245.39.41:8000'; 
  
  List<Marker> _machineMarkers = [];
  bool _isLoading = true;

  // 🌟 將原本寫死的成就數據改為動態變數
  int _returnCount = 0;
  int _rewardPoints = 0;
  String _userName = '載入中...';

  @override
  void initState() {
    super.initState();
    _fetchAllData(); // 初始化時同時抓取地圖與使用者資料
  }

  // 封裝一個同時更新所有資料的方法
  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchUserData(),
      _fetchMachines(),
    ]);
    setState(() => _isLoading = false);
  }

  // 🌟 新增：抓取使用者真實點數與成就
  Future<void> _fetchUserData() async {
    try {
      // Demo 階段先寫死抓取 user_id = 1 的資料
      final response = await http.get(Uri.parse('$apiBaseUrl/api/user/1'));
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _userName = data['name'];
          _returnCount = data['returned_count'];
          _rewardPoints = data['points'];
        });
      }
    } catch (e) {
      print("獲取使用者資料失敗: $e");
    }
  }

  // 修改：使用統一個 apiBaseUrl
  Future<void> _fetchMachines() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/api/machines'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _machineMarkers = data.map((machine) {
            return Marker(
              point: LatLng(machine['lat'], machine['lng']),
              width: 50,
              height: 50,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MachineDetailPage(machineId: machine['id']),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: machine['status'] == 'online' 
                        ? Theme.of(context).colorScheme.primary 
                        : Colors.grey, // 離線機台顯示灰色
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 3)),
                    ],
                  ),
                  child: const Icon(Icons.location_on, color: Colors.white, size: 28),
                ),
              ),
            );
          }).toList();
        });
      }
    } catch (e) {
      print("獲取機台資料失敗: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          '早安，$_userName 🌱', // 換成動態名字
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87), // 改成重新整理按鈕方便 Demo
            onPressed: _fetchAllData, 
          ),
        ],
      ),
      body: Column(
        children: [
          // ==========================================
          // 區塊 1：成就看板 (即時回饋感)
          // ==========================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Theme.of(context).colorScheme.primary, Colors.green.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('已成功循環', '$_returnCount 次', Icons.loop),
                  Container(height: 40, width: 1, color: Colors.white.withOpacity(0.5)),
                  _buildStatColumn('獲得點數', '$_rewardPoints 點', Icons.stars),
                ],
              ),
            ),
          ),

          // ==========================================
          // 區塊 2：核心行動按鈕 (租借與回收)
          // ==========================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context, 
                    title: '掃碼租借', 
                    subtitle: '拿新杯享優惠', 
                    icon: Icons.qr_code_scanner, 
                    color: Colors.blueAccent,
                    onTap: () async {
                      // 🌟 使用 await 等待使用者從掃碼頁面返回
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QRScanPage(actionType: 'rent'),
                        ),
                      );
                      // 返回後，立刻刷新畫面資料！
                      _fetchAllData();
                    }
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildActionButton(
                    context, 
                    title: '歸還循環杯', 
                    subtitle: '實體機構互動', 
                    icon: Icons.recycling, 
                    color: Colors.orangeAccent,
                    onTap: () async {
                      // 🌟 使用 await 等待使用者從掃碼頁面返回
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const QRScanPage(actionType: 'return'),
                        ),
                      );
                      // 返回後，立刻刷新畫面資料，讓使用者看到點數增加！
                      _fetchAllData();
                    }
                  ),
                ),
              ],
            ),
          ),

          // ==========================================
          // 區塊 3：尋找最近站點 (地圖區塊)
          // ==========================================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Row(
              children: [
                const Text('📍 附近循環站', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(onPressed: _fetchAllData, child: const Text('重整地圖')),
              ],
            ),
          ),
          
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: const LatLng(25.0429, 121.5356), // 北科大
                          initialZoom: 16.5,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.econexus_app',
                          ),
                          MarkerLayer(markers: _machineMarkers),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }
}