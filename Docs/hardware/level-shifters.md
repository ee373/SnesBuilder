# Rev.0.9 U1～U6レベル変換IC・3SB

74LVC245APW,118（U1–U4、U6）はTSSOP20、VCC PIN20=3.3V、GND PIN10、DIR PIN1=High（A→B）。CH0～7のA側ピンは2,3,4,5,6,7,8,9、B側ピンは18,17,16,15,14,13,12,11。未使用A入力はGND、対応B出力はNC。U2～U4の/OEはGND固定、U1/U6の/OEは3.3Vへプルアップする。

| IC | A側CH0–7 | B側CH0–7 | /OE PIN19 |
|---|---|---|---|
| U1 | SFC A11,A10,A9,A8,A7,A6,GND,GND | MEM A11,A10,A9,A8,A7,A6,NC,NC | AG32 PIN65 |
| U2 | SFC A5,A4,A3,A2,A1,A0,/RD,/WR | AG32 PIN36,35,34,33,32,31,38,39 | GND固定 |
| U3 | SFC A12,A13,A14,A15,A16,A17,A18,A19 | AG32 PIN47,46,45,44,43,42,41,40 | GND固定 |
| U4 | SFC A20,A21,A22,A23,/ROMSEL,GND,GND,GND | AG32 PIN54,53,52,51,48,NC,NC,NC | GND固定 |
| U6 | AG32 PIN55,56,57,58,59,60,GND,GND | MEM A11,A10,A9,A8,A7,A6,NC,NC | AG32 PIN66 |

U1とU6のB側CH0～5を同一MEM A11～A6へ接続する。SFC所有時にはU1だけを有効、CPU所有時にはU6だけを有効とし、切替時は両者を無効とする。AG32のアドレス出力23本はすべて通常OUTPUTとして実装する。

U5 SN74LVC8T245DBRはVCCA PIN1=5V、VCCB PIN23/24=3.3V、GND PIN11～13、SFC D0～D7→A側PIN3～10、MEM D0～D7→B側PIN21～14。DIR PIN2=SFC /RD（LowでMEM→SFC、HighでSFC→MEM）。/OE PIN22は5Vプルアップ、AG32 PIN67→N-MOSFETによるLow駆動で有効化する。AG32のMEM D0～D7はU5・NOR・SRAMと物理共通であり、FPGAの双方向出力許可を引き続き必要とする。


## 本番AG32との対応と検証

U1/U6の排他、AG32 PIN55～60のCPU所有時のみの駆動、U5の出力許可とMEM D0～D7のHi-Zは [現行RTL](../../fpga/rtl/sfcbuilder.v) と [ピン割当て](../../fpga/top.ve) を基準とする。Supra Nativeの配置配線とSTAは[検証記録](../verification/README.md)のとおり実施している。実基板では5 V側の入力電圧許容、電源断時の逆給電、バス方向切替、U1/U6/U5の競合と立上り・立下り時間を確認する。
