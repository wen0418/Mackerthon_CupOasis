import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // 🌟 引入藍牙套件
import 'package:permission_handler/permission_handler.dart';

class QRScanPage extends StatefulWidget {
  final String actionType; // 傳入 'rent' 或 'return'

  const QRScanPage({super.key, required this.actionType});

  @override
  State<QRScanPage> createState() => _QRScanPageState();
}

class _QRScanPageState extends State<QRScanPage> {
  final MobileScannerController _cameraController = MobileScannerController();
  bool _isProcessing = false; 

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  // ==========================================
  // 🌸 藍牙觸發核心邏輯 (背景執行不卡 UI)
  // ==========================================
  Future<void> _triggerFlowerBloom() async {
    print("🌸 [進入藍牙函式] 啟動藍牙掃描，尋找花花吊飾...");
    
    try {
      // 🌟 新增：第一步先動態請求所有需要的權限
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location, // 舊版 Android 需要定位權限才能掃描藍牙
      ].request();

      // 檢查權限是否被拒絕
      if (statuses[Permission.bluetoothScan]?.isDenied == true ||
          statuses[Permission.bluetoothConnect]?.isDenied == true) {
        print("❌ [錯誤] 使用者拒絕了藍牙權限，無法掃描！");
        // 這裡可以考慮跳出一個 AlertDialog 提醒使用者去設定裡開啟
        return;
      }

      // 🌟 防呆：檢查裝置是否支援藍牙
      if (await FlutterBluePlus.isSupported == false) {
        print("❌ [錯誤] 此裝置不支援藍牙 (請確認是否使用實體手機測試)！");
        return;
      }

      // 🌟 加上 Timeout 防止 await 卡死，並正確獲取狀態
      final adapterState = await FlutterBluePlus.adapterState.first.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          print("⚠️ [警告] 取得藍牙狀態超時！");
          return BluetoothAdapterState.unknown;
        },
      );

      // 如果權限有了，但藍牙沒開
      if (adapterState == BluetoothAdapterState.off) {
         print("❌ [錯誤] 手機藍牙未開啟，嘗試喚起開啟藍牙設定...");
         // 在 Android 上可以嘗試強制開啟藍牙 (選用)
         await FlutterBluePlus.turnOn();
         return;
      }

      if (adapterState != BluetoothAdapterState.on) {
        print("❌ [錯誤] 藍牙狀態異常！目前狀態: $adapterState");
        return;
      }

      // ================= 以下為原本的掃描邏輯 =================
      print("✅ 權限與狀態皆正常，開始掃描 10 秒...");
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // ================= 以下為你原本的掃描邏輯 =================
      // 🌟 把掃描時間拉長到 10 秒
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      var subscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          
          // 🌟 雷達掃描：抓取裝置名稱
          String deviceName = r.device.platformName;
          if (deviceName.isEmpty) {
            deviceName = r.advertisementData.advName;
          }
          
          if (deviceName.isNotEmpty) {
            print("📡 [雷達] 發現裝置: $deviceName (ID: ${r.device.remoteId})");
          }

          // 🌟 防呆：不分大小寫比對名稱
          if (deviceName.toLowerCase() == "econexus_flower".toLowerCase()) {
            print("🎯 [找到裝置] 找到花花吊飾！準備連線...");
            FlutterBluePlus.stopScan(); 
            
            try {
              await r.device.connect(timeout: const Duration(seconds: 5));
              print("✅ [連線成功] 正在尋找服務信箱...");

              List<BluetoothService> services = await r.device.discoverServices();
              for (BluetoothService service in services) {
                if (service.uuid.toString().toLowerCase() == "4fafc201-1fb5-459e-8fcc-c5c9c331914b".toLowerCase()) {
                  print("📬 [找到服務] 找到花花專屬服務！");
                  
                  for (BluetoothCharacteristic c in service.characteristics) {
                    if (c.uuid.toString().toLowerCase() == "beb5483e-36e1-4688-b7f5-ea07361b26a8".toLowerCase()) {
                      print("✉️ [找到特徵值] 準備寫入 BLOOM 指令...");
                      
                      await c.write(utf8.encode("BLOOM"), withoutResponse: true);
                      print("🌸 [發射完成] BLOOM 指令已送出！實體花朵應該要動了！");
                      
                      Future.delayed(const Duration(seconds: 3), () {
                        r.device.disconnect();
                        print("🔌 藍牙已安全斷開。");
                      });
                      
                      return; 
                    }
                  }
                }
              }
              print("⚠️ [警告] 連線成功，但沒有找到對應的 UUID 信箱。");
            } catch (e) {
              print("❌ [連線錯誤] 連線或傳輸失敗: $e");
              r.device.disconnect();
            }
          }
        }
      });
    } catch (e) {
      // 🌟 現在任何藍牙權限、狀態檢查的錯誤都會被接住在這
      print("❌ [掃描錯誤] 藍牙啟動或狀態檢查失敗: $e");
    }
  }

  // ==========================================
  // 📷 UI 與掃碼邏輯
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final isRent = widget.actionType == 'rent';
    final title = isRent ? '掃碼租借新杯' : '掃碼歸還循環杯';
    final themeColor = isRent ? Colors.blueAccent : Colors.orangeAccent;

    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black45, 
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _cameraController,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                  case TorchState.auto:
                    return const Icon(Icons.flash_auto, color: Colors.white);
                  default: 
                    return const Icon(Icons.flash_off, color: Colors.grey);
                }
              },
            ),
            onPressed: () => _cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: themeColor, width: 4),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: themeColor),
                    const SizedBox(height: 20),
                    Text(
                      isRent ? '正在解鎖機台取杯口...' : '正在為您開啟回收閘門...',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String qrCodeData = barcodes.first.rawValue!; 

      setState(() {
        _isProcessing = true;
      });

      _cameraController.stop();

      try {
        final bool isRent = widget.actionType == 'rent';
        final String endpoint = isRent ? '/api/rent' : '/api/return';
        final Uri url = Uri.parse('http://10.245.39.41:8000$endpoint');

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': 1, 
            'machine_id': qrCodeData,
          }),
        );

        if (!mounted) return;

        if (response.statusCode == 200) {
          
          // ==========================================
          // 🌸 魔法發生的瞬間：如果是歸還，觸發花朵綻放！
          // ==========================================
          if (!isRent) {
            _triggerFlowerBloom(); 
          }
          
          _showSuccessDialog(qrCodeData);
        } else {
          String errorMsg = '發生未知錯誤';
          try {
            final errorData = json.decode(utf8.decode(response.bodyBytes));
            if (errorData['detail'] != null) {
              errorMsg = errorData['detail'];
            }
          } catch (_) {}
          
          _showErrorDialog(errorMsg);
        }
      } catch (e) {
        if (!mounted) return;
        _showErrorDialog('網路連線失敗，請確認後端是否啟動且在同一區網下。');
      } finally {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    }
  }

  void _showSuccessDialog(String machineId) {
    final isRent = widget.actionType == 'rent';
    
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Icon(
          Icons.check_circle,
          color: isRent ? Colors.blueAccent : Colors.orangeAccent,
          size: 64,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isRent ? '租借指令已送出！' : '歸還指令已送出！',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              isRent 
                  ? '已連線至機台\n請從下方取杯口拿出您的循環杯 🌱'
                  : '閘門已開啟\n請將循環杯投入，感謝您的行動 ♻️',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isRent ? Colors.blueAccent : Colors.orangeAccent,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(context).pop(); 
              Navigator.of(context).pop(); 
            },
            child: const Text('完成', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Icon(
          Icons.error_outline,
          color: Colors.redAccent,
          size: 64,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('無法完成操作', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(errorMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.redAccent)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(context).pop(); 
              _cameraController.start(); 
            },
            child: const Text('了解，重試', style: TextStyle(color: Colors.black87, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}