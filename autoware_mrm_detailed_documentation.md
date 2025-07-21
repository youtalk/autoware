# Autoware MRM（Minimum Risk Maneuver）詳細ドキュメント

## 1. MRM（最小リスク操作）の概要

MRM（Minimum Risk Maneuver）は、自動運転システムが正常に動作できなくなった場合に、車両を安全な状態に移行させるための重要な安全機能です。Autowareでは、システムの故障レベルや状況に応じて、複数のMRM戦略を実装しています。

### 1.1 MRMの基本概念

```mermaid
graph TB
    subgraph "MRMの発動条件"
        NORMAL["正常動作状態
(default_ad_api)"]
        DEGRADE["性能劣化検知
(system_error_monitor)"]
        FAILURE["システム故障検知
(emergency_handler)"]
        EMERGENCY["緊急事態発生
(hazard_status_converter)"]
    end
    
    subgraph "MRMの種類"
        COMFORTABLE["快適停止
Comfortable Stop
(mrm_comfortable_stop_operator)"]
        EMERGENCY_STOP["緊急停止
Emergency Stop
(mrm_emergency_stop_operator)"]
        PULLOVER["路肩退避
Pull Over
(mrm_pull_over_operator)"]
        PULLOUT["退避場所へ移動
Pull Out
(mrm_pull_out_operator)"]
    end
    
    subgraph "最終状態"
        SAFE_STATE["安全状態
・車両停止
・ハザード点灯
・ドア解錠"]
    end
    
    NORMAL -->|故障検知| DEGRADE
    DEGRADE -->|軽度| COMFORTABLE
    DEGRADE -->|中度| PULLOVER
    FAILURE -->|重度| EMERGENCY_STOP
    EMERGENCY -->|即座| EMERGENCY_STOP
    
    COMFORTABLE --> SAFE_STATE
    EMERGENCY_STOP --> SAFE_STATE
    PULLOVER --> SAFE_STATE
    PULLOUT --> SAFE_STATE
    
    style NORMAL fill:#90EE90
    style DEGRADE fill:#FFD700
    style FAILURE fill:#FF6347
    style EMERGENCY fill:#DC143C
```

## 2. MRMの階層的アーキテクチャ

### 2.1 システム全体構成

```mermaid
graph TD
    subgraph "監視層"
        HB_MON["ハートビート監視
(component_state_monitor)"]
        DIAG_MON["診断監視
(diagnostic_aggregator)"]
        PERF_MON["性能監視
(system_monitor)"]
        ENV_MON["環境監視
(environment_monitor)"]
    end
    
    subgraph "判断層"
        FAIL_DETECT["故障検知器
(failure_detector)"]
        RISK_ASSESS["リスク評価器
(risk_assessor)"]
        MRM_SELECT["MRM選択器
(mrm_selector)"]
    end
    
    subgraph "実行層"
        MRM_BEHAVIOR["MRM行動計画
(mrm_behavior_planner)"]
        MRM_MOTION["MRM運動計画
(mrm_motion_planner)"]
        MRM_CONTROL["MRM制御
(mrm_controller)"]
    end
    
    subgraph "車両制御層"
        VEHICLE_CMD["車両コマンド
(vehicle_cmd_gate)"]
        HAZARD_CTRL["ハザード制御
(hazard_light_controller)"]
        DOOR_CTRL["ドア制御
(door_controller)"]
        COMM_CTRL["通信制御
(remote_cmd_converter)"]
    end
    
    HB_MON --> FAIL_DETECT
    DIAG_MON --> FAIL_DETECT
    PERF_MON --> FAIL_DETECT
    ENV_MON --> RISK_ASSESS
    
    FAIL_DETECT --> MRM_SELECT
    RISK_ASSESS --> MRM_SELECT
    
    MRM_SELECT --> MRM_BEHAVIOR
    MRM_BEHAVIOR --> MRM_MOTION
    MRM_MOTION --> MRM_CONTROL
    
    MRM_CONTROL --> VEHICLE_CMD
    MRM_CONTROL --> HAZARD_CTRL
    MRM_CONTROL --> DOOR_CTRL
    MRM_CONTROL --> COMM_CTRL
```

### 2.2 故障検知メカニズム

