# Autoware 反射動作と熟考動作の実装

## 概要

Autowareは安全で効率的な自動運転を実現するため、**反射動作（Reflexive Actions）**と**熟考動作（Deliberative Actions）**を階層的に実装しています。

## 反射動作と熟考動作の分類

```mermaid
graph TB
    subgraph "反射動作 (Reflexive Actions)"
        AEB[緊急ブレーキ<br/>AEB]
        MRM[最小リスク操作<br/>MRM]
        FILTER[制御フィルタ<br/>CMD Gate]
        EMERGENCY[緊急停止<br/>Emergency Stop]
    end
    
    subgraph "熟考動作 (Deliberative Actions)"
        MISSION[ミッション計画<br/>Mission Planning]
        BEHAVIOR[行動計画<br/>Behavior Planning]
        MOTION[運動計画<br/>Motion Planning]
        OPTIMIZE[経路最適化<br/>Path Optimization]
    end
    
    subgraph "特徴"
        REFLEX_CHAR[反射動作特徴:<br/>・低レイテンシー<br/>・ハードコード<br/>・安全性重視<br/>・単純ルール]
        DELIB_CHAR[熟考動作特徴:<br/>・高レイテンシー<br/>・最適化<br/>・効率性重視<br/>・複雑計算]
    end
```

## 階層的意思決定システム

```mermaid
graph TD
    SENSOR[センサー入力] --> PERCEPTION[認識処理]
    PERCEPTION --> EMERGENCY_CHECK{緊急状況?}
    
    EMERGENCY_CHECK -->|Yes| REFLEXIVE[反射動作実行]
    EMERGENCY_CHECK -->|No| DELIBERATIVE[熟考動作実行]
    
    subgraph "反射動作層 (1-10ms)"
        REFLEXIVE --> AEB_CHECK{衝突危険?}
        AEB_CHECK -->|Yes| AEB_BRAKE[緊急ブレーキ]
        AEB_CHECK -->|No| MRM_CHECK{システム故障?}
        MRM_CHECK -->|Yes| MRM_EXECUTE[MRM実行]
        MRM_CHECK -->|No| FILTER_CHECK{制御値異常?}
        FILTER_CHECK -->|Yes| FILTER_APPLY[フィルタ適用]
        FILTER_CHECK -->|No| NORMAL_CONTROL[通常制御]
    end
    
    subgraph "熟考動作層 (100-1000ms)"
        DELIBERATIVE --> PLAN_MISSION[ミッション計画<br/>大局的経路]
        PLAN_MISSION --> PLAN_BEHAVIOR[行動計画<br/>車線変更・回避]
        PLAN_BEHAVIOR --> PLAN_MOTION[運動計画<br/>詳細軌道]
        PLAN_MOTION --> OPTIMIZE[最適化<br/>平滑化]
    end
    
    AEB_BRAKE --> VEHICLE[車両制御]
    MRM_EXECUTE --> VEHICLE
    FILTER_APPLY --> VEHICLE
    NORMAL_CONTROL --> VEHICLE
    OPTIMIZE --> VEHICLE
```

## 反射動作の詳細実装

### 1. AEB (Autonomous Emergency Braking)

```mermaid
flowchart TD
    START[AEB開始] --> ACTIVE_CHECK{AEB有効?}
    ACTIVE_CHECK -->|No| END[終了]
    ACTIVE_CHECK -->|Yes| PATH_GEN[予測経路生成<br/>IMU/MPC]
    
    PATH_GEN --> OBSTACLE_DET[障害物検出<br/>点群/物体]
    OBSTACLE_DET --> SPEED_EST[障害物速度推定]
    SPEED_EST --> RSS_CALC[RSS距離計算]
    
    RSS_CALC --> COLLISION_CHECK{衝突危険?}
    COLLISION_CHECK -->|Yes| EMERGENCY_BRAKE[緊急ブレーキ信号<br/>診断システムへ]
    COLLISION_CHECK -->|No| MONITOR[監視継続]
    
    EMERGENCY_BRAKE --> END
    MONITOR --> PATH_GEN
    
    subgraph "RSS計算"
        RSS_FORMULA["d = v_ego*t_response + v_ego²/(2*a_min)<br/>- sign(v_obj)*v_obj²/(2*a_obj_min) + offset"]
    end
```

