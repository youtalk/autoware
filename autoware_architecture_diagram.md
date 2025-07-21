# Autowareアーキテクチャ概要図

## システム全体アーキテクチャ

```mermaid
graph TB
    subgraph "外部環境"
        ENV[環境・道路・他車両・歩行者]
        HD_MAP[高精度地図データ]
        GNSS[GNSS衛星]
    end

    subgraph "Sensing（センシング）"
        LIDAR[LiDAR]
        CAMERA[カメラ]
        RADAR[レーダー]
        IMU[IMU]
        GNSS_REC[GNSS受信機]
        CAN[CAN通信]
    end

    subgraph "Perception（認識）"
        OBJ_DET[物体検出]
        TRACK[物体追跡]
        PRED[動作予測]
        TL_REC[信号機認識]
        GRID_MAP[占有格子地図]
    end

    subgraph "Localization（自己位置推定）"
        NDT[NDT スキャンマッチング]
        EKF[拡張カルマンフィルタ]
        POSE_EST[姿勢推定]
    end

    subgraph "Planning（経路計画）"
        MISSION[ミッション計画]
        BEHAVIOR[行動計画]
        MOTION[運動計画]
        PATH_OPT[経路最適化]
    end

    subgraph "Control（制御）"
        LAT_CTRL[横方向制御]
        LONG_CTRL[縦方向制御]
        CMD_GATE[コマンドゲート]
        AEB[緊急ブレーキ]
    end

    subgraph "Map（地図）"
        VECTOR_MAP[ベクトル地図]
        POINT_MAP[点群地図]
        MAP_LOADER[地図ローダー]
    end

    subgraph "System（システム）"
        DIAG[診断]
        MRM[最小リスク操作]
        STATE_MON[状態監視]
        LAUNCH[起動管理]
    end

    subgraph "API/Interface"
        ADAPI[AD API]
        ROS_MSGS[ROSメッセージ]
        RVIZ[可視化]
        WEB_API[Web API]
    end

    subgraph "Vehicle（車両）"
        ACTUATOR[アクチュエータ]
        BRAKE[ブレーキ]
        STEER[ステアリング]
        ACCEL[アクセル]
    end

    %% データフロー
    ENV --> SENSING
    HD_MAP --> MAP
    GNSS --> SENSING
    
    SENSING --> PERCEPTION
    SENSING --> LOCALIZATION
    
    MAP --> LOCALIZATION
    MAP --> PLANNING
    
    PERCEPTION --> PLANNING
    LOCALIZATION --> PLANNING
    
    PLANNING --> CONTROL
    CONTROL --> VEHICLE
    
    SYSTEM --> CONTROL
    SYSTEM --> PLANNING
    SYSTEM --> PERCEPTION
    
    API --> SYSTEM
    API --> PLANNING
    
    %% フィードバック
    VEHICLE -.-> SENSING
    CONTROL -.-> SYSTEM
```

## 各コンポーネント詳細説明

### 1. Sensing（センシング）
- **役割**: 環境情報の取得とセンサーデータの前処理
- **主要機能**:
  - LiDAR点群データの取得・前処理
  - カメラ画像の取得・歪み補正
  - レーダーデータの処理
  - IMU・GNSSデータの統合
  - CAN通信による車両データ取得

### 2. Perception（認識）
- **役割**: センサーデータから環境の意味的理解
- **主要機能**:
  - 3D物体検出（車両、歩行者、自転車）
  - 多物体追跡（Multi-Object Tracking）
  - 動作予測（Motion Prediction）
  - 信号機認識・分類
  - 占有格子地図生成

### 3. Localization（自己位置推定）
- **役割**: 高精度な自車位置・姿勢の推定
- **主要機能**:
  - NDTアルゴリズムによるスキャンマッチング
  - 拡張カルマンフィルタによるセンサー融合
  - GNSS/IMU統合
  - 姿勢推定の信頼性評価

### 4. Planning（経路計画）
- **役割**: 目的地までの安全で効率的な経路・軌道生成
- **主要機能**:
  - **Mission Planning**: 大局的な経路計画
  - **Behavior Planning**: 交通状況に応じた行動決定
  - **Motion Planning**: 詳細な軌道生成
  - 経路最適化・平滑化

