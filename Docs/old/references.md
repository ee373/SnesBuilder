# Rev.0.9 — AGM構成の設計根拠と外部資料

この一覧はAG32VF407VGT6／AGRV2KL100を採用した現行Rev.0.9の外部資料である。現行RTL、ピン配置、クロック、MMIOの一次参照先は本リポジトリの[FPGAプロジェクト](../fpga/README.md)、[top.ve](../fpga/top.ve)、[RTL](../fpga/rtl/)および[検証記録](verification/README.md)とする。

## SoC・開発環境

- [AG32VF407の公式製品ページ](https://www.ag32mcu.com/aum-product/products_mcu_ag32vf407_100/)
- [AGM開発ツール](https://www.ag32mcu.com/dev-tools-category/dev_tools_mcu/)
- [Supra Native実機開発例](https://blog.csdn.net/Naisu_kun/article/details/166950248)

## SFCバス・表示・開発

- [SNESdev Cartridge Connector](https://snes.nesdev.org/wiki/Cartridge_connector)
- [SNESdev Memory Map](https://snes.nesdev.org/wiki/Memory_map)
- [SNESdev Timing](https://snes.nesdev.org/wiki/Timing)
- [Fullsnes](https://problemkaputt.de/fullsnes.htm)
- [PVSnesLib](https://github.com/alekmaul/pvsneslib)
- [ares](https://github.com/ares-emulator/ares)

## 現行基板の周辺部品

- [Nexperia 74LVC245A](https://www.nexperia.com/products/analog-logic-ics/logic/buffers-inverters-transceivers/transceivers/serie/74lvc245a-74lvch245a)：U1～U4/U6
- [TI SN74LVC8T245データシート](https://www.ti.com/lit/ds/symlink/sn74lvc8t245.pdf)：U5
- [Infineon S29GL064S 8MiB NOR](https://www.infineon.com/part/S29GL064S70TFI023)
- 外部SRAM：**Lyontek LY62W1024SL-55SLI（128KiB、55ns）**。部品型番・ピン配列は[hardware.md](hardware.md)と[memory.md](memory.md)を参照。
- [MCP1825S 3.3V LDO](https://www.microchip.com/en-us/product/mcp1825s)
- [MCP6002オペアンプ](https://www.microchip.com/en-us/product/mcp6002)

## ソフトウェアライブラリ

- [Jet C++17ソフトウェア3Dレンダラー](https://github.com/CubeCoders/Jet)
- [cmixer PCMミキサー](https://github.com/rxi/cmixer)

回路設計・部品購入時は採用型番のメーカー最新データシートを確認する。
