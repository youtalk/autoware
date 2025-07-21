# Autoware × E2E AI リアルタイム分散アーキテクチャ設計

## 1. リアルタイム制約と計算リソース設計

### 1.1 リアルタイム要求仕様

```mermaid
graph TB
    subgraph "リアルタイム制約階層"
        subgraph "ハードリアルタイム (1-10ms)"
            AEB_RT[AEB<br/>最悪1ms]
            STEER_RT[操舵制御<br/>最悪5ms]
            BRAKE_RT[ブレーキ制御<br/>最悪3ms]
        end
        
        subgraph "ファームリアルタイム (10-50ms)"
            PERCEP_RT[物体検出<br/>最悪30ms]
            LOCAL_RT[自己位置推定<br/>最悪20ms]
            TRACK_RT[物体追跡<br/>最悪25ms]
        end
        
        subgraph "ソフトリアルタイム (50-200ms)"
            PLAN_RT[経路計画<br/>目標100ms]
            PRED_RT[動作予測<br/>目標150ms]
            E2E_RT[E2E推論<br/>目標50ms]
        end
    end
    
    subgraph "WCET分析"
        WCET[最悪実行時間<br/>Worst Case Execution Time]
        STATIC[静的解析]
        MEASURE[実測定]
        PROB[確率的保証]
    end
    
    AEB_RT --> WCET
    STEER_RT --> WCET
    BRAKE_RT --> WCET
    
    WCET --> STATIC
    WCET --> MEASURE
    WCET --> PROB
```

### 1.2 計算リソース配分アーキテクチャ

```mermaid
graph LR
    subgraph "高性能計算ユニット"
        subgraph "AI推論専用"
            GPU1[NVIDIA Orin X<br/>275 TOPS]
            GPU2[NVIDIA Orin X<br/>275 TOPS]
            NPU1[専用NPU<br/>400 TOPS]
        end
        
        subgraph "汎用計算"
            CPU_MAIN[Intel Xeon<br/>32コア]
            CPU_SUB[AMD EPYC<br/>24コア]
        end
        
        subgraph "リアルタイム専用"
            RTOS_CPU[ARM Cortex-R52<br/>8コア]
            FPGA[Xilinx Zynq<br/>専用回路]
        end
    end
    
    subgraph "メモリ階層"
        HBM[HBM3<br/>32GB/2TB/s]
        DDR5[DDR5<br/>128GB/200GB/s]
        SRAM[オンチップSRAM<br/>256MB/10TB/s]
        CACHE[L3キャッシュ<br/>64MB]
    end
    
    subgraph "タスク割当"
        E2E_TASK[E2E推論<br/>→GPU1/NPU1]
        MOD_TASK[モジュラー処理<br/>→GPU2/CPU_MAIN]
        SAFETY_TASK[安全機能<br/>→RTOS_CPU/FPGA]
        FUSION_TASK[センサー融合<br/>→CPU_SUB]
    end
    
    GPU1 --> HBM
    GPU2 --> HBM
    NPU1 --> SRAM
    CPU_MAIN --> DDR5
    RTOS_CPU --> CACHE
    
    E2E_TASK --> GPU1
    E2E_TASK --> NPU1
    MOD_TASK --> GPU2
    MOD_TASK --> CPU_MAIN
    SAFETY_TASK --> RTOS_CPU
    SAFETY_TASK --> FPGA
    FUSION_TASK --> CPU_SUB
```

### 1.3 動的リソース管理システム

```mermaid
flowchart TD
    subgraph "リソースモニタリング"
        USAGE[使用率監視<br/>・CPU/GPU/メモリ<br/>・温度/電力]
        LATENCY[遅延監視<br/>・タスク実行時間<br/>・通信遅延]
        PREDICT[負荷予測<br/>・時系列分析<br/>・シナリオ予測]
    end
    
    subgraph "動的スケジューリング"
        PRIORITY[優先度管理<br/>・安全性最優先<br/>・動的調整]
        MIGRATE[タスク移行<br/>・負荷分散<br/>・故障回避]
        THROTTLE[性能調整<br/>・周波数制御<br/>・精度調整]
    end
    
    subgraph "QoS保証"
        DEADLINE[デッドライン保証<br/>・EDF/RM]
        BANDWIDTH[帯域保証<br/>・CBS/TBS]
        ISOLATION[リソース分離<br/>・コンテナ/VM]
    end
    
    USAGE --> PRIORITY
    LATENCY --> MIGRATE
    PREDICT --> THROTTLE
    
    PRIORITY --> DEADLINE
    MIGRATE --> BANDWIDTH
    THROTTLE --> ISOLATION
    
    DEADLINE --> GUARANTEE[リアルタイム保証]
    BANDWIDTH --> GUARANTEE
    ISOLATION --> GUARANTEE
```