### 5. Control（制御）
- **役割**: 計画された軌道の正確な追従
- **主要機能**:
  - Model Predictive Control（MPC）による横方向制御
  - PID制御による縦方向制御
  - 緊急ブレーキシステム
  - コマンドゲートによる安全性確保

### 6. Map（地図）
- **役割**: 高精度地図データの管理・提供
- **主要機能**:
  - Lanelet2ベクトル地図の読み込み
  - 点群地図（PCD）の管理
  - 地図投影・座標変換
  - 動的地図更新

### 7. System（システム）
- **役割**: システム全体の監視・制御・安全性確保
- **主要機能**:
  - 診断システム（故障検知・報告）
  - Minimum Risk Maneuver（最小リスク操作）
  - 状態監視・ヘルスチェック
  - 起動・停止管理

### 8. API/Interface
- **役割**: 外部システムとの連携・可視化
- **主要機能**:
  - Autoware AD API（標準化されたインターフェース）
  - ROSメッセージ通信
  - RViz可視化
  - Web API・リモート制御

## データフロー概要

1. **上流**: Sensing → Perception → Planning
2. **位置情報**: Map + Sensing → Localization → Planning
3. **制御**: Planning → Control → Vehicle
4. **監視**: System ← 全コンポーネント
5. **インターフェース**: API ← → 各コンポーネント

## 特徴

- **モジュラー設計**: 各コンポーネントは独立して開発・テスト可能
- **ROS 2ベース**: 分散システム・リアルタイム処理に対応
- **プラグイン対応**: アルゴリズムの動的切り替えが可能
- **安全性重視**: 多重の安全機構を内蔵
- **拡張性**: 新機能・アルゴリズムの追加が容易

---

## 反射動作と熟考動作の階層的実装

Autowareは安全で効率的な自動運転を実現するため、**反射動作（Reflexive Actions）**と**熟考動作（Deliberative Actions）**を時間スケールと優先度に基づいて階層的に実装しています。

### 反射動作と熟考動作の分類

```mermaid
graph TB
    subgraph "反射動作 (Reflexive Actions)"
        direction TB
        AEB[🚨 緊急ブレーキ<br/>AEB<br/>1-10ms]
        MRM[⚠️ 最小リスク操作<br/>MRM<br/>10-100ms]
        FILTER[🛡️ 制御フィルタ<br/>CMD Gate<br/><1ms]
        EMERGENCY[🛑 緊急停止<br/>Emergency Stop<br/>1-10ms]
    end
    
    subgraph "熟考動作 (Deliberative Actions)"
        direction TB
        MISSION[🗺️ ミッション計画<br/>Mission Planning<br/>1-10秒]
        BEHAVIOR[🚗 行動計画<br/>Behavior Planning<br/>100-1000ms]
        MOTION[📈 運動計画<br/>Motion Planning<br/>10-100ms]
        OPTIMIZE[✨ 経路最適化<br/>Path Optimization<br/>1-10ms]
    end
    
    subgraph "優先度と応答時間"
        PRIORITY["🔺 優先度: 反射動作 > 熟考動作<br/>⏱️ 応答時間: 反射動作(ms) << 熟考動作(秒)"]
    end
```

### 階層的意思決定システム