**特徴**:
- **応答時間**: 1-10ms
- **判断基準**: RSS距離による厳密な計算
- **動作**: 即座の緊急ブレーキ

### 2. MRM (Minimum Risk Maneuver)

```mermaid
flowchart TD
    FAILURE[システム故障検知] --> MRM_SELECT{MRM選択}
    
    MRM_SELECT --> COMFORTABLE[快適停止<br/>Comfortable Stop]
    MRM_SELECT --> EMERGENCY[緊急停止<br/>Emergency Stop]
    MRM_SELECT --> PULLOVER[路肩退避<br/>Pull Over]
    
    COMFORTABLE --> GRADUAL_STOP[段階的減速停止]
    EMERGENCY --> IMMEDIATE_STOP[即座の急停止]
    PULLOVER --> SAFE_LOCATION[安全な場所への移動]
    
    GRADUAL_STOP --> HAZARD[ハザードランプ点灯]
    IMMEDIATE_STOP --> HAZARD
    SAFE_LOCATION --> HAZARD
    
    HAZARD --> COMPLETE[MRM完了]
```

**特徴**:
- **応答時間**: 10-100ms
- **判断基準**: システム故障の種類と重要度
- **動作**: 状況に応じた最小リスク行動

### 3. Vehicle Command Gate

```mermaid
flowchart TD
    CONTROL_IN[制御コマンド入力] --> GATE_MODE{ゲートモード}
    
    GATE_MODE --> AUTO[自動運転モード]
    GATE_MODE --> EXTERNAL[外部制御モード]
    GATE_MODE --> EMERGENCY[緊急モード]
    
    AUTO --> FILTER[制御フィルタ]
    EXTERNAL --> FILTER
    EMERGENCY --> DIRECT[直接出力]
    
    FILTER --> LIMIT_CHECK{制限値チェック}
    LIMIT_CHECK -->|正常| OUTPUT[車両へ出力]
    LIMIT_CHECK -->|異常| LIMIT_APPLY[制限値適用]
    
    LIMIT_APPLY --> OUTPUT
    DIRECT --> OUTPUT
    
    subgraph "フィルタ項目"
        VEL_LIM[速度制限]
        ACC_LIM[加速度制限]
        JERK_LIM[ジャーク制限]
        LAT_LIM[横加速度制限]
    end
```

**特徴**:
- **応答時間**: < 1ms
- **判断基準**: 事前定義された制限値
- **動作**: 異常値の補正・制限

## 熟考動作の詳細実装

### 階層的計画システム

```mermaid
flowchart TD
    GOAL[目標設定] --> MISSION_PLAN[ミッション計画]
    
    subgraph "ミッション計画 (1-10秒)"
        MISSION_PLAN --> ROUTE_SEARCH[大局的経路探索<br/>A*アルゴリズム]
        ROUTE_SEARCH --> WAYPOINT[ウェイポイント生成]
    end
    
    subgraph "行動計画 (100-1000ms)"
        WAYPOINT --> BEHAVIOR_SEL[行動選択]
        BEHAVIOR_SEL --> LANE_FOLLOW[車線追従]
        BEHAVIOR_SEL --> LANE_CHANGE[車線変更]
        BEHAVIOR_SEL --> AVOIDANCE[障害物回避]
        BEHAVIOR_SEL --> INTERSECTION[交差点通過]
        
        LANE_FOLLOW --> BEHAVIOR_PATH[行動経路生成]
        LANE_CHANGE --> BEHAVIOR_PATH
        AVOIDANCE --> BEHAVIOR_PATH
        INTERSECTION --> BEHAVIOR_PATH
    end
    
    subgraph "運動計画 (10-100ms)"
        BEHAVIOR_PATH --> MOTION_PLAN[運動計画]
        MOTION_PLAN --> TRAJECTORY[軌道生成<br/>Frenet座標系]
        TRAJECTORY --> VELOCITY[速度プロファイル]
        VELOCITY --> OPTIMIZE_PATH[経路最適化]
    end
    
    subgraph "最適化 (1-10ms)"
        OPTIMIZE_PATH --> SMOOTH[平滑化処理]
        SMOOTH --> COLLISION_FREE[衝突回避チェック]
        COLLISION_FREE --> FINAL_TRAJ[最終軌道]
    end
    
    FINAL_TRAJ --> CONTROL[制御コマンド生成]
```

