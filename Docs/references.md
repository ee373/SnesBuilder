# 参考技術資料・設計決定根拠

Rev.0.7 / 2026-11-16。採用した仕様に関係する資料を収録する。メーカーの仕様とプロジェクトの推定・評価値を区別する。

## PSoC

- R01 [CY8C5287AXI-LP095 製品情報](https://www.infineon.com/part/CY8C5287AXI-LP095)、[CY8C52LP Family Datasheet](https://www.infineon.com/assets/row/public/documents/non-assigned/49/infineon-psoc5lp-cy8c52lp-datasheet-datasheet-en.pdf)（001-84933 Rev.P）。TQFP100端子表、VDDIO対応、GPIO AC特性、UDB AC特性（p.93）。MCU選定、72/72本割り当ての根拠。
- R02 [PSoC 5LP Architecture TRM](https://www.infineon.com/assets/row/public/documents/30/57/infineon-psoc5lp-architecture-trm-additionaltechnicalinformation-en.pdf)（001-78426 Rev.G）。19.3.5.1 / Fig.19-7：PRTx_BYP、DSI/DR選択。第21・22章：UDB、内部配線。
- R03 [PSoC 5LP Registers TRM](https://www.infineon.com/assets/row/public/documents/30/57/infineon-psoc5lp-registers-trm-additionaltechnicalinformation-en.pdf)（001-82120 Rev.G）。PRTx_DR、PS、DM0～2、BYP、BIE、SLW。 [Firmware Control of Hardware Output Pin](https://community.infineon.com/t5/Knowledge-Base-Articles/Firmware-Control-of-Hardware-Output-Pin-in-PSoC-3-5LP/ta-p/249274)。
- R04 [AN81623 Digital Design Best Practices](https://www.infineon.com/assets/row/public/documents/cross-divisions/42/infineon-an81623-psoc-3-psoc-4-and-psoc-5lp-digital-design-best-practices-applicationnotes-en.pdf?fileId=8ac78c8c7cdc391c017d0726b5b94b78)（001-81623 Rev.F）。DSIスイッチ約1～2ns、GPIO同期の無効化、TDP/TDR、STA。p.30 Fig.40のPSoC 3例22.883ns（1.250+5.433+16.200ns）。端子間遅延の実測値ではない。
- R05 [AN82250 Implementing Programmable Logic Designs with Verilog（公開版 Rev.F）](https://community.infineon.com/gfawx74859/attachments/gfawx74859/psoc4/46012/1/AN82250%20-%20Implementing%20PLD%20with%20Verilog_0F.pdf)（001-82250）。12C4 PLDの12入力、8積項、4マクロセルに基づく構造推定。
- R06 [AN82156 Designing PSoC Creator Components with UDB Datapaths](https://www.infineon.com/assets/row/public/documents/cross-divisions/42/infineon-an82156-designing-psoc-creator-components-with-udb-datapaths-applicationnotes-en.pdf)（001-82156 Rev.I）、[日本語版](https://www.infineon.com/assets/row/public/documents/cross-divisions/42/infineon-an82156-psoc-3-psoc-4-and-psoc-5lp-designing-psoc-creator-components-with-udb-datapaths-applicationnotes-ja.pdf)。8bit ALU、データパス、4byte FIFO×2、連結。
- R07 [AN60580 SIO Tips and Tricks 日本語版](https://www.infineon.com/assets/row/public/documents/30/42/infineon-an60580-sio-tips-and-tricks-in-psoc-3-psoc-5lp-applicationnotes-ja.pdf)（002-31231）。SIO特性と電圧ドメイン、SPI端子設計。

## SFC

- R08 [Nintendo SNES Development Manual Book I（公開アーカイブ）](https://floating.muncher.se/bot/manual/book1_text.pdf)、Chapter 21, 2-21-1。SlowROM 200ns未満、FastROM 120ns未満、MEMSEL、DMA 2.68MHz相当、Mode 25。
- R09 SNESdev Wiki：[Memory map](https://snes.nesdev.org/wiki/Memory_map)、[Timing](https://snes.nesdev.org/wiki/Timing)、[Cartridge connector](https://snes.nesdev.org/wiki/Cartridge_connector)、[ROM File Formats](https://snes.nesdev.org/wiki/ROM_file_formats)。ExHiROM A23反転、/ROMSEL、IRQ端子、各バスサイクル。
- R10 [Fullsnes / Nocash SNES Specifications](https://problemkaputt.de/fullsnes.htm)。既存マッピングとSRAM選択。
- R11 SNES Central：[SHVC-LJ3M-01](https://snescentral.com/pcbboards.php?chip=SHVC-LJ3M-01)（ExHiROM、$80～$BF:6000～7FFF）、[SHVC-1J3M-01](https://snescentral.com/pcbboards.php?chip=SHVC-1J3M-01)（HiROM、$20～$3F/$A0～$BF:6000～7FFF）。マッピング情報はbsnes/higan由来。SRAM互換モードと$5000通信配置の根拠。
- [Super Famicom Development Wiki: Memory Mapping](https://wiki.superfamicom.org/memory-mapping)。

## メモリ・ロジック

- R12 [S29GL064S70TFI023](https://www.infineon.com/part/S29GL064S70TFI023)、S29GL064S Datasheet 001-98286（[メーカー資料一覧](https://www.infineon.com/products/memories/nor-flash/parallel/high-performance-page-mode)）。AC Read表、タイミング図、注文型番。8MiB、70ns、ページ15ns、/OE 15ns、/CE 70ns、モデル02均一64KiBセクタ。8MiB品を維持する。
- R13 [CY62128EV30LL-45SXI](https://www.infineon.com/part/CY62128EV30LL-45SXI)、CY62128EV30 Datasheet 38-05579 Rev.N、AC特性p.7。128KiB、45ns、/OE22ns、書込パルス35ns、データセットアップ25ns、データ保持。
- R14 [SN74LVC16244A](https://www.ti.com/product/SN74LVC16244A)、[データシート](https://www.ti.com/lit/ds/symlink/sn74lvc16244a.pdf)。16bit、4bitごとの/OE、3.3V時4.1ns（条件付き）、5.5V入力許容、Ioff。10bitアドレスバイパスとSPIレベル変換。
- [SD Association Physical Layer Simplified Specification](https://www.sdcard.org/downloads/pls/)：SPI実装と電気仕様確認用。

## エミュレータ・ソフトウェア

- [ares](https://github.com/ares-emulator/ares)
- [bsnes](https://github.com/bsnes-emu/bsnes)
- [Unicorn Engine](https://github.com/unicorn-engine/unicorn)

## 設計値と検証の区別

SlowROM 200ns未満・FastROM 120ns未満はR08の要求。NOR70ns、SRAM45ns、3SB4.1nsはR12～14の規定条件下の特性。往路25ns・復路30ns・余裕10nsはR01/R04を参考にした独自の予算であり、実測ではない。PLD推定34～40/48（SPIなし）等は独自RTLの構造評価であり、メーカーの保証値ではない。[bus-udb.md](bus-udb.md)、[udb-evaluation.md](udb-evaluation.md)を参照する。資料のPDF端子表画像取得には以前失敗したため抽出テキストを使用した。回路図作成前に原資料と照合する。

## Rev.0.7追加参照資料

- [AN61290 PSoC 3 and PSoC 5LP Hardware Design Considerations](https://www.infineon.com/assets/row/public/documents/cross-divisions/42/infineon-an61290-psoc-3-and-psoc-5lp-hardware-design-considerations-applicationnotes-en.pdf)：電源、コアレギュレータ、ブースト未使用、SWD接続。
- [AN72382 Using PSoC 3 and PSoC 5LP GPIO Pins](https://www.infineon.com/assets/row/public/documents/cross-divisions/42/infineon-an72382-using-psoc-3-and-psoc-5lp-gpio-pins-applicationnotes-en.pdf)：GPIO、DSI、ドライブモード。
- Infineon PSoC Creator SPI Master Component Datasheet v2.50（標準/高速モードの資源表、13/18 MC、1 datapath、1 Control、3 Statusを設計予算に使用）。実際のコンポーネント版と配置はCreatorで確認する。
- R01/R02/R06：DSIのポート単位の入出力、OE経路、Datapath PI/POおよびStatus/Control共有、FIFO構造。R09：ROMヘッダ、マッピングと非2累乗容量のミラー。

## 2026-11-17 開発環境・自作カートリッジ・原価関連

- [PVSnesLib公式リポジトリ](https://github.com/alekmaul/pvsneslib)、[snes_rules](https://github.com/alekmaul/pvsneslib/blob/master/devkitsnes/snes_rules)、[hdr.asm.in](https://github.com/alekmaul/pvsneslib/blob/master/devkitsnes/include/hdr.asm.in)：816-tcc、WLA-DX、Makeによるビルド構成、HiROMとFastROMの設定、ROMヘッダ・ベクタ生成の確認用。
- [PVSnesLib Issue #332: ExHiROM support](https://github.com/alekmaul/pvsneslib/issues/332)：2026-06-22に開発者がExHiROM未対応と回答。WLA-DXのROMバンク割り当てが調査事項となっている。
- [Mouse Bite Labs Super Nintendo Cartridges](https://github.com/MouseBiteLabs/Super-Nintendo-Cartridges)、[Advanced UV](https://github.com/MouseBiteLabs/Super-Nintendo-Cartridges/tree/main/Advanced%20UV)、[Advanced Flash](https://github.com/MouseBiteLabs/Super-Nintendo-Cartridges/tree/main/Advanced%20Flash)：ExHiROM対応自作基板の部品構成とROMへの書き込み方式。
- [Marv17の8MiBカートリッジ基板](https://www.pcbway.com/project/shareproject/SNES_8MB_Lorom_Hirom_ExLorom_Exhirom_flashcard_with_saving_feature_bf2669ca.html)、[xirom-cart](https://gitlab.com/doragasu/xirom-cart)：ExHiROM対応自作基板の比較資料。
- [TI SN74LVC16244A](https://www.ti.com/product/SN74LVC16244A)、[DigiKey SN74LVC16244ADLR](https://www.digikey.jp/en/products/detail/texas-instruments/SN74LVC16244ADLR/276495)：3SB仕様・価格の参照先。価格・費用は2026-11-17会話内の試算であり、発注数量・納入条件で変動する。部品単価と完成カートリッジ製造原価を区別する。


## 2026-11-17 試作部品・周辺回路・製造価格に関する資料

以下のメーカー資料と販売店製品ページを参照し、採用部品の型番、パッケージ、電源特性、容量特性、および数量別調達価格の参考値を記録した。**販売店掲載価格は調査時の値であり、最新の発注価格や在庫を保証しない。** 詳細BOMは[production.md](production.md)の第8節を参照する。

- [Microchip MCP1825S製品情報](https://www.microchip.com/en-us/product/mcp1825s)：3.3V/500mA LDO、SOT-223、入力・出力コンデンサと熱条件。
- [Samsung CL32A476KOJNNNE データシート（Arrow経由）](https://static6.arrow.com/aropdfconversion/392baee8622accc06126c7ac07c4fd59e8ff636f/specsheetcl32a476kojnnn20250411.pdf)：47µF/16V/±10%/X5R/1210、寸法3.2×2.5×2.5mm。5Vバイアス時の容量は公称値でなく参考カーブからの推計。
- [GCT MEM2075-00-140-01-A（DigiKey）](https://www.digikey.jp/ja/products/detail/gct/MEM2075-00-140-01-A/9859614)：microSD水平プッシュプッシュ式スロット、フットプリントと寸法。
- [ST USBLC6-2SC6 製品情報](https://www.st.com/en/protection-devices/usblc6-2.html)、[USBLC6-4SC6製品情報](https://www.st.com/en/protection-devices/usblc6-4.html)：SOT-23-6のESD保護部品。
- [JST UBシリーズ](https://www.jst-mfg.com/product/index.php?series=257)：Mini-BのDIP/SMT実装仕様、基板厚の比較。1.2mm基板に適合する完全スルーホールの正式候補は未決定。
- [Yageo製品情報](https://www.yageo.com/)、[Samsung Electro-Mechanics MLCC](https://product.samsungsem.com/mlcc)：0805/1206の抵抗・MLCC型番とパッケージ。
- [DigiKey Japan](https://www.digikey.jp/)、[Mouser Japan](https://www.mouser.jp/)：半導体、受動部品、コネクタ等の単品・数量別参考価格。価格の比較基準日は2026-11-17。
- [JLCPCB](https://jlcpcb.com/)、[PCBWay](https://www.pcbway.com/)：4層・1.2mm厚・金端子・面取り加工の可否、ENIGと硬質金めっき、PCBA設定費・実装費の公開条件を比較するための参照先。基板およびPCBAの記載額はGerberによる正式見積もりではない。

## Rev.0.7 1MiB ROM・DVDAC・モノラル音声（2026-11-18）

- [Infineon AN58304 Analog Pin Selection](https://www.infineon.com/assets/row/public/documents/cross-divisions/42/infineon-an58304-psoc-3-and-psoc-5lp-pin-selection-for-analog-designs-applicationnotes-en.pdf)：アナログ経路、専用ピン、スイッチ抵抗。P4[5]への実配置可否はCreator検証が必要。
- [Infineon DVDAC Component](https://www.infineon.com/assets/row/public/documents/cross-divisions/396/infineon-component-dithered-voltage-dac-dvdac-v2.0-software-module-datasheets-en.pdf)：8bit DACのディザリング、分解能と更新速度。
- [Infineon AN64275](https://www.infineon.com/assets/row/public/documents/cross-divisions/42/infineon-an64275-psoc-3-and-psoc-5lp-getting-more-resolution-from-8-bit-dac-applicationnotes-en.pdf)：DVDACの分解能・帯域・LPFのトレードオフ。12bitで32kHzの実効品質は未保証。
- [Microchip MCP6001](https://www.microchip.com/en-us/product/MCP6001)：5V単電源RRIO音声バッファ候補（MCP6001T-I/OT）。正式出力負荷・安定性・フィルタ設計は検証事項。
- [SNESdev cartridge connector](https://snes.nesdev.org/wiki/Cartridge_connector)：カートリッジ外部音声端子31(L)、62(R)。
- [S29GL064S](https://www.infineon.com/part/S29GL064S70TFI023)：256B書込み・64KiBセクタ消去の典型値を利用した時間試算。実際のローダ速度ではない。
