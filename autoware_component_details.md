# Autoware コンポーネント詳細解説

## 1. Sensing（センシング）コンポーネント

### 概要
車両周辺環境の情報を取得し、後段の処理に適した形でデータを前処理するコンポーネント

### 主要モジュール
- **Point Cloud Preprocessor**: LiDAR点群の前処理（ノイズ除去、ダウンサンプリング）
- **Image Transport Decompressor**: 圧縮画像の展開
- **IMU Corrector**: IMUデータの補正・キャリブレーション
- **Radar Processors**: レーダーデータの変換・フィルタリング

### 担当機能
- センサー生データの取得
- データの同期・タイムスタンプ調整
- ノイズ除去・外れ値検出
- 座標系変換

---

## 2. Perception（認識）コンポーネント

### 概要
センサーデータから環境の意味的な理解を行い、周囲の物体や道路状況を認識

### 主要モジュール
- **LiDAR Object Detection**: 
  - CenterPoint（3D物体検出）
  - Apollo Instance Segmentation
- **Camera Recognition**:
  - YOLOX（2D物体検出）
  - Traffic Light Recognition
- **Multi-Object Tracker**: 物体追跡・ID管理
- **Prediction**: 他車両・歩行者の動作予測
- **Occupancy Grid Map**: 占有格子地図生成

### 主要アルゴリズム
- **物体検出**: PointPillars, CenterPoint, YOLOX
- **追跡**: カルマンフィルタ, Hungarian Algorithm
- **予測**: Constant Velocity Model, Map-based Prediction

---

## 3. Localization（自己位置推定）コンポーネント

### 概要
高精度地図と各種センサーを用いて、センチメートル級の自車位置・姿勢を推定

### 主要モジュール
- **NDT Scan Matcher**: 点群マッチングによる位置推定
- **EKF Localizer**: 拡張カルマンフィルタによるセンサー融合
- **GNSS Poser**: GNSS位置情報の処理
- **Pose Initializer**: 初期位置の設定

### 主要アルゴリズム
- **NDT（Normal Distributions Transform）**: 点群マッチング
- **拡張カルマンフィルタ**: 複数センサーの融合
- **粒子フィルタ**: 非線形推定（YabLoc）

---

## 4. Planning（経路計画）コンポーネント

### 概要
目的地まで安全で効率的な経路・軌道を生成する階層的な計画システム

### 階層構造
1. **Mission Planning**: 大局的経路計画
2. **Behavior Planning**: 行動レベル計画
3. **Motion Planning**: 詳細軌道計画

### 主要モジュール
- **Behavior Path Planner**: 
  - Lane Following, Lane Change
  - Static/Dynamic Obstacle Avoidance
  - Goal/Start Planner
- **Behavior Velocity Planner**: 
  - Traffic Light, Crosswalk
  - Intersection, Stop Line
- **Motion Velocity Planner**: 障害物回避速度調整
- **Path Optimizer**: 経路最適化
- **Sampling-based Planner**: Frenet座標系軌道生成

### 主要アルゴリズム
- **A* / Hybrid A***: グラフ探索
- **RRT* / Informed RRT***: サンプリングベース
- **Model Predictive Path Integral (MPPI)**: 確率的最適制御
- **Constant Jerk Profile**: 滑らかな軌道生成

---

## 5. Control（制御）コンポーネント

### 概要
計画された軌道を正確に追従し、車両を安全に制御

### 主要モジュール
- **MPC Lateral Controller**: Model Predictive Controlによる操舵制御
- **PID Longitudinal Controller**: 速度制御
- **Pure Pursuit**: 簡易操舵制御
- **Vehicle Command Gate**: 制御コマンドの安全性チェック
- **Autonomous Emergency Braking**: 緊急ブレーキ

### 制御手法
- **MPC**: 予測制御による最適操舵
- **PID制御**: 速度・加減速制御
- **フィードフォワード制御**: 操舵角予測

---

## 6. Map（地図）コンポーネント

### 概要
高精度地図データの読み込み・管理・提供

### 主要モジュール
- **Map Loader**: Lanelet2形式地図の読み込み
- **Point Cloud Map Loader**: PCD点群地図の管理
- **Map Height Fitter**: 地図の高さ情報調整
- **Map TF Generator**: 地図座標系の設定

### 地図形式
- **Lanelet2**: 道路ネットワークのベクトル地図
- **PCD (Point Cloud Data)**: LiDAR点群地図
- **OSM (OpenStreetMap)**: オープンな地図形式