### 意思決定プロセス

```mermaid
flowchart TD
    SITUATION[交通状況認識] --> EVALUATE[選択肢評価]
    
    subgraph "選択肢生成"
        EVALUATE --> OPT1[選択肢1: 車線維持]
        EVALUATE --> OPT2[選択肢2: 車線変更]
        EVALUATE --> OPT3[選択肢3: 障害物回避]
        EVALUATE --> OPT4[選択肢4: 減速停止]
    end
    
    subgraph "評価基準"
        SAFETY[安全性]
        EFFICIENCY[効率性]
        COMFORT[快適性]
        LEGALITY[法規遵守]
    end
    
    OPT1 --> COST_CALC[コスト計算]
    OPT2 --> COST_CALC
    OPT3 --> COST_CALC
    OPT4 --> COST_CALC
    
    SAFETY --> COST_CALC
    EFFICIENCY --> COST_CALC
    COMFORT --> COST_CALC
    LEGALITY --> COST_CALC
    
    COST_CALC --> SELECT[最適選択肢決定]
    SELECT --> EXECUTE[実行]
```

## 統合システムアーキテクチャ

```mermaid
graph TB
    subgraph "入力層"
        SENSORS[センサー]
        MAP_DATA[地図データ]
    end
    
    subgraph "認識層"
        PERCEPTION[物体認識]
        LOCALIZATION[自己位置推定]
    end
    
    subgraph "判断層"
        EMERGENCY_DETECT[緊急事態検知]
        PLANNING[計画システム]
    end
    
    subgraph "実行層"
        REFLEXIVE_EXEC[反射動作実行]
        DELIBERATIVE_EXEC[熟考動作実行]
    end
    
    subgraph "制御層"
        CMD_GATE[コマンドゲート]
        VEHICLE_IF[車両インターフェース]
    end
    
    SENSORS --> PERCEPTION
    MAP_DATA --> LOCALIZATION
    PERCEPTION --> EMERGENCY_DETECT
    LOCALIZATION --> PLANNING
    
    EMERGENCY_DETECT -->|緊急時| REFLEXIVE_EXEC
    PLANNING -->|通常時| DELIBERATIVE_EXEC
    
    REFLEXIVE_EXEC --> CMD_GATE
    DELIBERATIVE_EXEC --> CMD_GATE
    CMD_GATE --> VEHICLE_IF
    
    %% 優先度表示
    REFLEXIVE_EXEC -.->|高優先度| CMD_GATE
    DELIBERATIVE_EXEC -.->|低優先度| CMD_GATE
```

## 時間スケールと優先度

| レベル | 動作タイプ | 応答時間 | 優先度 | 主要機能 |
|--------|------------|----------|--------|----------|
| 1 | 反射動作 | 1-10ms | 最高 | AEB, 緊急停止 |
| 2 | 安全制御 | 10-100ms | 高 | MRM, フィルタ |
| 3 | 運動制御 | 100ms | 中 | 軌道追従 |
| 4 | 行動制御 | 1秒 | 中 | 車線変更, 回避 |
| 5 | 計画制御 | 10秒 | 低 | 経路計画 |

この階層的なアーキテクチャにより、Autowareは緊急時の即座の対応と、通常時の最適な計画を両立しています。