```mermaid
flowchart TD
    subgraph "入力監視"
        SENSOR_CHECK["センサー状態チェック
(sensing_driver)"]
        LOCALIZATION_CHECK["自己位置推定チェック
(localization_health_checker)"]
        PERCEPTION_CHECK["認識機能チェック
(perception_health_checker)"]
        PLANNING_CHECK["計画機能チェック
(planning_health_checker)"]
        CONTROL_CHECK["制御機能チェック
(control_health_checker)"]
    end
    
    subgraph "故障判定"
        TIMEOUT["タイムアウト検知
・3秒以上無応答"]
        QUALITY["品質劣化検知
・精度低下
・ノイズ増大"]
        CONSISTENCY["一貫性チェック
・矛盾検出
・異常値"]
    end
    
    subgraph "故障レベル分類"
        LEVEL1["レベル1: 軽微
・単一センサー故障
・冗長性あり"]
        LEVEL2["レベル2: 中度
・複数機能劣化
・限定的動作可能"]
        LEVEL3["レベル3: 重度
・主要機能停止
・即座の対応必要"]
    end
    
    SENSOR_CHECK --> TIMEOUT
    LOCALIZATION_CHECK --> TIMEOUT
    PERCEPTION_CHECK --> QUALITY
    PLANNING_CHECK --> QUALITY
    CONTROL_CHECK --> CONSISTENCY
    
    TIMEOUT --> LEVEL1
    TIMEOUT --> LEVEL2
    QUALITY --> LEVEL2
    QUALITY --> LEVEL3
    CONSISTENCY --> LEVEL3
    
    style LEVEL1 fill:#FFFFE0
    style LEVEL2 fill:#FFD700
    style LEVEL3 fill:#FF6347
```

## 3. MRMの種類と実行詳細

### 3.1 快適停止（Comfortable Stop）

```mermaid
flowchart TD
    START["快適停止開始
(mrm_comfortable_stop_operator)"] --> CHECK_LANE{"現在車線で
停止可能?
(path_safety_checker)"}
    
    CHECK_LANE -->|Yes| DECEL_PLAN["減速計画生成
・目標減速度: -1.0 m/s²
・ジャーク制限: 0.5 m/s³
(trajectory_planner)"]
    CHECK_LANE -->|No| FIND_SAFE["安全な停止位置探索
(goal_planner)"]
    
    DECEL_PLAN --> SMOOTH_STOP["スムーズ停止実行
・5-10秒で停止
・乗客の快適性維持"]
    
    FIND_SAFE --> LANE_CHANGE[車線変更して停止]
    LANE_CHANGE --> SMOOTH_STOP
    
    SMOOTH_STOP --> STOP_ACTIONS[停止後動作]
    
    subgraph "停止後動作"
        HAZARD_ON["ハザードランプ点灯
(turn_signal_decider)"]
        PARK_BRAKE["パーキングブレーキ
(shift_decider)"]
        SHIFT_P["シフトP
(shift_decider)"]
        DOOR_UNLOCK["ドア解錠
(door_controller)"]
        NOTIFY["管制センター通知
(autoware_state_panel)"]
    end
    
    STOP_ACTIONS --> HAZARD_ON
    HAZARD_ON --> PARK_BRAKE
    PARK_BRAKE --> SHIFT_P
    SHIFT_P --> DOOR_UNLOCK
    DOOR_UNLOCK --> NOTIFY
```

### 3.2 緊急停止（Emergency Stop）