## 2. 複数ECUシステムの分散アーキテクチャ

### 2.1 ゾーン型ECUアーキテクチャ

```mermaid
graph TB
    subgraph "中央計算ユニット"
        CENTRAL[中央ECU<br/>・メイン処理<br/>・統合判断]
        BACKUP_C[バックアップ中央ECU<br/>・ホットスタンバイ<br/>・完全冗長]
    end
    
    subgraph "ゾーンECU"
        subgraph "前方ゾーン"
            FRONT_ECU[前方ECU<br/>・前方センサー処理<br/>・AEB制御]
            FRONT_CAM[前方カメラ群]
            FRONT_RADAR[前方レーダー]
            FRONT_LIDAR[前方LiDAR]
        end
        
        subgraph "後方ゾーン"
            REAR_ECU[後方ECU<br/>・後方センサー処理<br/>・後退支援]
            REAR_CAM[後方カメラ群]
            REAR_RADAR[後方レーダー]
        end
        
        subgraph "側方ゾーン"
            LEFT_ECU[左側ECU<br/>・死角監視<br/>・車線変更支援]
            RIGHT_ECU[右側ECU<br/>・死角監視<br/>・車線変更支援]
        end
    end
    
    subgraph "専用機能ECU"
        SAFETY_ECU[安全ECU<br/>・ASIL-D認証<br/>・独立動作]
        GATEWAY_ECU[ゲートウェイECU<br/>・通信管理<br/>・セキュリティ]
        POWER_ECU[電源管理ECU<br/>・電力配分<br/>・冗長電源]
    end
    
    subgraph "高速通信バックボーン"
        TSN[TSN Ethernet<br/>10Gbps<br/>確定的通信]
        PCIE[PCIe Gen5<br/>32GT/s<br/>低遅延]
        CAN_FD[CAN-FD<br/>8Mbps<br/>車両制御]
    end
    
    CENTRAL <==> TSN
    BACKUP_C <==> TSN
    
    FRONT_ECU <==> TSN
    REAR_ECU <==> TSN
    LEFT_ECU <==> TSN
    RIGHT_ECU <==> TSN
    
    SAFETY_ECU <==> CAN_FD
    GATEWAY_ECU <==> TSN
    POWER_ECU <==> CAN_FD
    
    FRONT_CAM --> FRONT_ECU
    FRONT_RADAR --> FRONT_ECU
    FRONT_LIDAR --> FRONT_ECU
    
    REAR_CAM --> REAR_ECU
    REAR_RADAR --> REAR_ECU
    
    style CENTRAL fill:#ff9999
    style BACKUP_C fill:#ffcc99
    style SAFETY_ECU fill:#99ff99
```

### 2.2 分散処理フローと同期機構

```mermaid
sequenceDiagram
    participant S1 as 前方ECU
    participant S2 as 側方ECU
    participant C as 中央ECU
    participant B as バックアップECU
    participant SF as 安全ECU
    participant ACT as アクチュエータ
    
    Note over S1,ACT: 10msサイクル（100Hz）
    
    par センサー処理
        S1->>S1: 前方センサー処理 (5ms)
        S2->>S2: 側方センサー処理 (5ms)
    end
    
    S1->>C: 前方物体情報
    S2->>C: 側方物体情報
    
    par 冗長処理
        C->>C: E2E推論 (20ms)
        B->>B: モジュラー処理 (25ms)
    end
    
    C->>SF: E2E制御命令
    B->>SF: モジュラー制御命令
    
    SF->>SF: 安全性検証 (2ms)
    SF->>SF: 調停・選択 (1ms)
    
    SF->>ACT: 最終制御命令
    
    Note over SF,ACT: 総遅延 < 35ms
    
    loop ヘルスチェック
        C->>B: ハートビート (1ms周期)
        B->>C: ACK
        SF->>C: 状態確認
        SF->>B: 状態確認
    end
```

### 2.3 時刻同期とデータ一貫性

