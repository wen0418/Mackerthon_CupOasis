import json
import paho.mqtt.publish as publish
from typing import Optional, List
from fastapi import FastAPI, Depends, HTTPException
from sqlmodel import Field, Session, SQLModel, create_engine, select
from datetime import datetime
from pydantic import BaseModel

# ==========================================
# ⚙️ 系統與 MQTT 設定
# ==========================================
# 🚨 填入你目前的筆電 IP
MQTT_BROKER = "172.26.43.41" 
MQTT_PORT = 1883

sqlite_file_name = "database.db"
sqlite_url = f"sqlite:///{sqlite_file_name}"
engine = create_engine(sqlite_url, echo=False)

app = FastAPI(title="SDG 12 循環杯系統 API")

# ==========================================
# 📊 資料庫模型 (SQLModel)
# ==========================================
class User(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str = Field(default="環保小尖兵")
    points: int = Field(default=0)           # 累積點數
    returned_count: int = Field(default=0)   # 成功循環次數
    is_renting: bool = Field(default=False)  # 防呆：是否已經借了杯子還沒還？

class Machine(SQLModel, table=True):
    machine_id: str = Field(primary_key=True)
    name: str
    lat: float
    lon: float
    last_seen: datetime = Field(default_factory=datetime.now)
    clean_cups: int = Field(default=20)   # 剩餘可借的乾淨杯子
    used_cups: int = Field(default=0)     # 回收倉已滿程度
    max_capacity: int = Field(default=50) # 回收倉最大容量

class TransactionLog(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int
    machine_id: str
    action: str          # "rent" 或 "return"
    status: str          # "pending" (處理中), "success" (成功)
    timestamp: datetime = Field(default_factory=datetime.now)

# ==========================================
# 🚀 系統初始化 (產生測試資料)
# ==========================================
def get_session():
    with Session(engine) as session:
        yield session

@app.on_event("startup")
def on_startup():
    SQLModel.metadata.create_all(engine)
    
    # 建立預設資料，方便 Hackathon 直接 Demo
    with Session(engine) as session:
        # 1. 建立測試使用者 (如果沒有的話)
        if not session.get(User, 1):
            session.add(User(id=1, name="Demo User", points=150, returned_count=12))
            
        # 2. 建立地圖上的三台機台
        default_machines = [
            {"id": "M001", "name": "M001 實體展示機", "lat": 25.0365, "lon": 121.4320, "clean": 15},
            {"id": "M002", "name": "M002 台北車站網點", "lat": 25.0479, "lon": 121.5173, "clean": 5},
            {"id": "M003", "name": "M003 信義商圈網點", "lat": 25.0339, "lon": 121.5644, "clean": 0}
        ]
        for m in default_machines:
            if not session.get(Machine, m["id"]):
                session.add(Machine(
                    machine_id=m["id"], name=m["name"], lat=m["lat"], lon=m["lon"], clean_cups=m["clean"]
                ))
        session.commit()

# ==========================================
# 📡 MQTT 發送小幫手
# ==========================================
def send_mqtt_command(machine_id: str, action: str, tx_type: str, tx_id: int):
    """將開門指令打給指定的 MQTT Topic"""
    topic = f"sdg12/machine/{machine_id}/command"
    payload = json.dumps({"action": action, "type": tx_type, "transaction_id": tx_id})
    try:
        # 使用 publish.single 可以快速發送單一訊息，非常適合 API 端點使用
        publish.single(topic, payload=payload, hostname=MQTT_BROKER, port=MQTT_PORT)
        print(f"📤 [MQTT 發送成功] Topic: {topic} | Payload: {payload}")
    except Exception as e:
        print(f"❌ [MQTT 發送失敗] 請檢查 Broker 是否開啟: {e}")

# ==========================================
# 🌐 API 端點 (給 APP 呼叫)
# ==========================================

# 1. 取得地圖機台清單
@app.get("/api/machines")
def get_machines(session: Session = Depends(get_session)):
    machines = session.exec(select(Machine)).all()
    now = datetime.now()
    result = []
    
    for m in machines:
        # 判斷是否連線 (30秒內有心跳算連線)
        is_online = (now - m.last_seen).total_seconds() <= 30
        
        result.append({
            "id": m.machine_id,
            "name": m.name,
            "lat": m.lat,
            "lng": m.lon,
            "inventory": m.clean_cups,  # APP 顯示剩餘杯子數
            "status": "online" if is_online else "offline"
        })
    return result

# 定義 Request 格式
class ActionRequest(BaseModel):
    user_id: int
    machine_id: str

# 2. 🌟 核心 API：掃碼租借
@app.post("/api/rent")
def rent_cup(req: ActionRequest, session: Session = Depends(get_session)):
    # 檢查機台狀態
    machine = session.get(Machine, req.machine_id)
    if not machine:
        raise HTTPException(status_code=404, detail="找不到此機台")
    if machine.clean_cups <= 0:
        raise HTTPException(status_code=400, detail="機台內已無可用循環杯")

    # 檢查使用者狀態
    user = session.get(User, req.user_id)
    if user.is_renting:
        raise HTTPException(status_code=400, detail="您還有未歸還的循環杯，請先歸還！")

    # 建立一筆「處理中」的交易紀錄
    tx = TransactionLog(user_id=req.user_id, machine_id=req.machine_id, action="rent", status="pending")
    session.add(tx)
    
    # 防呆：先標記使用者已租借，扣除機台庫存 (預扣)
    user.is_renting = True
    machine.clean_cups -= 1
    session.commit()
    session.refresh(tx)

    # 🚀 呼叫 MQTT，通知實體機台開門吐杯子！
    send_mqtt_command(machine_id=req.machine_id, action="open", tx_type="rent", tx_id=tx.id)

    return {"message": "租借指令已發送至機台，等待開啟中", "transaction_id": tx.id}

# 3. 🌟 核心 API：掃碼歸還
@app.post("/api/return")
def return_cup(req: ActionRequest, session: Session = Depends(get_session)):
    # 檢查機台容量
    machine = session.get(Machine, req.machine_id)
    if machine.used_cups >= machine.max_capacity:
        raise HTTPException(status_code=400, detail="此機台回收倉已滿，請尋找其他機台")

    # 檢查使用者
    user = session.get(User, req.user_id)
    if not user.is_renting:
        raise HTTPException(status_code=400, detail="您目前沒有租借中的循環杯喔！")

    # 建立交易紀錄
    tx = TransactionLog(user_id=req.user_id, machine_id=req.machine_id, action="return", status="pending")
    session.add(tx)
    session.commit()
    session.refresh(tx)

    # 🚀 呼叫 MQTT，通知實體機台打開回收閘門！
    send_mqtt_command(machine_id=req.machine_id, action="open", tx_type="return", tx_id=tx.id)

    return {"message": "回收指令已發送，請將杯子投入閘門", "transaction_id": tx.id}

# 4. 取得使用者儀表板狀態 (供 APP 首頁使用)
@app.get("/api/user/{user_id}")
def get_user_dashboard(user_id: int, session: Session = Depends(get_session)):
    user = session.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="找不到使用者")
    return {
        "name": user.name,
        "points": user.points,
        "returned_count": user.returned_count,
        "is_renting": user.is_renting
    }