```mermaid
graph TD
    SENSOR[📡 センサー入力] --> PERCEPTION[👁️ 認識処理]
    PERCEPTION --> EMERGENCY_CHECK{🚨 緊急状況?}
    
    EMERGENCY_CHECK -->|Yes| REFLEXIVE[⚡ 反射動作実行]
    EMERGENCY_CHECK -->|No| DELIBERATIVE[🧠 熟考動作実行]
    
    subgraph "反射動作層 (1-100ms) - 最高優先度"
        REFLEXIVE --> AEB_CHECK{💥 衝突危険?}
        AEB_CHECK -->|Yes| AEB_BRAKE[🚨 緊急ブレーキ]
        AEB_CHECK -->|No| MRM_CHECK{⚠️ システム故障?}
        MRM_CHECK -->|Yes| MRM_EXECUTE[⚠️ MRM実行]
        MRM_CHECK -->|No| FILTER_CHECK{🛡️ 制御値異常?}
        FILTER_CHECK -->|Yes| FILTER_APPLY[🛡️ フィルタ適用]
        FILTER_CHECK -->|No| NORMAL_CONTROL[✅ 通常制御]
    end
    
    subgraph "熟考動作層 (100ms-10秒) - 通常優先度"
        DELIBERATIVE --> PLAN_MISSION[🗺️ ミッション計画<br/>大局的経路]
        PLAN_MISSION --> PLAN_BEHAVIOR[🚗 行動計画<br/>車線変更・回避]
        PLAN_BEHAVIOR --> PLAN_MOTION[📈 運動計画<br/>詳細軌道]
        PLAN_MOTION --> OPTIMIZE[✨ 最適化<br/>平滑化]
    end
    
    AEB_BRAKE --> VEHICLE[🚙 車両制御]
    MRM_EXECUTE --> VEHICLE
    FILTER_APPLY --> VEHICLE
    NORMAL_CONTROL --> VEHICLE
    OPTIMIZE --> VEHICLE
    
    classDef reflexive fill:#ffcccc,stroke:#ff0000,stroke-width:3px
    classDef deliberative fill:#ccffcc,stroke:#00aa00,stroke-width:2px
    classDef priority fill:#ffffcc,stroke:#ffaa00,stroke-width:2px
    
    class REFLEXIVE,AEB_CHECK,AEB_BRAKE,MRM_CHECK,MRM_EXECUTE,FILTER_CHECK,FILTER_APPLY reflexive
    class DELIBERATIVE,PLAN_MISSION,PLAN_BEHAVIOR,PLAN_MOTION,OPTIMIZE deliberative
```

### 時間スケールと優先度マトリックス

| 優先度 | 動作タイプ | 応答時間 | 実装コンポーネント | 主要機能 |
|:------|:-----------|:---------|:------------------|:---------|
| **1 (最高)** | 反射動作 | **1-10ms** | AEB, Emergency Stop | 衝突回避、緊急停止 |
| **2 (高)** | 安全制御 | **10-100ms** | MRM, Command Gate | 故障対応、制御フィルタ |
| **3 (中)** | 運動制御 | **100ms** | Motion Planning | 軌道追従、速度制御 |
| **4 (中)** | 行動制御 | **1秒** | Behavior Planning | 車線変更、障害物回避 |
| **5 (低)** | 計画制御 | **10秒** | Mission Planning | 大局的経路計画 |

### 統合制御フロー

```mermaid
graph LR
    subgraph "入力"
        INPUT[📡 センサー<br/>地図データ]
    end
    
    subgraph "処理"
        PROCESSING[👁️ 認識<br/>📍 位置推定]
    end
    
    subgraph "意思決定"
        DECISION{🚨 緊急?}
        REFLEX[⚡ 反射動作]
        DELIB[🧠 熟考動作]
    end
    
    subgraph "制御統合"
        GATE[🛡️ Command Gate<br/>優先度制御]
    end
    
    subgraph "出力"
        OUTPUT[🚙 車両制御]
    end
    
    INPUT --> PROCESSING
    PROCESSING --> DECISION
    DECISION -->|Yes| REFLEX
    DECISION -->|No| DELIB
    REFLEX -->|高優先度| GATE
    DELIB -->|低優先度| GATE
    GATE --> OUTPUT
    
    classDef reflex fill:#ffcccc,stroke:#ff0000,stroke-width:3px
    classDef delib fill:#ccffcc,stroke:#00aa00,stroke-width:2px
    classDef gate fill:#ccccff,stroke:#0000ff,stroke-width:2px
    
    class REFLEX reflex
    class DELIB delib
    class GATE gate
```

### 実装上の特徴

#### 反射動作の特徴
- **低レイテンシー**: ハードウェア割り込みレベルの高速応答
- **決定論的**: 事前定義されたルールベース判断
- **安全性重視**: 確実な危険回避を最優先
- **単純ロジック**: 複雑な計算を避けた高速処理

#### 熟考動作の特徴
- **最適化指向**: 複数目的関数による最適解探索
- **適応性**: 環境変化に応じた柔軟な計画変更
- **効率性重視**: 燃費・時間・快適性の総合最適化
- **学習能力**: 過去の経験を活用した改善

この**二重階層システム**により、Autowareは緊急時の瞬時対応と通常時の最適な運転計画を両立し、安全で効率的な自動運転を実現しています。