```mermaid
graph TD
    subgraph "時刻同期システム"
        GPS_TIME[GPS時刻源<br/>±100ns精度]
        PTP_GM[PTPグランドマスター<br/>IEEE 1588]
        LOCAL_OSC[高精度発振器<br/>OCXO/原子時計]
    end
    
    subgraph "同期プロトコル"
        PTP[Precision Time Protocol<br/>±1μs精度]
        NTP[Network Time Protocol<br/>±1ms精度]
        SYNC_PULSE[同期パルス<br/>ハードウェア同期]
    end
    
    subgraph "データ一貫性管理"
        TIMESTAMP[タイムスタンプ管理<br/>・ナノ秒精度<br/>・因果順序保証]
        VERSION[バージョン管理<br/>・世代番号<br/>・更新追跡]
        CONSENSUS[分散合意<br/>・Raftアルゴリズム<br/>・Byzantine耐性]
    end
    
    GPS_TIME --> PTP_GM
    LOCAL_OSC --> PTP_GM
    PTP_GM --> PTP
    
    PTP --> TIMESTAMP
    SYNC_PULSE --> TIMESTAMP
    
    TIMESTAMP --> VERSION
    VERSION --> CONSENSUS
```

## 3. 冗長性と安全性の多層防御設計

### 3.1 機能安全アーキテクチャ（ISO 26262準拠）

```mermaid
graph TB
    subgraph "ASIL分解"
        subgraph "ASIL-D機能"
            BRAKE_D[ブレーキ制御<br/>ASIL-D]
            STEER_D[操舵制御<br/>ASIL-D]
            SAFETY_D[安全監視<br/>ASIL-D]
        end
        
        subgraph "ASIL-B機能"
            PERCEP_B[知覚処理<br/>ASIL-B(D)]
            PLAN_B[経路計画<br/>ASIL-B(D)]
        end
        
        subgraph "QM機能"
            E2E_QM[E2E推論<br/>QM+監視]
            COMFORT_QM[快適機能<br/>QM]
        end
    end
    
    subgraph "冗長化戦略"
        HW_REDUNDANT[ハードウェア冗長<br/>・2oo3投票<br/>・故障検出]
        SW_DIVERSITY[ソフトウェア多様性<br/>・異なるアルゴリズム<br/>・独立実装]
        TEMPORAL[時間的冗長<br/>・再実行<br/>・結果検証]
    end
    
    subgraph "故障検出・診断"
        BIST[組込み自己診断<br/>・起動時<br/>・実行時]
        MONITOR[監視機能<br/>・プログラムフロー<br/>・データ整合性]
        DIAGNOSTIC[診断サービス<br/>・故障記録<br/>・劣化予測]
    end
    
    BRAKE_D --> HW_REDUNDANT
    STEER_D --> HW_REDUNDANT
    SAFETY_D --> SW_DIVERSITY
    
    PERCEP_B --> SW_DIVERSITY
    PLAN_B --> TEMPORAL
    
    HW_REDUNDANT --> BIST
    SW_DIVERSITY --> MONITOR
    TEMPORAL --> DIAGNOSTIC
```

### 3.2 フェイルセーフ・フェイルオペレーショナル設計

```mermaid
stateDiagram-v2
    [*] --> 正常動作
    
    正常動作 --> 性能劣化: 軽微な故障
    性能劣化 --> 正常動作: 自己修復
    
    正常動作 --> 縮退動作: 重要部故障
    性能劣化 --> 縮退動作: 故障進行
    
    縮退動作 --> 最小リスク状態: 安全機能故障
    縮退動作 --> 性能劣化: 部分回復
    
    最小リスク状態 --> 安全停止: MRM完了
    
    state 正常動作 {
        [*] --> 完全自動運転
        完全自動運転 --> E2E優先モード
        E2E優先モード --> ハイブリッドモード
        ハイブリッドモード --> 完全自動運転
    }
    
    state 縮退動作 {
        [*] --> 機能制限
        機能制限 --> 速度制限
        速度制限 --> 手動介入要求
    }
    
    state 最小リスク状態 {
        [*] --> 路肩退避
        路肩退避 --> 減速停止
        減速停止 --> 緊急停止
    }
```

### 3.3 サイバーセキュリティ統合

```mermaid
graph TD
    subgraph "セキュリティレイヤー"
        subgraph "境界防御"
            FIREWALL[ファイアウォール<br/>・パケットフィルタ<br/>・DPI]
            IDS[侵入検知<br/>・異常検知<br/>・ML基盤]
            GATEWAY[セキュアゲートウェイ<br/>・認証<br/>・暗号化]
        end
        
        subgraph "内部防御"
            SECURE_BOOT[セキュアブート<br/>・署名検証<br/>・改ざん防止]
            CRYPTO[暗号化モジュール<br/>・HSM<br/>・鍵管理]
            INTEGRITY[完全性監視<br/>・ランタイム検証<br/>・異常検知]
        end
        
        subgraph "データ保護"
            PRIVACY[プライバシー保護<br/>・匿名化<br/>・差分プライバシー]
            SECURE_LOG[セキュアログ<br/>・改ざん防止<br/>・監査証跡]
            SECURE_UPDATE[セキュアアップデート<br/>・OTA<br/>・ロールバック]
        end
    end
    
    FIREWALL --> IDS
    IDS --> GATEWAY
    
    GATEWAY --> SECURE_BOOT
    SECURE_BOOT --> CRYPTO
    CRYPTO --> INTEGRITY
    
    INTEGRITY --> PRIVACY
    PRIVACY --> SECURE_LOG
    SECURE_LOG --> SECURE_UPDATE
```

