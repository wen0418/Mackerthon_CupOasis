import streamlit as st
import pandas as pd
import folium
import plotly.express as px
from streamlit_folium import st_folium
from sqlmodel import Session, create_engine, select
from main import Product, sqlite_url, MachineStatus
from datetime import datetime, time

st.set_page_config(page_title="SDG12 責任消費 ERP 系統", page_icon="🌱", layout="wide")

hide_st_style = """
            <style>
            #MainMenu {visibility: hidden;}
            footer {visibility: hidden;}
            header {visibility: hidden;}
            </style>
            """
st.markdown(hide_st_style, unsafe_allow_html=True)

engine = create_engine(sqlite_url)

with st.sidebar:
    st.title("🌱 SDG12 管理系統")
    st.markdown("---")
    st.write("👤 使用者: Admin (最高權限)")
    st.write(f"📅 系統時間: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    st.markdown("---")
    st.info("💡 提示：本系統會自動偵測商品到期時間，並即時更新前端 APP 售價。")
    st.markdown("---")
    st.write("### ⚙️ 系統操作")
    if st.button("🔄 手動更新 (同步最新資料)", type="primary", use_container_width=True):
        st.toast("✅ 已成功從資料庫同步最新狀態！", icon="🔄")
        st.rerun()

st.title("📊 管理後台")

@st.cache_data(ttl=5)
def load_data():
    try:
        return pd.read_sql_query("SELECT * FROM product", engine)
    except Exception:
        return pd.DataFrame()

df_db = load_data()

tab1, tab2, tab3, tab4 = st.tabs(["📈 即時監控", "📋 庫存管理", "🛠️ 手動編輯 (CRUD)", "⚙️ 系統初始化"])

# ==========================================
# 頁籤 1：即時監控
# ==========================================
with tab1:
    if not df_db.empty:
        col1, col2, col3, col4 = st.columns(4)
        total_items = len(df_db)
        discounted_items = df_db[df_db['is_discounted'] == 1].shape[0]
        normal_items = total_items - discounted_items
        saved_value = df_db[df_db['is_discounted'] == 1]['original_price'].sum()

        col1.metric("📦 總庫存件數", f"{total_items} 件")
        col2.metric("🟢 正常售價商品", f"{normal_items} 件")
        col3.metric("🔴 啟動友善時光 (五折)", f"{discounted_items} 件", delta="-50% 售價", delta_color="inverse")
        col4.metric("💰 潛在拯救剩食價值", f"NT$ {saved_value:.0f}")

        st.markdown("---")
        st.subheader("📍 實體機台與模擬網點即時監控")
        
        m001_df = df_db[df_db['machine_id'] == 'M001']
        m001_discount_count = len(m001_df[m001_df['is_discounted'] == 1])

        is_online = False
        last_seen_str = "從未連線"
        with Session(engine) as session:
            status_record = session.get(MachineStatus, "M001")
            if status_record:
                time_diff = (datetime.now() - status_record.last_seen).total_seconds()
                if time_diff <= 30:
                    is_online = True
                last_seen_str = status_record.last_seen.strftime("%H:%M:%S")

        status_color = "green" if is_online else "red"
        status_text = "🟢 即時連線中" if is_online else "🔴 設備已離線"
        marker_color = "red" if is_online else "gray"

        real_machine = {
            "name": "M001 實體展示機", "lat": 25.0365, "lng": 121.4320, "type": "真實硬體連線", 
            "inventory": m001_discount_count, "color": marker_color, "icon": "star",
            "status_text": status_text, "status_color": status_color, "last_seen": last_seen_str
        }
        
        simulated_machines = [
            {"name": "M002 台北車站網點", "lat": 25.0479, "lng": 121.5173, "type": "雲端模擬網點", "inventory": 15, "color": "blue", "icon": "info-sign"},
            {"name": "M003 信義商圈網點", "lat": 25.0339, "lng": 121.5644, "type": "雲端模擬網點", "inventory": 8, "color": "blue", "icon": "info-sign"}
        ]

        m = folium.Map(location=[25.0365, 121.4320], zoom_start=12)
        for loc in [real_machine] + simulated_machines:
            if loc["type"] == "真實硬體連線":
                popup_html = f"<div style='width: 230px; border: 2px solid {loc['status_color']}; padding: 10px; border-radius: 8px;'><h4 style='color: #333; margin: 0 0 5px 0;'>📍 {loc['name']}</h4><b style='color: {loc['status_color']};'>{loc['status_text']}</b><br><span style='font-size: 12px; color: gray;'>最後通訊: {loc['last_seen']}</span><br><b style='color: #333;'>友善時光剩餘：<span style='font-size: 20px; color: red;'>{loc['inventory']}</span> 份</b></div>"
            else:
                popup_html = f"<div style='width: 180px;'><h5 style='margin: 0 0 5px 0;'>{loc['name']}</h5><span style='color: gray;'>狀態：{loc['type']}</span><br><b>模擬庫存：{loc['inventory']} 份</b></div>"
                
            folium.Marker(location=[loc["lat"], loc["lng"]], popup=folium.Popup(popup_html, max_width=300), icon=folium.Icon(color=loc["color"], icon=loc["icon"])).add_to(m)

        st_folium(m, width=1200, height=450, returned_objects=[])
    else:
        st.warning("⚠️ 系統中沒有庫存資料。")

# ==========================================
# 頁籤 2：庫存管理
# ==========================================
with tab2:
    if not df_db.empty:
        display_df = df_db.copy()
        display_df['is_discounted'] = display_df['is_discounted'].apply(lambda x: '✅ 是' if x else '❌ 否')
        st.dataframe(display_df, use_container_width=True)

# ==========================================
# 🌟 頁籤 3：手動編輯 (新增種類欄位)
# ==========================================
with tab3:
    manage_action = st.radio("請選擇操作模式", ["➕ 新增單筆商品", "✏️ 編輯或刪除現有商品"], horizontal=True)
    
    if manage_action == "➕ 新增單筆商品":
        with st.form("add_product_form"):
            col1, col2, col_cat = st.columns(3)
            new_machine = col1.text_input("機台編號 (例如: M001)")
            new_name = col2.text_input("商品名稱")
            new_category = col_cat.selectbox("種類", ["超商", "學餐", "其他"]) # 🌟 新增選項
            
            col3, col4 = st.columns(2)
            new_orig_price = col3.number_input("原價", min_value=0, value=50)
            new_curr_price = col4.number_input("目前售價", min_value=0, value=50)
            
            col5, col6 = st.columns(2)
            new_date = col5.date_input("到期日期")
            new_time = col6.time_input("到期時間", value=time(17, 0))
            new_discounted = st.checkbox("直接標記為打折")
            
            if st.form_submit_button("🚀 確認新增商品", type="primary"):
                with Session(engine) as session:
                    p = Product(machine_id=new_machine, name=new_name, category=new_category, original_price=new_orig_price, current_price=new_curr_price, expiry_time=datetime.combine(new_date, new_time), is_discounted=new_discounted)
                    session.add(p)
                    session.commit()
                st.success("✅ 新增成功！")
                st.rerun()

    elif manage_action == "✏️ 編輯或刪除現有商品":
        with Session(engine) as session:
            all_products = session.exec(select(Product)).all()
        if all_products:
            options = {f"[{p.machine_id}] {p.name}": p for p in all_products}
            target_p = options[st.selectbox("🔍 選擇要修改的商品", list(options.keys()))]
            
            with st.form("edit_product_form"):
                col1, col2, col_cat = st.columns(3)
                edit_machine = col1.text_input("機台編號", value=target_p.machine_id)
                edit_name = col2.text_input("商品名稱", value=target_p.name)
                # 預設選中資料庫中的種類
                cat_index = ["超商", "學餐", "其他"].index(target_p.category) if target_p.category in ["超商", "學餐", "其他"] else 0
                edit_category = col_cat.selectbox("種類", ["超商", "學餐", "其他"], index=cat_index)
                
                col3, col4 = st.columns(2)
                edit_orig_price = col3.number_input("原價", value=float(target_p.original_price))
                edit_curr_price = col4.number_input("目前售價", value=float(target_p.current_price))
                
                col5, col6 = st.columns(2)
                edit_date = col5.date_input("日期", value=target_p.expiry_time.date())
                edit_time = col6.time_input("時間", value=target_p.expiry_time.time())
                edit_discounted = st.checkbox("標記為打折", value=target_p.is_discounted)
                
                if st.form_submit_button("💾 儲存修改", type="primary"):
                    with Session(engine) as session:
                        db_p = session.get(Product, target_p.id)
                        db_p.machine_id, db_p.name, db_p.category = edit_machine, edit_name, edit_category
                        db_p.original_price, db_p.current_price = edit_orig_price, edit_curr_price
                        db_p.expiry_time = datetime.combine(edit_date, edit_time)
                        db_p.is_discounted = edit_discounted
                        session.add(db_p)
                        session.commit()
                    st.rerun()
            
            if st.button("🗑️ 強制下架 (刪除此商品)"):
                with Session(engine) as session:
                    session.delete(session.get(Product, target_p.id))
                    session.commit()
                st.rerun()

# ==========================================
# 頁籤 4：系統初始化 (CSV 匯入支援 category)
# ==========================================
with tab4:
    st.subheader("📥 批次匯入測試資料 (CSV)")
    uploaded_file = st.file_uploader("選擇檔案", type="csv")
    if uploaded_file is not None:
        if st.button("🚀 執行資料匯入", type="primary"):
            df = pd.read_csv(uploaded_file)
            with Session(engine) as session:
                for _, row in df.iterrows():
                    new_product = Product(
                        machine_id=row['machine_id'],
                        name=row['name'],
                        category=row.get('category', '超商'), # 🌟 如果 CSV 沒提供種類，預設為超商
                        original_price=row['original_price'],
                        current_price=row['original_price'],
                        expiry_time=pd.to_datetime(row['expiry_time'])
                    )
                    session.add(new_product)
                session.commit()
            st.success("✅ 資料匯入成功！")
            st.rerun()