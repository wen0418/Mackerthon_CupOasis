import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// 如果你要格式化時間，可以在 pubspec.yaml 加入 intl 套件，並 import 'package:intl/intl.dart'; 
// 這裡我們先用簡單的字串處理示範

class MachineDetailPage extends StatefulWidget {
  final String machineId;

  const MachineDetailPage({
    super.key, 
    required this.machineId,
  });

  @override
  State<MachineDetailPage> createState() => _MachineDetailPageState();
}

class _MachineDetailPageState extends State<MachineDetailPage> {
  // 存放從 API 抓回來的商品資料
  List<dynamic> _products = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchInventory(); // 進入畫面時立刻抓取資料
  }

  Future<void> _fetchInventory() async {
    // ⚠️ 記得將網址換成你對應的環境 (例如 10.0.2.2 或 ngrok 網址)
    // 這裡假設後端 API 路徑是 /api/machines/{machineId}/products
    final url = 'http://10.0.2.2:8000/api/machines/${widget.machineId}/products';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // 使用 utf8.decode 避免中文變亂碼
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        
        setState(() {
          _products = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = "無法取得資料 (狀態碼: ${response.statusCode})";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "網路連線發生錯誤，請確認 API 是否啟動。";
        _isLoading = false;
      });
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('📍 機台庫存 (${widget.machineId})'),
        actions: [
          // 加上一個重新整理按鈕
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
              _fetchInventory();
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // 1. 狀態：載入中
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在同步即時庫存...'),
          ],
        ),
      );
    }

    // 2. 狀態：發生錯誤
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      );
    }

    // 3. 狀態：空空如也 (機台沒商品)
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('這台機器目前沒有商品喔！', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    // 4. 狀態：成功顯示列表
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        final bool isDiscounted = product['is_discounted'] ?? false;
        
        // 簡單處理時間字串 (把 T 拔掉，只留到分鐘)
        String expiryStr = product['expiry_time']?.toString().replaceAll('T', ' ').substring(0, 16) ?? '未知';

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isDiscounted 
                  ? Colors.orange.withOpacity(0.2) 
                  : Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                isDiscounted ? Icons.sell : Icons.fastfood, 
                color: isDiscounted ? Colors.orange : Theme.of(context).colorScheme.primary,
              ),
            ),
            title: Text(
              product['name'] ?? '未知商品',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('種類: ${product['category'] ?? '一般'}'),
                Text('到期: $expiryStr', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isDiscounted) 
                  const Text('友善時光', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                Text(
                  'NT\$ ${product['current_price']}',
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold,
                    color: isDiscounted ? Colors.orange : Colors.black87,
                  ),
                ),
                if (isDiscounted)
                  Text(
                    '原價 \$${product['original_price']}',
                    style: const TextStyle(
                      fontSize: 12, 
                      color: Colors.grey, 
                      decoration: TextDecoration.lineThrough, // 畫刪除線
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}