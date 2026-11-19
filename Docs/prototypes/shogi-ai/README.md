# 将棋AI移植によるSFCBuilder初期実装・総合技術実証案

- 作成日: 2026-11-17
- 区分: **初期実装候補／技術実証計画（未着手）**
- 参照ハードウェア: SFCBuilder Rev.0.8
- 想定実行環境: SFC実機 + SFCBuilder（PSoC 5LP CY8C5287AXI-LP095）
- 主案: 『早指し二段 森田将棋2』の65C816側画面・操作プログラムを活用し、思考処理をPSoCのARM Cortex-M3上の新規将棋AIに置き換える。

## 1. 目的と位置づけ

SFCBuilderの最初期から最終段階まで、同じ題材を使ってROMマッピング、ARMネイティブコード、CPU間通信、FIFO、メモリ所有権切り替え、外部NOR読み出し、microSD/USBデバッグ、SDK・エミュレータを順次検証する。将棋は実機描画の負荷が小さく、1手あたりの思考時間を数秒から数十秒以上確保できるため、最大80MHz・64KiB内部SRAMのCortex-M3を継続的に評価する用途に適する。

ゲーム本体には既存の将棋ソフトを移植対象として利用する構想であり、**ST018の命令実行やコマンドの完全互換機能をSFCBuilderに実装しない**。65C816側ROM内の拡張プロセッサ通信ルーチンを直接パッチし、SFCBuilderの既存通信レジスタ・FIFOと独自の将棋AIコマンドに接続する。盤面の内部表現と既存ルーチンの呼び出し規約だけを必要な範囲で調査する。

『森田将棋2』は改造候補であり、実装に必要なROM内のフック位置、ゲームロジックの分担、LoROM原本のバンク配置・追加通信部の適合は未調査である。対象ソフト、配布形態、AIエンジンの採用をSFCBuilder本体の確定仕様にはしない。

## 2. 実装方針

1. 初期のSFC側プログラムには既存の盤面表示、コントローラ入力、効果音・BGM、メニューを活用する。
2. ROMにあるST018との通信開始・データ送信・思考完了待ち・指し手受信のコードを、既存呼び出し元との整合性を維持したSFCBuilder通信ドライバへ置き換える。
3. ARMは将棋の合法手生成・探索・評価・指し手返却を担当する。通信プロトコルはST018非互換のSFCBuilder専用形式にする。
4. 初期はPC上の思考エンジンへUSB経由で委譲し、その後ARM単体で動作する軽量エンジンを経て、学習済みNNUE評価関数「つようら王11micro」を移植候補にする。
5. つようら王11microは圧縮済みの重みをNORに格納し、特徴量単位で必要な重みを逐次復号する案を第一候補とする。全展開して内部SRAMに保持する方式は採用しない。
6. 実機単独での対局を最終的な実証状態とし、PCはビルド、初期デバッグ、ベンチマーク、自動対局に利用する。

## 3. 本体仕様への依存

| 項目 | 現行Rev.0.8の仕様 | この題材での使用方法 |
|---|---|---|
| ARM | Cortex-M3 最大80MHz、内部Flash 256KiB・SRAM 64KiB、FPUなし | 思考エンジンと圧縮重みの整数演算 |
| 外部NOR | 8MiB、8bit、70ns品 | 65C816コード・ARMバイナリ・圧縮評価関数 |
| 外部SRAM | 128KiB、NORと共通バス | 棋譜、探索用補助データ、セーブ |
| ROMマッピング | HiROM/ExHiROM/LoROM/ExLoROM、NOR事前ミラー配置 | 原本ROM形式のまま実機起動し、ゲーム側コード・通信部を個別パッチ |
| 通信 | `$00:5000`ベースのレジスタ、独立双方向4バイトFIFO | 指し手・盤面・思考状態の送受信 |
| バス調停 | SFC/ARMの外部メモリ排他使用 | NNUE重み読み出し時にARMがNORを使用 |
| USB | PSoCがFull-Speed USBデバイス | PCエンジンによる暫定思考・検証 |
| microSD | SPI | ROM/ARMコード/評価関数のロードと差し替え |

特に、**ARMが外部NORを所有している間はSFCがカートリッジROMを読めない**。SFC側で思考待ちの処理を内部WRAMへ移し、カートリッジROMを参照するNMI・IRQ・DMAを停止するという現行の排他的バス所有権規則を守る。盤面表示はPPUが継続し、BGMはAPUが独立動作できる。画面アニメーションや表示更新を思考中に継続したい場合は、WRAM側へ必要なルーチンを移す。

## 4. 成果物

- 元ROMを再配布せず、ゲームの正規所有者が用意したROMに適用する差分パッチと変換ツール。
- 65C816側SFCBuilder通信ドライバとARM側将棋エンジン・評価関数ローダ。
- PCによる参照評価・自動対局・USBプロキシ・実機プロファイリングのテストツール。
- 実測値を伴うNORアクセス、復号、探索速度、思考時間、棋力の検証記録。

実装の詳細は [integration.md](integration.md)、[nnue-memory.md](nnue-memory.md)、[milestones.md](milestones.md)に分ける。共通のハードウェア仕様を変更する提案ではなく、個別の実証ソフトウェア案として記録する。

## 5. 既存資料

- [SFCBuilder本体](../../README.md)
- [メモリマッピング](../../memory.md)
- [通信レジスタ・FIFO](../../communication.md)
- [バス所有権・タイミング](../../bus-udb.md)
- [ARM共通BIOSとロード方式](../../firmware.md)
- [既存ROM互換方針](../../rom-compatibility.md)
- [SDK・エミュレータ](../../sdk-emulator.md)

## 6. 参照元

- やねうら王ソースコード: https://github.com/yaneurao/YaneuraOu
- ネットワーク構造生成器: https://github.com/yaneurao/YaneuraOu/blob/master/source/eval/nnue/architectures/nnue_arch_gen.py
- NNUE特徴変換層: https://github.com/yaneurao/YaneuraOu/blob/master/source/eval/nnue/nnue_feature_transformer.h
- 進行度データの形式: https://github.com/yaneurao/YaneuraOu/blob/master/tools/memo/progress-format.md

外部プロジェクトの構造・配布物・ライセンスは実際に使用するリビジョンを固定して確認する。ROMの解析結果や独自パッチは調査後に追記する。