## 4. 統合システムアーキテクチャ

### 4.1 全体システム構成

```mermaid
graph TB
    subgraph "Tier 1: センサー層"
        CAM_ARRAY[カメラアレイ<br/>8MP×8]
        LIDAR_ARRAY[LiDARアレイ<br/>128線×2]
        RADAR_ARRAY[4Dレーダー<br/>×8]
        GNSS_RTK[GNSS/RTK<br/>±2cm]
    end
    
    subgraph "Tier 2: エッジ処理層"
        FRONT_EDGE[前方エッジ<br/>Orin NX]
        REAR_EDGE[後方エッジ<br/>Orin NX]
        LEFT_EDGE[左側エッジ<br/>Xavier NX]
        RIGHT_EDGE[右側エッジ<br/>Xavier NX]
    end
    
    subgraph "Tier 3: 中央処理層"
        subgraph "プライマリ系"
            MAIN_AI[メインAI<br/>Orin X×2<br/>E2E処理]
            MAIN_CPU[メインCPU<br/>Xeon 32C<br/>統合処理]
        end
        
        subgraph "セカンダリ系"
            BACKUP_AI[バックアップAI<br/>Orin X<br/>モジュラー]
            BACKUP_CPU[バックアップCPU<br/>EPYC 24C<br/>冗長処理]
        end
    end
    
    subgraph "Tier 4: 安全制御層"
        SAFETY_CTRL[安全コントローラ<br/>TMS570×3<br/>2oo3投票]
        VEHICLE_IF[車両インターフェース<br/>ASIL-D認証]
    end
    
    subgraph "通信インフラ"
        TSN_BACKBONE[TSN Ethernet<br/>10Gbps<br/>μs精度同期]
        CAN_NETWORK[CAN-FD/XL<br/>10Mbps<br/>車両制御]
    end
    
    CAM_ARRAY --> FRONT_EDGE
    LIDAR_ARRAY --> FRONT_EDGE
    RADAR_ARRAY --> |各ゾーン| FRONT_EDGE
    
    FRONT_EDGE <==> TSN_BACKBONE
    REAR_EDGE <==> TSN_BACKBONE
    LEFT_EDGE <==> TSN_BACKBONE
    RIGHT_EDGE <==> TSN_BACKBONE
    
    TSN_BACKBONE <==> MAIN_AI
    TSN_BACKBONE <==> MAIN_CPU
    TSN_BACKBONE <==> BACKUP_AI
    TSN_BACKBONE <==> BACKUP_CPU
    
    MAIN_AI --> SAFETY_CTRL
    BACKUP_AI --> SAFETY_CTRL
    
    SAFETY_CTRL <==> CAN_NETWORK
    CAN_NETWORK <==> VEHICLE_IF
    
    style SAFETY_CTRL fill:#99ff99,stroke:#00aa00,stroke-width:3px
    style MAIN_AI fill:#ff9999,stroke:#ff0000,stroke-width:3px
    style BACKUP_AI fill:#ffcc99,stroke:#ff6600,stroke-width:3px
```

### 4.2 リアルタイム処理フロー

```mermaid
gantt
    title リアルタイム処理スケジュール（100Hzサイクル）
    dateFormat X
    axisFormat %L
    
    section センサー取得
    カメラ露光         :cam, 0, 2
    LiDAR回転         :lid, 0, 10
    レーダー取得       :rad, 0, 5
    
    section エッジ処理
    画像前処理        :img_pre, 2, 3
    点群前処理        :pc_pre, 2, 3
    レーダー処理      :rad_proc, 5, 2
    
    section AI推論
    E2E推論(GPU1)    :e2e, 5, 20
    物体検出(GPU2)    :det, 5, 15
    追跡処理(CPU)     :track, 20, 10
    
    section 統合処理
    センサー融合      :fusion, 25, 5
    経路計画         :plan, 30, 15
    安全性検証       :safety, 45, 3
    
    section 制御出力
    制御命令生成     :ctrl, 48, 2
    CAN送信         :can, 50, 1
    
    section 次サイクル準備
    バッファ切替     :buf, 51, 1
```

