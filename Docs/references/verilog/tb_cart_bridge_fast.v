`timescale 1ns/1ps
module tb_cart_bridge_fast;
reg rst_n=1,sys_clk=0,sfc_reset_n=1,sfc_romsel_n=0,sfc_rd_n=1,sfc_wr_n=1;
reg [14:0] sfc_a=0;
reg [7:0] sfc_di=0,mem_di=8'hA5;
reg host_enable=1,arm_own=0,arm_ce=0,arm_rd=0,arm_wr=0,arm_ram=0;
reg [22:0] arm_a=23'h123456;
reg [7:0] arm_d=8'h69, arm_reply=8'hAB;
reg arm_ack=0,arm_irq=0;
wire [22:0] a0,a1;
wire [7:0] md0,md1,sd0,sd1,cmd0,cmd1;
wire [6:0] c0,c1; wire q0,q1;
wire [22:0] ab; wire [7:0] db; wire [6:0] cb; wire [7:0] sb,cmdb; wire qb;
wire [22:0] pad_a=arm_own?arm_a:ab; wire [7:0] pad_d=arm_own?arm_d:db;
`define IN rst_n,sys_clk,sfc_reset_n,sfc_romsel_n,sfc_rd_n,sfc_wr_n,sfc_a,sfc_di,mem_di,host_enable,arm_own,arm_ce,arm_rd,arm_wr,arm_ram,arm_a,arm_d,arm_reply,arm_ack,arm_irq
cart_bridge old (`IN,a0,md0,sd0,c0[0],c0[1],c0[2],c0[3],c0[4],c0[5],c0[6],cmd0,q0);
cart_bridge_fast fast (`IN,a1,md1,sd1,c1[0],c1[1],c1[2],c1[3],c1[4],c1[5],c1[6],cmd1,q1);
cart_bridge_fast #(.GPIO_BYPASS(1)) bypass (`IN,ab,db,sb,cb[0],cb[1],cb[2],cb[3],cb[4],cb[5],cb[6],cmdb,qb);
always #12.5 sys_clk=~sys_clk;
task check;
begin
 #5;
 if ((a0!==a1)||(md0!==md1)||(cmd0!==cmd1)||(q0!==q1)) $fatal(1,"rev mismatch address/data/state");
 if ({c0[6:3],c0[1:0]}!=={c1[6:3],c1[1:0]}) $fatal(1,"control mismatch");
 if (c1[1] && sd0!==sd1) $fatal(1,"read data mismatch");
 if (!c1[2] && !c1[3]) $fatal(1,"dual select");
 if ((!c1[4] || !c1[5]) && c0[2]!==c1[2]) $fatal(1,"active CE mismatch");
 if ({pad_a,pad_d,cb,cmdb,qb}!=={a1,md1,c1,cmd1,q1} || (c1[1] && sb!==sd1)) $fatal(1,"BYP pad model mismatch");
end endtask
task write_reg(input [14:0] a,input [7:0] d);
begin
 sfc_a=a;sfc_di=d;sfc_rd_n=1;sfc_wr_n=0; #80;check;
 sfc_wr_n=1;#80;check;
end endtask
initial begin
 #1;rst_n=0; #50;rst_n=1;#30;check;
 sfc_a=15'h1234;sfc_rd_n=0;check;sfc_rd_n=1;check;
 sfc_romsel_n=1;check;sfc_romsel_n=0;
 write_reg(15'h3fe0,8'h35);write_reg(15'h3fe1,8'h81);
 sfc_a=15'h1234;sfc_rd_n=0;check;sfc_rd_n=1;
 sfc_wr_n=0;check;sfc_wr_n=1;check;
 sfc_a=15'h7ffc;sfc_rd_n=0;check;sfc_rd_n=1;
 write_reg(15'h3fe2,8'h81);
 sfc_a=15'h3fe3;sfc_rd_n=0;check;sfc_rd_n=1;
 arm_own=1;check;arm_ce=1;arm_rd=1;check;arm_rd=0;arm_ce=0;
 arm_ram=1;arm_wr=1;check;arm_ce=1;check;arm_ce=0;arm_wr=0;check;arm_own=0;arm_ack=1;check;
 sfc_a=15'h3fe4;sfc_rd_n=0;check;
 $display("PASS directed RTL comparison (zero delay)");$finish;
end
endmodule