```mermaid
flowchart TD
    TRIGGER["緊急停止トリガー
(mrm_emergency_stop_operator)"] --> IMMEDIATE["即座の制動開始
・最大減速度: -6.0 m/s²
・ABS作動許容
(emergency_brake_controller)"]
    
    IMMEDIATE --> PARALLEL_ACTIONS{並行処理}
    
    PARALLEL_ACTIONS --> BRAKE["最大制動力
・前後配分最適化
・横滑り防止"]
    PARALLEL_ACTIONS --> HAZARD_FLASH["ハザード高速点滅
・2Hz以上"]
    PARALLEL_ACTIONS --> HORN["警笛吹鳴
・断続的"]
    PARALLEL_ACTIONS --> EMERGENCY_COMM["緊急通信
・V2X/セルラー"]
    
    BRAKE --> FULL_STOP["完全停止
・2-3秒以内"]
    
    FULL_STOP --> POST_STOP[停止後処理]
    
    subgraph "緊急停止後処理"
        EPB[電動パーキングブレーキ作動]
        ENGINE_OFF[エンジン停止]
        DOOR_OPEN[全ドア解錠]
        EMERGENCY_CALL["緊急通報
（eCall）"]
    end
    
    POST_STOP --> EPB
    EPB --> ENGINE_OFF
    ENGINE_OFF --> DOOR_OPEN
    DOOR_OPEN --> EMERGENCY_CALL
    
    style TRIGGER fill:#DC143C
    style IMMEDIATE fill:#FF6347
```

### 3.3 路肩退避（Pull Over）

```mermaid
flowchart TD
    INIT["路肩退避開始
(mrm_pull_over_operator)"] --> SCAN["退避場所スキャン
(pull_over_planner)"]
    
    subgraph "退避場所探索"
        SHOULDER["路肩検出
・幅2.5m以上
・障害物なし
(lanelet2_extension)"]
        PARKING["駐車場検索
・500m以内
・アクセス可能
(goal_planner)"]
        EMERGENCY_BAY["非常駐車帯
・1km以内
(map_loader)"]
    end
    
    SCAN --> SHOULDER
    SCAN --> PARKING
    SCAN --> EMERGENCY_BAY
    
    SHOULDER --> EVALUATE[評価・選択]
    PARKING --> EVALUATE
    EMERGENCY_BAY --> EVALUATE
    
    EVALUATE --> PATH_PLAN[退避経路計画]
    
    subgraph "経路計画詳細"
        LANE_SEQUENCE["車線変更順序
・右車線へ移動
・安全確認"]
        DECEL_PROFILE["減速プロファイル
・段階的減速
・-0.5～-2.0 m/s²"]
        STEERING_PLAN["操舵計画
・最大横加速度: 2.0 m/s²"]
    end
    
    PATH_PLAN --> LANE_SEQUENCE
    PATH_PLAN --> DECEL_PROFILE
    PATH_PLAN --> STEERING_PLAN
    
    LANE_SEQUENCE --> EXECUTE[実行フェーズ]
    DECEL_PROFILE --> EXECUTE
    STEERING_PLAN --> EXECUTE
    
    EXECUTE --> PULLOVER_COMPLETE[退避完了]
    
    subgraph "退避完了後"
        POSITION_SECURE["位置確保
・車両安定"]
        HAZARD_ACTIVE[ハザード継続]
        REFLECTOR["三角表示板
（将来機能）"]
        REMOTE_ASSIST[遠隔支援要請]
    end
    
    PULLOVER_COMPLETE --> POSITION_SECURE
    POSITION_SECURE --> HAZARD_ACTIVE
    HAZARD_ACTIVE --> REFLECTOR
    REFLECTOR --> REMOTE_ASSIST
```

## 4. MRM選択ロジック

### 4.1 状況別MRM選択フロー

```mermaid
flowchart TD
    FAILURE_DETECTED["故障検知
(system_error_monitor)"] --> ASSESS{"故障評価
(mrm_handler)"}
    
    ASSESS --> CRITICAL{重大故障?}
    ASSESS --> LOCATION{現在位置?}
    ASSESS --> TRAFFIC{交通状況?}
    ASSESS --> ROAD{道路種別?}
    
    CRITICAL -->|Yes| EMERGENCY_STOP_SELECT[緊急停止選択]
    CRITICAL -->|No| LOCATION_CHECK
    
    LOCATION -->|高速道路| HIGHWAY_MRM
    LOCATION -->|一般道| URBAN_MRM
    LOCATION -->|交差点内| INTERSECTION_MRM
    
    TRAFFIC -->|渋滞| COMFORTABLE_SELECT[快適停止選択]
    TRAFFIC -->|通常| PULLOVER_SELECT[路肩退避選択]
    TRAFFIC -->|混雑| CAREFUL_MRM
    
    ROAD -->|片側多車線| LANE_CHANGE_MRM
    ROAD -->|単車線| IN_LANE_MRM
    ROAD -->|路肩あり| SHOULDER_MRM
    
    subgraph "高速道路MRM戦略"
        HIGHWAY_MRM --> HIGHWAY_SHOULDER[路肩退避優先]
        HIGHWAY_SHOULDER --> HIGHWAY_DECEL["段階的減速
・80→60→40→0 km/h"]
    end
    
    subgraph "市街地MRM戦略"
        URBAN_MRM --> URBAN_PARKING[駐車場探索]
        URBAN_PARKING --> URBAN_ROADSIDE[路側停車]
    end
    
    subgraph "交差点MRM戦略"
        INTERSECTION_MRM --> CLEAR_INTERSECTION[交差点通過]
        CLEAR_INTERSECTION --> IMMEDIATE_STOP[即座停止]
    end
```