### 4.3 故障時の動作保証

```mermaid
flowchart TD
    subgraph "正常時処理フロー"
        NORMAL_SENSE[全センサー正常]
        NORMAL_AI[E2E+モジュラー並列]
        NORMAL_CTRL[最適制御選択]
    end
    
    subgraph "レベル1故障"
        L1_SENSE[一部センサー故障]
        L1_COMPENSATE[他センサー補償]
        L1_CONTINUE[性能劣化で継続]
    end
    
    subgraph "レベル2故障"
        L2_AI[AI処理系故障]
        L2_SWITCH[バックアップ切替]
        L2_DEGRADE[機能制限モード]
    end
    
    subgraph "レベル3故障"
        L3_CRITICAL[重要機能故障]
        L3_MRM[MRM起動]
        L3_STOP[安全停止]
    end
    
    NORMAL_SENSE --> |センサー故障| L1_SENSE
    NORMAL_AI --> |GPU故障| L2_AI
    NORMAL_CTRL --> |通信断| L3_CRITICAL
    
    L1_SENSE --> L1_COMPENSATE
    L1_COMPENSATE --> L1_CONTINUE
    
    L2_AI --> L2_SWITCH
    L2_SWITCH --> L2_DEGRADE
    
    L3_CRITICAL --> L3_MRM
    L3_MRM --> L3_STOP
    
    L1_CONTINUE --> |追加故障| L2_DEGRADE
    L2_DEGRADE --> |安全機能故障| L3_MRM
```

## 5. 性能保証とリソース管理

### 5.1 計算リソース配分表

| コンポーネント | 必要性能 | 割当リソース | 最悪実行時間 | 優先度 |
|:-------------|:--------|:----------|:-----------|:------|
| **AEB** | 1000 MIPS | FPGA専用回路 | 0.8ms | 最高 |
| **操舵制御** | 500 MIPS | RTOS CPU コア0-1 | 3.5ms | 最高 |
| **E2E推論** | 200 TOPS | GPU1 + NPU | 45ms | 高 |
| **物体検出** | 100 TOPS | GPU2 | 25ms | 高 |
| **センサー融合** | 5000 MIPS | CPU メインコア | 15ms | 中 |
| **経路計画** | 3000 MIPS | CPU サブコア | 80ms | 中 |
| **地図処理** | 2000 MIPS | CPU 補助コア | 200ms | 低 |

### 5.2 通信帯域配分

```mermaid
pie title 通信帯域使用率（10Gbps TSN）
    "カメラデータ" : 40
    "LiDARデータ" : 30
    "制御命令" : 5
    "状態監視" : 10
    "冗長通信" : 10
    "予備帯域" : 5
```

### 5.3 電力管理戦略

```mermaid
graph LR
    subgraph "電源系統"
        MAIN_PWR[主電源<br/>48V/5kW]
        BACKUP_PWR[補助電源<br/>48V/3kW]
        EMERGENCY_PWR[緊急電源<br/>12V/500W]
    end
    
    subgraph "電力配分"
        AI_POWER[AI処理系<br/>2000W]
        SENSOR_POWER[センサー系<br/>800W]
        COMM_POWER[通信系<br/>300W]
        SAFETY_POWER[安全系<br/>200W]
    end
    
    subgraph "省電力モード"
        NORMAL_MODE[通常モード<br/>3.5kW]
        ECO_MODE[エコモード<br/>2.5kW]
        LIMP_MODE[縮退モード<br/>1.5kW]
    end
    
    MAIN_PWR --> AI_POWER
    MAIN_PWR --> SENSOR_POWER
    BACKUP_PWR --> COMM_POWER
    EMERGENCY_PWR --> SAFETY_POWER
    
    AI_POWER --> NORMAL_MODE
    SENSOR_POWER --> ECO_MODE
    SAFETY_POWER --> LIMP_MODE
```

## 6. まとめ

この詳細設計により、以下を実現：

1. **リアルタイム性**: 最悪35ms以内の制御応答
2. **計算効率**: 950 TOPS の総計算能力を効率配分
3. **冗長性**: 3重系による99.999%の可用性
4. **安全性**: ASIL-D準拠の機能安全
5. **拡張性**: モジュラーECUによる柔軟な構成

これにより、E2E AIの高度な判断能力と、車載システムに要求される高信頼性を両立した次世代自動運転システムを実現します。