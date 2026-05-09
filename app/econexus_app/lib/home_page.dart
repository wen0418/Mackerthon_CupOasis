import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'machine_detail_page.dart';
import 'qr_scan_page.dart';
import 'eco_planet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 🚨 你的熱點 IP
  final String apiBaseUrl = 'http://172.26.43.41:8000'; 
  
  List<Marker> _machineMarkers = [];
  bool _isLoading = true;

  int _returnCount = 0;
  int _rewardPoints = 0;
  String _userName = '載入中...';

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    // 使用 catchError 避免其中一個 API 失敗導致整個畫面卡住
    await Future.wait([
      _fetchUserData().catchError((e) => debugPrint('User API Error: $e')),
      _fetchMachines().catchError((e) => debugPrint('Machine API Error: $e')),
    ]);
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserData() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/api/user/1'))
        .timeout(const Duration(seconds: 5)); // 加上超時機制
    
    if (response.statusCode == 200) {
      final data = json.decode(utf8.decode(response.bodyBytes));
      if (mounted) {
        setState(() {
          _userName = data['name'] ?? 'Demo User';
          // 確保型別轉換安全
          _returnCount = int.tryParse(data['returned_count'].toString()) ?? 0;
          _rewardPoints = int.tryParse(data['points'].toString()) ?? 0;
        });
      }
    }
  }

  Future<void> _fetchMachines() async {
    final response = await http.get(Uri.parse('$apiBaseUrl/api/machines'))
        .timeout(const Duration(seconds: 5));
        
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      if (mounted) {
        setState(() {
          _machineMarkers = data.map((machine) {
            // 🛡️ 安全解析經緯度 (避免 int 與 double 轉換錯誤)
            final double lat = (machine['lat'] as num).toDouble();
            final double lng = (machine['lng'] as num).toDouble();
            
            return Marker(
              point: LatLng(lat, lng),
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
                        ? const Color(0xFF00C4B4) // 使用你的青翠綠
                        : Colors.grey.shade700,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: const Icon(Icons.eco, color: Colors.white, size: 24),
                ),
              ),
            );
          }).toList();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // 確保純粹的深色背景
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.eco, color: Color(0xFF00C4B4), size: 24),
            const SizedBox(width: 8),
            Text(
              '早安，SHIYEE',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
      body: SafeArea( // 確保不會被瀏海或底部白條擋住
        child: Column(
          children: [
            // 區塊 1：成就看板
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF20B2AA), Color(0xFF7FFFD4)], // 漸層綠色
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn('已成功循環', '$_returnCount 次', Icons.autorenew),
                    Container(height: 40, width: 1, color: Colors.white.withOpacity(0.5)),
                    _buildStatColumn('獲得點數', '$_rewardPoints 點', Icons.star),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),
            const Text(
              '您的小樹點',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
            const SizedBox(height: 10),

            // 你的小樹星球動畫元件
            EcoPlanet(returnCount: _returnCount), 
            
            const SizedBox(height: 20),

            // 區塊 2：核心行動按鈕
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      context, 
                      title: '掃碼租借', 
                      subtitle: '拿新杯享優惠', 
                      icon: Icons.qr_code_scanner, 
                      iconColor: const Color(0xFF00C4B4),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const QRScanPage(actionType: 'rent')),
                        );
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
                      iconColor: const Color(0xFF00C4B4),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const QRScanPage(actionType: 'return')),
                        );
                        _fetchAllData();
                      }
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 區塊 3：地圖標題列
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.push_pin, color: Color(0xFF00C4B4), size: 20),
                  const SizedBox(width: 8),
                  const Text('附近循環站', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  InkWell(
                    onTap: _fetchAllData,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00C4B4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('重整地圖', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 10),

            // 區塊 4：地圖
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C4B4)))
                      : FlutterMap(
                          options: MapOptions(
                            initialCenter: const LatLng(25.0429, 121.5356),
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
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.black87, size: 24),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color iconColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15), 
                shape: BoxShape.circle
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}