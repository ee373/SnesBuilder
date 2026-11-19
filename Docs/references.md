# 設計根拠と参考資料

Rev0.8 / 2026-11-19。本リビジョンで採用した部品と機能の仕様を検証するための参照資料を記載する。メーカーの保証仕様、プロジェクトの設計目標、未実測の推定値は区別する。

## 1. SFCのバスとメモリ形式

- [Nintendo SNES Development Manual Book I](https://floating.muncher.se/bot/manual/book1_text.pdf)：SlowROM 200ns未満、FastROM 120ns未満のアクセス要求、ROM信号、DMAタイミングの検証用。
- [SNESdev Memory map](https://snes.nesdev.org/wiki/Memory_map)：LoROM/HiROMの標準領域、WRAM優先窓、SRAM窓。
- [SNESdev Timing](https://snes.nesdev.org/wiki/Timing)：アクセスサイクルと本体バスタイミング。
- [SNESdev Cartridge connector](https://snes.nesdev.org/wiki/Cartridge_connector)：SFCコネクタ信号、音声L/R入力と割り込み。
- [SNESdev ROM file formats](https://snes.nesdev.org/wiki/ROM_file_formats)：ROMヘッダ・マッピング識別。
- [Fullsnes SNES Specifications](https://problemkaputt.de/fullsnes.htm)：LoROM/HiROM/ExROMのバンク対応とSRAM形式の照合。
- [SNES Central SHVC-LJ3M-01](https://snescentral.com/pcbboards.php?chip=SHVC-LJ3M-01)、[SHVC-1J3M-01](https://snescentral.com/pcbboards.php?chip=SHVC-1J3M-01)：HiROM/ExHiROMのSRAMデコード例。

## 2. CPLDとレベル変換

- [AGM AG256SL100製品情報](https://www.agmcn.com/product-news/1667.html)：不揮発CPLD、256 LUT/LE、80 I/O、LQFP-100、JTAG。
- [AGM CPLD Rev1.2メーカー資料](https://www.agm-micro.com/upload/userfiles/files/AG_CPLD_Rev1_2.pdf)：AG256のピン表、VDDC/VDDIO/VDDF33の3.3V推奨動作範囲、内部遅延と出力イネーブル。
- [AGM Supra開発資料](https://www.agmsemi.com/new_details_4795553.html)：AG256SL100のツールチェーンとMAX II互換開発手順。
- [TI SN74LVC8T245](https://www.ti.com/product/SN74LVC8T245)、[データシート](https://www.ti.com/lit/ds/symlink/sn74lvc8t245.pdf)：8bit双方向、VCCA 3.3V/VCCB 5V、DIR・/OE、VIHと伝搬遅延。
- [SN74LVC8T245DBR DigiKey製品情報](https://www.digikey.jp/ja/products/detail/texas-instruments/SN74LVC8T245DBR/1216671)：SSOP-24、参考単価。
- [Nexperia 74LVC245A](https://www.nexperia.com/products/analog-logic-ics/logic/buffers-inverters-transceivers/transceivers/serie/74lvc245a-74lvch245a)：5V許容入力、3.3V駆動、DIR・/OE、Ioff。
- [74LVC245APW,118 DigiKey製品情報](https://www.digikey.jp/ja/products/detail/nexperia-usa-inc/74LVC245APW-118/946691)：TSSOP-20、1個・100個単価。
- [SD Association規格](https://www.sdcard.org/downloads/pls/)：microSD SPIモードの電圧・クロック・CS条件。

AG256の資料にあるLUT/IOE遅延は内部素子の参考値であり、SFC→LVC245A→AG256→NOR A/CEのフィッティング後の総遅延ではない。256 LUT、54/80 I/Oと出力別OE制御への収容はAGM Supraで確認する。

## 3. 外部メモリ

- [Infineon S29GL064S70TFI023](https://www.infineon.com/part/S29GL064S70TFI023)：8MiB、x8、70nsランダム、15nsページ・/OE、64KiBセクタ。パラレルNORの出力有効化時間、NORプログラムとWP#/ACC制御を確認する。
- [Infineon CY62128EV30LL-45SXI](https://www.infineon.com/part/CY62128EV30LL-45SXI)：128KiB、45ns非同期SRAM、電池保持条件、CE1/CE2、/OE・/WEタイミング。
- [Microchip MCP1825S](https://www.microchip.com/en-us/product/mcp1825s)：3.3V 500mA LDO。
- [Microchip MCP6001](https://www.microchip.com/en-us/product/MCP6001)：5V RRIO DVDAC出力バッファ。
- [ST USBLC6-2](https://www.st.com/en/protection-devices/usblc6-2.html)、[ST USBLC6-4](https://www.st.com/en/protection-devices/usblc6-4.html)：USBとmicroSD ESD保護。

## 4. PSoC 5LPと周辺回路

- [CY8C5287AXI-LP095](https://www.infineon.com/part/CY8C5287AXI-LP095)、[CY8C52LP Family Datasheet](https://www.infineon.com/assets/row/public/documents/non-assigned/49/infineon-psoc5lp-cy8c52lp-datasheet-datasheet-en.pdf)：100-TQFP、72 I/O、VDDIOドメイン、GPIO、USB、DVDAC、ARM80MHz。
- [PSoC 5LP Architecture TRM](https://www.infineon.com/assets/row/public/documents/30/57/infineon-psoc5lp-architecture-trm-additionaltechnicalinformation-en.pdf)：PRTx_BYP、DSI/DR、UDB、FIFO、出力制御。
- [PSoC 5LP Registers TRM](https://www.infineon.com/assets/row/public/documents/30/57/infineon-psoc5lp-registers-trm-additionaltechnicalinformation-en.pdf)：GPIO Drive Mode、出力無効化、SIO。
- [AN81623 Digital Design Best Practices](https://www.infineon.com/assets/row/public/documents/cross-divisions/42/infineon-an81623-psoc-3-psoc-4-and-psoc-5lp-digital-design-best-practices-applicationnotes-en.pdf)：UDB/DSIタイミング、CDC、STA。
- [AN82156 Designing PSoC Creator Components with UDB Datapaths](https://www.infineon.com/assets/row/public/documents/cross-divisions/42/infineon-an82156-designing-psoc-creator-components-with-udb-datapaths-applicationnotes-en.pdf)：4byte FIFO×2、ALU・データパス。
- [AN61290 PSoC 3/5LP Hardware Design Considerations](https://www.infineon.com/assets/row/public/documents/cross-divisions/42/infineon-an61290-psoc-3-and-psoc-5lp-hardware-design-considerations-applicationnotes-en.pdf)：電源・コア・SWD、未使用端子処理。
- [AN72382 Using PSoC 3/5LP GPIO Pins](https://www.infineon.com/assets/row/public/documents/cross-divisions/42/infineon-an72382-using-psoc-3-and-psoc-5lp-gpio-pins-applicationnotes-en.pdf)：VDDIO、SIO、ポートドライブ。
- [PSoC DVDAC Component](https://www.infineon.com/assets/row/public/documents/cross-divisions/396/infineon-component-dithered-voltage-dac-dvdac-v2.0-software-module-datasheets-en.pdf)、[AN64275](https://www.infineon.com/assets/row/public/documents/cross-divisions/42/infineon-an64275-psoc-3-and-psoc-5lp-getting-more-resolution-from-8-bit-dac-applicationnotes-en.pdf)：10bit/32kHz音声評価の技術根拠。

## 5. SDK・製造

- [PVSnesLib](https://github.com/alekmaul/pvsneslib)：HiROM/SlowROMを開始点とする65C816開発環境。[snes_rules](https://github.com/alekmaul/pvsneslib/blob/master/devkitsnes/snes_rules)でビルド設定を確認する。
- [PVSnesLib ExHiROM Issue #332](https://github.com/alekmaul/pvsneslib/issues/332)：ExROM用リンカ・バンク配置を検討するための参照。
- [ares](https://github.com/ares-emulator/ares)、[bsnes](https://github.com/bsnes-emu/bsnes)、[Unicorn Engine](https://github.com/unicorn-engine/unicorn)：ROMマッピング・ARM実行のエミュレータ設計。
- [GCT MEM2075-00-140-01-A](https://www.digikey.jp/ja/products/detail/gct/MEM2075-00-140-01-A/9859614)：microSDスロット。
- [DigiKey Japan](https://www.digikey.jp/)、[Mouser Japan](https://www.mouser.jp/)：主要半導体・受動部品・コネクタの参考単価。
- [JLCPCB](https://jlcpcb.com/)、[PCBWay](https://www.pcbway.com/)：4層・1.2mm FR-4、ENIG、エッジ端子、面取り、PCBA製造条件。

## 6. 計測値と設計上の数値

PSoC経由のNOR読出し全体約210ns、アドレス往路約60ns、データ復路約50ns、往路約60nsのうちGPIOの遅延約50nsはプロジェクト内で確認した参考値である。Rev0.8はこれらのPSoC経路をSFCの高速メモリ読出しから除外する。LVC245A＋AG256＋NOR＋8T245の合成後遅延および実機FastROM 120ns適合は未測定である。

BOM単価は2026年11月の販売店調査値であり、[production.md](production.md)の1枚・100枚試算を現在の部品表の基準とする。
