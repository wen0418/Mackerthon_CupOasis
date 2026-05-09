# SDG 12 責任消費與生產 - 智慧剩食管理系統

![Python](https://img.shields.io/badge/Python-3.10+-blue.svg)
![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-green.svg)
![Streamlit](https://img.shields.io/badge/Streamlit-1.20+-red.svg)
![MQTT](https://img.shields.io/badge/MQTT-Mosquitto-orange.svg)

本專案為 2026 技術黑客松 (Technology Hackathon) 參賽作品。旨在透過 IoT 物聯網技術與後端自動化邏輯，解決通路剩食問題，實踐 **SDG 12：負責任的消費與生產**。

---

## 🚀 系統核心價值
本系統針對零售通路、自動販賣機之「過期食品浪費」問題，提出以下解決方案：
1. **動態折價機制**：系統自動偵測商品到期時間，於到期前 2 小時自動調降價格（5 折），透過價格誘因減少剩食。
2. **軟硬整合監測**：結合 ESP32 硬體與 MQTT 協定，實現即時庫存扣除與設備狀態監控。
3. **數據驅動決策**：提供管理員後台，即時顯示各機台銷售 KPI、剩食減量成果與地理位置分佈。

---

## 🛠️ 技術棧 (Tech Stack)
- **Language**: Python 3.10+
- **Backend**: FastAPI (High-performance API framework)
- **Frontend/Admin**: Streamlit (Data-driven dashboard)
- **Database**: SQLModel + SQLite (Lightweight & efficient ORM)
- **IoT Communication**: MQTT (Paho-MQTT) + Mosquitto Broker
- **Visualization**: Plotly, Folium (Maps)

---

## 📂 專案結構
```text
├── main.py              # FastAPI 主程式 (API & 自動折價邏輯)
├── admin.py             # Streamlit 管理後台 (視覺化儀表板)
├── mqtt_listener.py     # MQTT 訊息監聽器 (處理硬體端訊號)
├── database.db          # SQLite 資料庫檔案
├── test_data.csv        # 測試用商品資料 (支援後台一鍵匯入)
├── requirements.txt     # 相依套件清單
├── test_esp32.py        # 硬體模擬器 (用於 Demo 備案)
└── README.md            # 專案說明文件
```

---

## ⚙️ 安裝與啟動教學

### 1. 環境準備
建議使用虛擬環境 (Conda 或 venv)：
```bash
conda create -n sdg12 python=3.10
conda activate sdg12
```

### 2. 安裝套件
```bash
pip install -r requirements.txt
```

### 3. 啟動系統 (建議分 4 個終端機視窗執行)
請確保您的電腦已啟動 **Mosquitto MQTT Broker**。

1.  **啟動 API 伺服器：**
    ```bash
    uvicorn main:app --reload
    ```
2.  **啟動管理後台：**
    ```bash
    streamlit run admin.py
    ```
3.  **啟動 MQTT 監聽器：**
    ```bash
    python mqtt_listener.py
    ```
4.  **啟動測試模擬器 (可選)：**
    ```bash
    python test_esp32.py
    ```

---

## 📊 Demo 流程建議
1. **資料匯入**：進入 Streamlit 後台，上傳 `test_data.csv`。
2. **觀察折價**：檢查 API 或後台列表，確認接近到期之商品已自動標註為「5折」。
3. **模擬購買**：運行 `test_esp32.py` 或操作實體機台，觀察庫存即時減少。
4. **數據追蹤**：查看圖表與地圖，分析該機台之銷售狀況與節省的食物價值。

---

## 👥 開發團隊
- **Jerry** (Back-end / IoT Integration)
- 以及其他團隊成員...

---
*本專案僅供 2026 技術黑客松競賽展示使用。*
