import json
import paho.mqtt.client as mqtt
from sqlmodel import Session, create_engine
from main import User, Machine, TransactionLog, sqlite_url
from datetime import datetime

# 建立與 SQLite 資料庫的連線
engine = create_engine(sqlite_url)

# ==========================================
# ⚙️ 系統設定
# ==========================================
MQTT_BROKER = "10.245.39.41" # 🚨 請確認這裡是你筆電的 IP
MQTT_PORT = 1883

# 新的主題規劃
TOPIC_STATUS = "sdg12/machine/status"
TOPIC_EVENT = "sdg12/machine/event"   # 把舊的 sold 改成 event，更符合借/還邏輯

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("✅ 成功連線至 MQTT 伺服器")
        client.subscribe(TOPIC_STATUS)
        client.subscribe(TOPIC_EVENT)
        print(f"🎧 正在監聽頻道: {TOPIC_STATUS} 與 {TOPIC_EVENT}")
    else:
        print(f"❌ 連線失敗，狀態碼: {rc}")

def on_message(client, userdata, msg):
    payload = msg.payload.decode("utf-8")
    topic = msg.topic
    
    try:
        data = json.loads(payload)
        
        # ==========================================
        # 1. 處理機台心跳 (更新最後看見時間)
        # ==========================================
        if topic == TOPIC_STATUS:
            machine_id = data.get("machine_id")
            if machine_id:
                with Session(engine) as session:
                    machine = session.get(Machine, machine_id)
                    if machine:
                        machine.last_seen = datetime.now()
                        session.add(machine)
                        session.commit()
                        print(f"💓 收到機台 {machine_id} 的心跳！更新連線時間。")
                        
        # ==========================================
        # 2. 處理硬體回報的「動作成功」事件
        # ==========================================
        elif topic == TOPIC_EVENT:
            tx_id = data.get("transaction_id")
            if tx_id:
                with Session(engine) as session:
                    # 撈出這筆交易
                    tx = session.get(TransactionLog, tx_id)
                    
                    if tx and tx.status == "pending":
                        # 將交易標記為成功
                        tx.status = "success"
                        session.add(tx)
                        
                        user = session.get(User, tx.user_id)
                        machine = session.get(Machine, tx.machine_id)
                        
                        # 🟢 如果是「歸還」成功：解除租借狀態、+10點數、機台回收倉變滿
                        if tx.action == "return" and user and machine:
                            user.is_renting = False
                            user.returned_count += 1
                            user.points += 10
                            machine.used_cups += 1
                            session.add(user)
                            session.add(machine)
                            print(f"♻️  [結算] 歸還完成！使用者獲得 10 點。回收倉目前數量: {machine.used_cups}/{machine.max_capacity}")
                            
                        # 🔵 如果是「租借」成功：其實在 APP 請求時已經預扣了，這裡只需印出 Log
                        elif tx.action == "rent":
                            print(f"🌱 [結算] 租借成功！機台閘門已關閉。")
                            
                        session.commit()
                        
    except Exception as e:
        print(f"❌ 訊號處理錯誤: {e}")

# 初始化 MQTT 客戶端 (加入 VERSION1 避免黃字警告)
client = mqtt.Client(mqtt.CallbackAPIVersion.VERSION1)
client.on_connect = on_connect
client.on_message = on_message

try:
    print("啟動 MQTT 監聽器中...")
    client.connect(MQTT_BROKER, MQTT_PORT, 60)
    client.loop_forever() 
except ConnectionRefusedError:
    print("❌ 無法連線！請確認您的電腦有沒有安裝並啟動 Mosquitto 伺服器。")
except KeyboardInterrupt:
    print("\n⏹️ 監聽器已手動停止。")