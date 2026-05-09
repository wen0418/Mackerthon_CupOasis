import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class QRScanPage extends StatefulWidget {
  final String actionType; // 傳入 'rent' (租借) 或 'return' (歸還)

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
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
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

  // 🌟 核心修改：當相機偵測到 QR Code 時觸發 API
  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String qrCodeData = barcodes.first.rawValue!; // 掃到的機台 ID，例如 "M001"

      setState(() {
        _isProcessing = true;
      });

      // 暫停相機，避免重複掃描
      _cameraController.stop();

      try {
        // 🚨 這裡直接使用你目前的筆電 IP (手機熱點環境)
        final String endpoint = widget.actionType == 'rent' ? '/api/rent' : '/api/return';
        final Uri url = Uri.parse('http://10.245.39.41:8000$endpoint');

        // 發送 POST 請求給 FastAPI 大腦
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': 1, // Demo 階段先寫死預設使用者 ID 為 1
            'machine_id': qrCodeData,
          }),
        );

        if (!mounted) return;

        // 判斷後端回傳的狀態碼
        if (response.statusCode == 200) {
          // 成功！大腦已經同意並通知樹莓派開門了
          _showSuccessDialog(qrCodeData);
        } else {
          // 失敗！(例如：機台沒杯子、防呆機制擋下)
          // 嘗試解析後端傳來的錯誤訊息 (detail)
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
        // 如果對話框被關掉且沒有離開頁面，將狀態重置
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    }
  }

  // ✅ 成功畫面
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
              Navigator.of(context).pop(); // 關閉 Dialog
              Navigator.of(context).pop(); // 返回 HomePage
            },
            child: const Text('完成', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // ❌ 錯誤畫面 (被後端擋下時觸發)
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
            const Text(
              '無法完成操作',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.redAccent),
            ),
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
              Navigator.of(context).pop(); // 關閉 Dialog
              _cameraController.start(); // 重新啟動相機，讓使用者可以再次掃描
            },
            child: const Text('了解，重試', style: TextStyle(color: Colors.black87, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}