---

## 7. System（システム）コンポーネント

### 概要
システム全体の監視・診断・安全性確保を行う

### 主要モジュール
- **Diagnostic Monitor**: システム診断・ヘルスチェック
- **MRM Handler**: Minimum Risk Maneuver（最小リスク操作）
- **Component Monitor**: ノード状態監視
- **Emergency Stop Operator**: 緊急停止制御

### 安全機能
- **故障検知**: ハードウェア・ソフトウェア監視
- **フェイルセーフ**: 安全な状態への遷移
- **冗長性**: 重要機能のバックアップ

---

## 8. API/Interface

### 概要
外部システムとの連携・可視化・リモート操作インターフェース

### 主要モジュール
- **AD API (Autonomous Driving API)**: 標準化されたインターフェース
- **RViz Plugins**: 可視化プラグイン
- **Web Server**: リモートモニタリング
- **Component Interface**: モジュール間通信

### インターフェース種類
- **REST API**: HTTP/JSONベースの外部連携
- **ROS Topics/Services**: 内部モジュール間通信
- **Visualization**: RViz, PlotJuggler等による可視化

---

## コンポーネント間の相互作用

```mermaid
sequenceDiagram
    participant S as Sensing
    participant P as Perception
    participant L as Localization
    participant Pl as Planning
    participant C as Control
    participant M as Map
    participant Sys as System

    S->>P: センサーデータ
    S->>L: 点群・IMU・GNSS
    M->>L: 地図データ
    M->>Pl: 道路情報
    P->>Pl: 物体情報
    L->>Pl: 自車位置
    Pl->>C: 目標軌道
    C->>Sys: 制御状態
    Sys->>C: 安全監視
```

このアーキテクチャにより、Autowareは複雑な自動運転タスクを安全かつ効率的に実行できます。

---

## 反射動作と熟考動作の実装詳細

各コンポーネントは、**反射動作（Reflexive Actions）**と**熟考動作（Deliberative Actions）**を適切に組み合わせることで、安全性と効率性を両立しています。

### 🚨 反射動作を実装するコンポーネント

#### 1. Control - AEB（緊急ブレーキ）
```mermaid
flowchart TD
    SENSOR_INPUT[🔍 センサー入力<br/>点群・物体データ] --> PATH_PRED[📈 予測経路生成<br/>IMU/MPC]
    PATH_PRED --> OBSTACLE_DETECT[🎯 障害物検出<br/>1-5ms]
    OBSTACLE_DETECT --> RSS_CALC[⚡ RSS距離計算<br/>< 1ms]
    RSS_CALC --> COLLISION_CHECK{💥 衝突危険?}
    COLLISION_CHECK -->|Yes| EMERGENCY_BRAKE[🚨 緊急ブレーキ<br/>即座実行]
    COLLISION_CHECK -->|No| CONTINUE[✅ 監視継続]
    
    subgraph "RSS計算式"
        RSS_FORMULA["d = v_ego×t_response + v_ego²/(2×a_min)<br/>- sign(v_obj)×v_obj²/(2×a_obj_min) + offset"]
    end
    
    classDef reflex fill:#ffcccc,stroke:#ff0000,stroke-width:3px
    class EMERGENCY_BRAKE reflex
```

**特徴**:
- **応答時間**: 1-10ms
- **判断基準**: 物理法則に基づく確定的計算
- **実行**: ハードウェア割り込みレベル

#### 2. System - MRM（最小リスク操作）
```mermaid
flowchart TD
    SYSTEM_FAILURE[⚠️ システム故障検知] --> FAILURE_ASSESS[📊 故障評価<br/>10ms]
    FAILURE_ASSESS --> MRM_SELECT{🎯 MRM選択}
    
    MRM_SELECT -->|軽微| COMFORTABLE[😌 快適停止<br/>Comfortable Stop]
    MRM_SELECT -->|重大| EMERGENCY_STOP[🛑 緊急停止<br/>Emergency Stop]
    MRM_SELECT -->|可能| PULLOVER[🚗 路肩退避<br/>Pull Over]
    
    COMFORTABLE --> GRADUAL[📉 段階的減速<br/>3-5秒]
    EMERGENCY_STOP --> IMMEDIATE[⚡ 即座停止<br/>< 1秒]
    PULLOVER --> SAFE_MOVE[🏁 安全地点移動<br/>5-10秒]
    
    GRADUAL --> COMPLETE[✅ MRM完了]
    IMMEDIATE --> COMPLETE
    SAFE_MOVE --> COMPLETE
    
    classDef reflex fill:#ffcccc,stroke:#ff0000,stroke-width:3px
    class EMERGENCY_STOP,IMMEDIATE reflex
```

