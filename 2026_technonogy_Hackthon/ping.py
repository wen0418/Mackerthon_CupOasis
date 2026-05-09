import paho.mqtt.publish as publish
import json

# 發送心跳包
payload = json.dumps({"machine_id": "M001", "status": "online"})
publish.single("sdg12/machine/status", payload, hostname="127.0.0.1")
print("💓 心跳已發送！")