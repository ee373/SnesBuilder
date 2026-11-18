`timescale 1ns/1ps
// Directed HDL test bench. Not run in the preparation environment.
module tb;
reg rst_n=1,sfc_reset_n=1,enabled=1,sys_clk=0,romsel_n=1,rd_n=1,wr_n=1;
reg [5:0] a_lo=0;
reg a12=0,a13=0,a14=0,a15=0,a21=0,a22=0,a23=0;
reg [7:0] sfc_di=0,mem_di=8'hA5,arm_reply=8'h69;
reg [1:0] bus_mode=0;
reg hi_enable=1,ex_enable=1,extension_enable=1,arm_ce=0,arm_ram=0,arm_rd=0,arm_wr=0;
reg arm_ack=0,arm_irq_mask=0,arm_irq_pending=0;
wire [7:0] sfc_do,mem_dsi_data,cmd_data;
wire [22:0] mem_dsi_addr;
wire sfc_d_oe,mem_d_oe,direct_addr_oe,bypass_addr_oe,buf_oe_n;
wire ce_rom_n,ce_ram_n,mem_oe_n,mem_we_n,irq_assert,arm_request,cmd_seq,cmd_meta,cmd_sync;
wire [1:0] cmd_kind;
sfcbuilder_bridge dut (.*);
always #12.5 sys_clk=~sys_clk;
task addr(input [23:0] a);
begin
  {a23,a22,a21}=a[23:21]; {a15,a14,a13,a12}=a[15:12]; a_lo=a[5:0];
  romsel_n= !((a[23:16]!=8'h7e && a[23:16]!=8'h7f) && (a[22] || a[15]));
end endtask
task ck(input cond,input [255:0] msg);
begin if(cond !== 1'b1) $fatal(1,"%s",msg); end endtask
task readbyte(input [23:0] a,input [7:0] expected);
begin addr(a);rd_n=0;wr_n=1;#20;ck(sfc_d_oe && sfc_do===expected,"read data");rd_n=1;#20;end endtask
task writebyte(input [23:0] a,input [7:0] data);
begin addr(a);sfc_di=data;rd_n=1;wr_n=0;#70;wr_n=1;#70;end endtask
initial begin
 #1;rst_n=0;#50;rst_n=1;#20;
 addr(24'h00ffc0);#10;ck(!ce_rom_n && mem_dsi_addr[22],"ExHiROM upper half");
 addr(24'hc00000);#10;ck(!ce_rom_n && !mem_dsi_addr[22],"ExHiROM lower half");
 readbyte(24'hc00000,8'ha5);readbyte(24'h806000,8'ha5);
 writebyte(24'h005000,8'h53);ck(arm_request && cmd_data==8'h53 && cmd_kind==0,"mailbox request");
 readbyte(24'h005001,8'h01);writebyte(24'h005000,8'hff);ck(cmd_data==8'h53,"busy reject");
 arm_ack=cmd_sync;#20;readbyte(24'h805042,8'h69);
 writebyte(24'h005003,8'h01);ck(arm_request && cmd_kind==1,"bus request");
 bus_mode=1;#30;ck(buf_oe_n && !direct_addr_oe && ce_rom_n && ce_ram_n,"isolate");
 bus_mode=3;#30;arm_ack=cmd_sync;#10;readbyte(24'h005003,8'h01);
 arm_ram=1;arm_wr=1;#20;ck(mem_d_oe && mem_we_n,"predrive");arm_ce=1;#20;ck(!mem_we_n && !ce_ram_n && mem_oe_n,"arm write");arm_ce=0;#20;arm_wr=0;
 arm_irq_pending=1;arm_irq_mask=1;#20;ck(!irq_assert,"irq suppressed");
 bus_mode=1;#30;bus_mode=0;#30;ck(irq_assert,"irq after return");
 readbyte(24'h005008,8'h01);writebyte(24'h005008,8'h01);ck(arm_request && cmd_kind==3,"irq clear request");
 arm_irq_pending=0;arm_ack=cmd_sync;#20;ck(!irq_assert,"irq cleared");
 $display("PASS directed bridge RTL tests");$finish;
end
endmodule