**特徴**:
- **応答時間**: 10-100ms
- **判断基準**: 故障の種類と重要度
- **実行**: 事前定義されたシナリオベース

#### 3. Control - Vehicle Command Gate
```mermaid
flowchart TD
    CONTROL_CMD[🎮 制御コマンド] --> GATE_INPUT[🚪 ゲート入力]
    GATE_INPUT --> SAFETY_CHECK{🛡️ 安全チェック<br/>< 1ms}
    
    SAFETY_CHECK -->|正常| NORMAL_OUTPUT[✅ 通常出力]
    SAFETY_CHECK -->|異常| LIMIT_APPLY[⚡ 制限適用]
    
    subgraph "制限チェック項目"
        VEL_CHECK[🏃 速度制限]
        ACC_CHECK[📈 加速度制限]
        JERK_CHECK[📊 ジャーク制限]
        LAT_CHECK[🔄 横加速度制限]
    end
    
    SAFETY_CHECK --> VEL_CHECK
    SAFETY_CHECK --> ACC_CHECK
    SAFETY_CHECK --> JERK_CHECK
    SAFETY_CHECK --> LAT_CHECK
    
    LIMIT_APPLY --> VEHICLE_OUT[🚙 車両へ出力]
    NORMAL_OUTPUT --> VEHICLE_OUT
    
    classDef reflex fill:#ffcccc,stroke:#ff0000,stroke-width:3px
    class SAFETY_CHECK,LIMIT_APPLY reflex
```

**特徴**:
- **応答時間**: < 1ms
- **判断基準**: 事前設定された制限値
- **実行**: リアルタイムフィルタリング

### 🧠 熟考動作を実装するコンポーネント

#### 1. Planning - 階層的計画システム
```mermaid
flowchart TD
    GOAL[🎯 目標設定] --> MISSION_PLAN[🗺️ ミッション計画<br/>1-10秒]
    
    subgraph "熟考層1: 大局計画"
        MISSION_PLAN --> ROUTE_SEARCH[🔍 経路探索<br/>A*アルゴリズム]
        ROUTE_SEARCH --> WAYPOINT_GEN[📍 ウェイポイント生成]
    end
    
    subgraph "熟考層2: 行動計画"
        WAYPOINT_GEN --> BEHAVIOR_EVAL[🤔 行動評価<br/>100-1000ms]
        BEHAVIOR_EVAL --> MULTI_OPT[📊 複数選択肢検討]
        MULTI_OPT --> COST_CALC[💰 コスト計算]
        
        LANE_FOLLOW[🛣️ 車線追従]
        LANE_CHANGE[↔️ 車線変更]
        AVOID[🚫 障害物回避]
        INTERSECT[🚦 交差点通過]
        
        MULTI_OPT --> LANE_FOLLOW
        MULTI_OPT --> LANE_CHANGE
        MULTI_OPT --> AVOID
        MULTI_OPT --> INTERSECT
    end
    
    subgraph "熟考層3: 運動計画"
        COST_CALC --> MOTION_PLAN[📈 運動計画<br/>10-100ms]
        MOTION_PLAN --> TRAJ_GEN[🌊 軌道生成<br/>Frenet座標系]
        TRAJ_GEN --> VEL_PROFILE[⚡ 速度プロファイル]
        VEL_PROFILE --> OPTIMIZE[✨ 最適化]
    end
    
    OPTIMIZE --> FINAL_TRAJ[🏁 最終軌道]
    
    classDef delib fill:#ccffcc,stroke:#00aa00,stroke-width:2px
    class MISSION_PLAN,BEHAVIOR_EVAL,MOTION_PLAN,OPTIMIZE delib
```

**特徴**:
- **応答時間**: 100ms - 10秒
- **判断基準**: 多目的最適化
- **実行**: 複雑な数値計算とアルゴリズム