### 4.2 MRM優先度マトリクス

```mermaid
graph TD
    subgraph "故障レベル × 環境条件マトリクス"
        subgraph "レベル1故障"
            L1_HIGHWAY["高速道路
→路肩退避"]
            L1_URBAN["市街地
→快適停止"]
            L1_PARKING["駐車場
→通常駐車"]
        end
        
        subgraph "レベル2故障"
            L2_HIGHWAY["高速道路
→緊急退避"]
            L2_URBAN["市街地
→最寄停止"]
            L2_INTERSECTION["交差点
→通過後停止"]
        end
        
        subgraph "レベル3故障"
            L3_ANY["全環境
→緊急停止"]
            L3_SPECIAL["特殊状況
→状況適応"]
        end
    end
    
    style L1_HIGHWAY fill:#90EE90
    style L1_URBAN fill:#90EE90
    style L1_PARKING fill:#90EE90
    style L2_HIGHWAY fill:#FFD700
    style L2_URBAN fill:#FFD700
    style L2_INTERSECTION fill:#FFD700
    style L3_ANY fill:#FF6347
    style L3_SPECIAL fill:#DC143C
```

## 5. MRM実行時のシステム動作

### 5.1 MRM実行シーケンス

```mermaid
sequenceDiagram
    participant MON as 監視システム
    participant MRM as MRM管理器
    participant PLAN as 計画システム
    participant CTRL as 制御システム
    participant VEH as 車両
    participant CENTER as 管制センター
    
    MON->>MON: 異常検知
    MON->>MRM: 故障通知
    MRM->>MRM: 故障レベル判定
    MRM->>MRM: MRM種別選択
    
    MRM->>PLAN: MRM計画要求
    PLAN->>PLAN: 安全経路生成
    PLAN->>MRM: 計画完了
    
    MRM->>CTRL: MRM実行指令
    CTRL->>VEH: 制御コマンド
    
    par 並行処理
        VEH->>VEH: 減速実行
        VEH->>VEH: ハザード点灯
        MRM->>CENTER: 状況通知
    end
    
    loop 実行監視
        CTRL->>VEH: 制御更新
        VEH->>CTRL: 状態フィードバック
        CTRL->>MRM: 進捗報告
    end
    
    VEH->>VEH: 停止完了
    MRM->>CENTER: 完了通知
    CENTER->>CENTER: 対応手配
```

### 5.2 MRM中の機能制限

```mermaid
graph TB
    subgraph "通常動作時機能"
        FULL_PERCEPTION["完全認識機能
(perception)"]
        FULL_PLANNING["完全計画機能
(planning)"]
        FULL_CONTROL["完全制御機能
(control)"]
        COMFORT_FEATURES["快適機能
(comfort_features)"]
    end
    
    subgraph "MRM動作時機能"
        LIMITED_PERCEPTION["限定認識
・前方のみ
・最小範囲
(mrm_perception)"]
        SIMPLE_PLANNING["単純計画
・停止のみ
・固定経路
(mrm_planner)"]
        SAFE_CONTROL["安全制御
・保守的
・冗長系
(mrm_controller)"]
        EMERGENCY_ONLY["緊急機能のみ
(mrm_emergency)"]
    end
    
    subgraph "無効化される機能"
        LANE_CHANGE_X[車線変更 ❌]
        OVERTAKE_X[追い越し ❌]
        INTERSECTION_X[交差点通過 ❌]
        OPTIMIZATION_X[経路最適化 ❌]
    end
    
    FULL_PERCEPTION -.->|MRM発動| LIMITED_PERCEPTION
    FULL_PLANNING -.->|MRM発動| SIMPLE_PLANNING
    FULL_CONTROL -.->|MRM発動| SAFE_CONTROL
    COMFORT_FEATURES -.->|MRM発動| EMERGENCY_ONLY
    
    style LANE_CHANGE_X fill:#FFB6C1
    style OVERTAKE_X fill:#FFB6C1
    style INTERSECTION_X fill:#FFB6C1
    style OPTIMIZATION_X fill:#FFB6C1
```

