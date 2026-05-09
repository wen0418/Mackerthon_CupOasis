import paho.mqtt.publish as publish
import json

# 1. 模擬 ESP32 準備送出的資料 (有人買了 ID 為 2 的雞肉沙拉)
fake_hardware_signal = {
    "product_id": 2
}

# 2. 將字典轉成 JSON 字串
payload = json.dumps(fake_hardware_signal)

print("🔌 模擬 ESP32 觸發：馬達轉動，商品掉落...")
# 3. 發送 MQTT 訊號到你的本機伺服器
publish.single("sdg12/machine/sold", payload, hostname="127.0.0.1")
print("✅ 購買訊號已發送給後端！")