#### 2. Perception - 認識処理
```mermaid
flowchart TD
    SENSOR_DATA[📡 センサーデータ] --> PREPROCESSING[🔧 前処理<br/>50-100ms]
    PREPROCESSING --> DETECTION[🎯 物体検出<br/>100-200ms]
    DETECTION --> TRACKING[📍 追跡処理<br/>50ms]
    TRACKING --> PREDICTION[🔮 動作予測<br/>100-500ms]
    
    subgraph "深層学習による認識"
        DETECTION --> CNN_PROC[🧠 CNN処理<br/>CenterPoint/YOLOX]
        CNN_PROC --> FEATURE_EXT[🔍 特徴抽出]
        FEATURE_EXT --> CLASSIFICATION[📋 分類・検出]
    end
    
    subgraph "時系列解析"
        TRACKING --> KALMAN[📊 カルマンフィルタ]
        KALMAN --> HUNGARIAN[🎯 ハンガリアン法]
        HUNGARIAN --> ID_ASSIGN[🏷️ ID割り当て]
    end
    
    subgraph "予測モデル"
        PREDICTION --> CV_MODEL[📈 等速モデル]
        PREDICTION --> MAP_BASED[🗺️ 地図ベース予測]
        PREDICTION --> LEARNED[🤖 学習ベース予測]
    end
    
    PREDICTION --> PERCEPTION_OUT[👁️ 認識結果出力]
    
    classDef delib fill:#ccffcc,stroke:#00aa00,stroke-width:2px
    class DETECTION,TRACKING,PREDICTION delib
```

**特徴**:
- **応答時間**: 50-500ms
- **判断基準**: 統計的推論と学習モデル
- **実行**: GPU加速計算

### ⚖️ 統合意思決定システム

```mermaid
graph TB
    subgraph "入力層"
        SENS_IN[📡 センサー入力]
        MAP_IN[🗺️ 地図データ]
        STATE_IN[📊 車両状態]
    end
    
    subgraph "認識・位置推定層"
        PERCEPTION[👁️ 認識処理<br/>熟考: 100-500ms]
        LOCALIZATION[📍 位置推定<br/>熟考: 50-100ms]
    end
    
    subgraph "危険度評価層"
        EMERGENCY_DETECT[🚨 緊急事態検知<br/>反射: 1-10ms]
        SITUATION_ASSESS[🤔 状況評価<br/>熟考: 100ms]
    end
    
    subgraph "実行層"
        REFLEX_ACTION[⚡ 反射動作<br/>AEB/MRM/Filter]
        DELIB_ACTION[🧠 熟考動作<br/>Planning/Control]
    end
    
    subgraph "制御統合層"
        CMD_GATE[🛡️ Command Gate<br/>優先度制御: < 1ms]
    end
    
    subgraph "出力層"
        VEHICLE_CTRL[🚙 車両制御]
    end
    
    SENS_IN --> PERCEPTION
    MAP_IN --> LOCALIZATION
    STATE_IN --> EMERGENCY_DETECT
    
    PERCEPTION --> EMERGENCY_DETECT
    PERCEPTION --> SITUATION_ASSESS
    LOCALIZATION --> SITUATION_ASSESS
    
    EMERGENCY_DETECT -->|緊急時| REFLEX_ACTION
    SITUATION_ASSESS -->|通常時| DELIB_ACTION
    
    REFLEX_ACTION -->|最高優先度| CMD_GATE
    DELIB_ACTION -->|通常優先度| CMD_GATE
    
    CMD_GATE --> VEHICLE_CTRL
    
    classDef reflex fill:#ffcccc,stroke:#ff0000,stroke-width:3px
    classDef delib fill:#ccffcc,stroke:#00aa00,stroke-width:2px
    classDef gate fill:#ccccff,stroke:#0000ff,stroke-width:2px
    
    class EMERGENCY_DETECT,REFLEX_ACTION reflex
    class PERCEPTION,LOCALIZATION,SITUATION_ASSESS,DELIB_ACTION delib
    class CMD_GATE gate
```

### 📊 性能特性比較

| 動作タイプ | 応答時間 | 計算複雑度 | 精度 | 適応性 | 主要用途 |
|:----------|:---------|:----------|:-----|:-------|:---------|
| **反射動作** | 1-100ms | 低 | 中 | 低 | 安全確保 |
| **熟考動作** | 100ms-10s | 高 | 高 | 高 | 最適化 |

### 🔄 協調動作例

#### シナリオ: 急な車線変更が必要な状況

1. **熟考動作**: 車線変更計画を最適化（500ms）
2. **反射動作**: 急接近車両をAEBで検知（5ms）
3. **統合制御**: Command Gateで優先度判定（< 1ms）
4. **最終動作**: 緊急ブレーキ実行（反射動作が優先）

この**多層防御システム**により、Autowareは様々な交通状況に対して適切な時間スケールで最適な判断と行動を実現しています。