## 6. 実装詳細

### 6.1 MRMステートマシン

```mermaid
stateDiagram-v2
    [*] --> Normal: システム起動<br/>(autoware_launch)
    
    Normal --> MRMReady: 異常検知<br/>(system_error_monitor)
    MRMReady --> MRMOperating: MRM開始<br/>(mrm_handler)
    
    state MRMOperating {
        [*] --> Decelerating
        Decelerating --> LaneChanging: 車線変更必要
        Decelerating --> Stopping: 目標地点接近
        LaneChanging --> Decelerating: 車線変更完了
        Stopping --> Stopped: 速度ゼロ
    }
    
    MRMOperating --> MRMSucceeded: 正常完了
    MRMOperating --> MRMFailed: 実行失敗
    
    MRMSucceeded --> WaitingForRecovery
    MRMFailed --> EmergencyStop
    
    WaitingForRecovery --> Normal: 手動復帰
    EmergencyStop --> [*]: システム停止
    
    state Normal {
        [*] --> Driving
        Driving --> Monitoring
        Monitoring --> Driving
    }
```

### 6.2 MRM動作パラメータ

```mermaid
graph LR
    subgraph "快適停止パラメータ"
        CS_DECEL[減速度: -1.0 m/s²]
        CS_JERK[ジャーク: 0.5 m/s³]
        CS_TIME[停止時間: 5-10秒]
        CS_DISTANCE[停止距離: 50-100m]
    end
    
    subgraph "緊急停止パラメータ"
        ES_DECEL[減速度: -6.0 m/s²]
        ES_JERK[ジャーク: 無制限]
        ES_TIME[停止時間: 2-3秒]
        ES_DISTANCE[停止距離: 10-30m]
    end
    
    subgraph "路肩退避パラメータ"
        PO_DECEL[減速度: -2.0 m/s²]
        PO_LATERAL[横加速度: 2.0 m/s²]
        PO_TIME[実行時間: 20-30秒]
        PO_SEARCH[探索範囲: 500m]
    end
```

## 7. 安全性保証

### 7.1 MRMの冗長性設計

```mermaid
graph TB
    subgraph "主系統"
        MAIN_MONITOR[主監視系<br/>(primary_system_monitor)]
        MAIN_MRM[主MRM制御<br/>(primary_mrm_handler)]
        MAIN_EXECUTOR[主実行系<br/>(primary_executor)]
    end
    
    subgraph "副系統"
        SUB_MONITOR[副監視系<br/>(secondary_system_monitor)]
        SUB_MRM[副MRM制御<br/>(secondary_mrm_handler)]
        SUB_EXECUTOR[副実行系<br/>(secondary_executor)]
    end
    
    subgraph "緊急系統"
        EMERGENCY_TRIGGER[緊急トリガー<br/>(emergency_handler)]
        HARDWARE_MRM[ハードウェアMRM<br/>(hw_safety_controller)]
        MECHANICAL_BRAKE[機械式ブレーキ<br/>(mechanical_brake_system)]
    end
    
    MAIN_MONITOR --> MAIN_MRM
    MAIN_MRM --> MAIN_EXECUTOR
    
    SUB_MONITOR --> SUB_MRM
    SUB_MRM --> SUB_EXECUTOR
    
    MAIN_MONITOR -.->|故障| SUB_MONITOR
    MAIN_MRM -.->|故障| SUB_MRM
    MAIN_EXECUTOR -.->|故障| SUB_EXECUTOR
    
    SUB_MRM -.->|故障| EMERGENCY_TRIGGER
    EMERGENCY_TRIGGER --> HARDWARE_MRM
    HARDWARE_MRM --> MECHANICAL_BRAKE
    
    style EMERGENCY_TRIGGER fill:#DC143C
    style HARDWARE_MRM fill:#FF6347
    style MECHANICAL_BRAKE fill:#FF6347
```

