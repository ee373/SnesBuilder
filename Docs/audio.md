# Rev.0.9 追加ステレオPCM音声

AG32内蔵10bit DAC0 PIN29→LPF→MCP6002左→SFC外部AUDIO L端子31、DAC1 PIN30→LPF→MCP6002右→SFC外部AUDIO R端子62を採用する。初期目標は10bit/32kHzステレオPCM。RISC-VのPCM生成/復号・ソフトウェアミキサー・内部SRAM・タイマー/DMAで左右を駆動する。SFC標準SPC700/S-DSPの8chは消費しない。LPF/DCカット/音量・ノイズ・左右クロストーク・SFC入力負荷・ポップノイズを試作で測定する。
