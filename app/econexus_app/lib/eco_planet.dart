import 'package:flutter/material.dart';
import 'dart:math' as math;

class EcoPlanet extends StatefulWidget {
  final int returnCount;

  const EcoPlanet({super.key, required this.returnCount});

  @override
  State<EcoPlanet> createState() => _EcoPlanetState();
}

class _EcoPlanetState extends State<EcoPlanet> with TickerProviderStateMixin {
  late AnimationController _spinController;
  late AnimationController _heartController;
  late Animation<double> _heartOpacity;
  late Animation<Offset> _heartSlide;

  @override
  void initState() {
    super.initState();
    // 地球自轉動畫 (預設 10 秒轉一圈，緩慢旋轉)
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // 愛心噴發動畫
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // 愛心的透明度：0 -> 1 -> 消失
    _heartOpacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_heartController);

    // 愛心的位移：從中間往上飄
    _heartSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: const Offset(0, -1.5))
        .animate(CurvedAnimation(parent: _heartController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(EcoPlanet oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 🌟 魔法觸發點：如果發現循環次數增加了！
    if (widget.returnCount > oldWidget.returnCount) {
      _triggerLevelUpAnimation();
    }
  }

  void _triggerLevelUpAnimation() {
    // 1. 噴發愛心
    _heartController.forward(from: 0);

    // 2. 地球加速轉一圈 (1秒內轉完)，然後恢復正常速度
    _spinController.duration = const Duration(seconds: 1);
    _spinController.forward(from: _spinController.value).then((_) {
      _spinController.duration = const Duration(seconds: 10);
      _spinController.repeat();
    });
  }

  @override
  void dispose() {
    _spinController.dispose();
    _heartController.dispose();
    super.dispose();
  }

  // 生成樹木的方法 (使用固定的隨機種子，確保樹長出來後不會亂跑)
  List<Widget> _buildTrees() {
    final math.Random random = math.Random(42); // 固定種子
    final int treeCount = math.min(widget.returnCount, 30); // 最多畫 30 棵樹
    List<Widget> trees = [];

    for (int i = 0; i < treeCount; i++) {
      // 隨機產生樹木在地球上的位置 (-60 到 60 之間，配合地球半徑)
      final double dx = (random.nextDouble() * 120) - 60;
      final double dy = (random.nextDouble() * 120) - 60;
      
      trees.add(
        Transform.translate(
          offset: Offset(dx, dy),
          child: const Icon(Icons.park, color: Colors.green, size: 24),
        ),
      );
    }
    return trees;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 旋轉的地球與樹木
          RotationTransition(
            turns: _spinController,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 海洋背景與陸地漸層
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.lightBlueAccent.shade100, Colors.blue.shade700],
                      center: const Alignment(-0.3, -0.5),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 20, spreadRadius: 5),
                    ],
                  ),
                ),
                // 雲朵/陸地裝飾 (使用 Icon 營造感覺)
                Icon(Icons.public, color: Colors.white.withOpacity(0.3), size: 140),
                // 動態生長的樹木
                ..._buildTrees(),
              ],
            ),
          ),

          // 飄浮的愛心 (獨立於旋轉之外，永遠直直往上飄)
          SlideTransition(
            position: _heartSlide,
            child: FadeTransition(
              opacity: _heartOpacity,
              child: const Icon(
                Icons.favorite,
                color: Colors.redAccent,
                size: 50,
              ),
            ),
          ),
        ],
      ),
    );
  }
}