### 7.2 フェイルセーフ機構

```mermaid
flowchart TD
    subgraph "多重防護"
        LEVEL1[第1層: ソフトウェア監視<br/>・プロセス監視<br/>・通信監視<br/>(process_monitor)]
        LEVEL2[第2層: システム監視<br/>・CPU/メモリ監視<br/>・センサー監視<br/>(system_monitor)]
        LEVEL3[第3層: ハードウェア監視<br/>・電源監視<br/>・温度監視<br/>(hardware_monitor)]
        LEVEL4[第4層: 機械的安全装置<br/>・独立ブレーキ<br/>・手動オーバーライド<br/>(mechanical_safety)]
    end
    
    LEVEL1 -->|異常| MRM1[ソフトMRM]
    LEVEL2 -->|異常| MRM2[システムMRM]
    LEVEL3 -->|異常| MRM3[ハードMRM]
    LEVEL4 -->|作動| MECHANICAL[機械的停止]
    
    MRM1 --> SAFE_STOP[安全停止]
    MRM2 --> SAFE_STOP
    MRM3 --> SAFE_STOP
    MECHANICAL --> IMMEDIATE_STOP[即座停止]
    
    style LEVEL4 fill:#DC143C
    style MECHANICAL fill:#FF6347
```

## 8. 実環境でのMRM事例

### 8.1 高速道路でのMRM実行例

```mermaid
flowchart LR
    subgraph "シナリオ: 高速道路でのセンサー故障"
        T0[時刻0秒<br/>LiDAR故障検知<br/>速度: 100km/h<br/>(lidar_driver)]
        T1[時刻1秒<br/>MRM起動決定<br/>路肩退避選択<br/>(mrm_selector)]
        T5[時刻5秒<br/>車線変更開始<br/>速度: 90km/h<br/>(lane_change_planner)]
        T10[時刻10秒<br/>路肩進入<br/>速度: 60km/h<br/>(pull_over_planner)]
        T15[時刻15秒<br/>減速継続<br/>速度: 40km/h<br/>(velocity_controller)]
        T20[時刻20秒<br/>完全停止<br/>ハザード点灯<br/>(hazard_light_cmd_publisher)]
    end
    
    T0 --> T1
    T1 --> T5
    T5 --> T10
    T10 --> T15
    T15 --> T20
    
    T20 --> ACTIONS[停止後動作<br/>・管制通知<br/>・路側表示<br/>・救援要請]
```

### 8.2 市街地でのMRM実行例

```mermaid
flowchart TD
    subgraph "シナリオ: 交差点付近での制御系異常"
        DETECT[異常検知<br/>交差点手前30m<br/>速度: 40km/h]
        ASSESS[状況評価<br/>・交差点通過不可<br/>・後続車あり]
        DECIDE[MRM決定<br/>・快適停止選択<br/>・左路側寄せ]
        EXECUTE[実行<br/>・ハザード点灯<br/>・段階的減速<br/>・路側停止]
    end
    
    DETECT --> ASSESS
    ASSESS --> DECIDE
    DECIDE --> EXECUTE
    
    EXECUTE --> COMPLETE[完了<br/>・安全確保<br/>・交通影響最小化]
```

## 9. まとめ

AutowareのMRMシステムは、自動運転車両の安全性を確保する最後の砦として機能します。故障の種類と深刻度、環境条件、交通状況を総合的に判断し、最適な安全行動を選択・実行します。

### 主要な特徴：
- **多層防護**: ソフトウェアからハードウェアまでの多重安全機構
- **状況適応**: 環境に応じた柔軟なMRM戦略
- **段階的対応**: 故障レベルに応じた適切な対応
- **冗長性確保**: 主系統故障時のバックアップ機能
- **完全性**: 停止後の安全確保まで含む包括的システム

このMRMシステムにより、Autowareは高い安全性と信頼性を持つ自動運転を実現しています。