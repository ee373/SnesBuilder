`timescale 1ns/1ps
`default_nettype none
module tb_sfcbuilder_rev07;
 reg rst_n=0,sys_clk=0,sfc_reset_n=0,enabled=1;
 always #12.5 sys_clk=~sys_clk; // 40 MHz
 reg request_arm=1,host_quiesced=0,gpio_cfg_done=0;
 wire gpio_cfg_request,gpio_cfg_target_arm,owner_busy;
 wire [2:0] owner_state;
 reg boot_mode=1,extension_enable=1,hi_enable=1,ex_enable=1;
 reg exhirom_enable=1;reg [2:0] rom_blocks_m1=7;
 reg romsel_n=1,rd_n=1,wr_n=1;
 reg [4:0] sfc_a0_4=0;reg [3:0] sfc_a12_15=0,sfc_a20_23=0;
 reg [6:0] host_mem_a5_11=0;reg [3:0] host_mem_a16_19=0;
 reg [7:0] sfc_data_in=0,mem_data_in=8'ha7;
 wire [7:0] sfc_data_out,mem_data_out;
 wire sfc_data_oe,mem_data_oe,buf_oe_n;
 wire [22:0] mem_addr_out,mem_addr_oe;
 wire ce_rom_n,ce_ram_n,mem_oe_n,mem_we_n,irq_assert;
 reg [22:0] arm_mem_addr=0;reg [7:0] arm_mem_wdata=0;
 reg arm_mem_ce=0,arm_mem_ram=0,arm_mem_rd=0,arm_mem_wr=0;
 wire [7:0] cmd_data,arm_tx_data,fifo_status;
 wire [2:0] cmd_kind;
 wire arm_cmd_valid,arm_tx_valid,arm_rx_ready,boot_hit;
 reg arm_cmd_ack=0;reg [7:0] arm_reply=8'h5a;
 reg arm_irq_mask=0,arm_irq_pending=0;
 reg [7:0] arm_error=0;reg [15:0] arm_length=16'h1234;
 reg arm_tx_ready=0,arm_rx_valid=0;reg [7:0] arm_rx_data=0;
 integer checks=0,errors=0,i,blocks,ex,a19,a20,a21,a23;
 integer logical_block,expected_block,phys;
 sfcbuilder_rev07 dut(.*);
 task check;
 input cond;input [8*110-1:0] msg;
 begin checks=checks+1;if(cond!==1'b1)begin errors=errors+1;$display("FAIL %0s",msg);end end
 endtask
 task address;
 input [23:0] a;
 begin {sfc_a20_23,host_mem_a16_19,sfc_a12_15,host_mem_a5_11,sfc_a0_4}=a;end
 endtask
 task handoff;
 input target;
 integer z;
 begin
   request_arm=target;
   if(target)host_quiesced=1;
   z=0;
   while(!gpio_cfg_request && z<30) begin @(negedge sys_clk);z=z+1;end
   check(gpio_cfg_request,"gpio request should appear");
   check(owner_state==3 && ce_rom_n && ce_ram_n && mem_we_n && buf_oe_n && mem_addr_oe==0,
         "during CONFIG all memory controls isolated");
   @(negedge sys_clk);gpio_cfg_done=1;
   repeat(4) @(negedge sys_clk);gpio_cfg_done=0;
   z=0;
   while(owner_state!=(target ? 3'd2:3'd1) && z<30)begin
       @(negedge sys_clk);z=z+1;
       check(ce_rom_n && ce_ram_n && mem_we_n && buf_oe_n && mem_addr_oe==0 ||
             owner_state==(target ? 3'd2:3'd1),"no pre-ack bus drive");
   end
   check(owner_state==(target ? 3'd2:3'd1),"ownership transition completed");
 end
 endtask
 task host_read;
 input [23:0] a;input [7:0] expected;
 begin
   address(a);romsel_n=0;rd_n=0;wr_n=1;#4;
   check(sfc_data_oe && sfc_data_out===expected,"host read matches");
   rd_n=1;#30;
 end
 endtask
 task io_write;
 input [4:0] off;input [7:0] value;
 begin address(24'h005000 | off);romsel_n=1;sfc_data_in=value;
 rd_n=1;wr_n=0;#80;wr_n=1;#100;end
 endtask
 task rx_read;
 input [7:0] val;
 begin address(24'h005005);romsel_n=1;wr_n=1;rd_n=0;#15;
 check(sfc_data_oe && sfc_data_out===val,"RX read returns prefetch byte");
 rd_n=1;#100;end
 endtask
 function integer mirror;
 input integer pos;input integer size;
 integer window,power,offset,remain,work;
 begin
 window=1;while(window<size)window=window*2;
 work=pos&(window-1);offset=0;remain=size;
 while(remain>0)begin
   power=1;while((power*2)<=remain)power=power*2;
   if(work<power)begin offset=offset+work;remain=0;end
   else begin
    offset=offset+power;remain=remain-power;
    window=1;while(window<remain)window=window*2;
    work=pos&(window-1);
   end
 end
 mirror=offset;
 end endfunction
 initial begin
 #35;rst_n=1;#20;
 check(owner_busy && ce_rom_n && ce_ram_n && mem_addr_oe==0,"reset safe isolated");
 handoff(1);
 arm_mem_addr=23'h745321;arm_mem_wdata=8'hd2;
 arm_mem_ce=1;arm_mem_ram=0;arm_mem_wr=1;#3;
 check(owner_state==2 && mem_addr_out==arm_mem_addr && mem_addr_oe==23'h7fffff,
       "ARM drives all address bits");
 check(!ce_rom_n && ce_ram_n && !mem_we_n && mem_data_oe,"ARM NOR write gated by owner");
 arm_mem_ce=0;arm_mem_wr=0;
 handoff(0);sfc_reset_n=1;
 host_read(24'h00fffc,8'h00);host_read(24'h00fffd,8'h80);
 host_read(24'h008000,8'h5c);host_read(24'h008001,8'h00);
 host_read(24'h008002,8'h60);host_read(24'h008003,8'h2f);
 check(ce_rom_n,"boot NOR never selected");
 address(24'h018000);romsel_n=0;rd_n=0;#5;
 check(!boot_hit && !sfc_data_oe,"boot response bank00 only");rd_n=1;
 address(24'h2f6000);romsel_n=1;rd_n=0;#5;
 check(!ce_ram_n && ce_rom_n && sfc_data_out==8'ha7,"BIOS SRAM accessible during boot");
 check(host_mem_a16_19==4'hf && mem_addr_oe[19]==0,"BIOS SRAM high bits from 3SB");rd_n=1;
 boot_mode=0;address(24'hc00000);romsel_n=0;rd_n=0;#5;
 check(!ce_rom_n && sfc_data_out==8'ha7,"regular ROM returns after boot");rd_n=1;
 for(ex=0;ex<2;ex=ex+1)begin
   exhirom_enable=ex;
   for(blocks=1;blocks<=(ex?8:4);blocks=blocks+1)begin
   rom_blocks_m1=blocks-1;
   for(a23=0;a23<2;a23=a23+1)
   for(a21=0;a21<2;a21=a21+1)
   for(a20=0;a20<2;a20=a20+1)
   for(a19=0;a19<2;a19=a19+1)begin
       address({a23[0],1'b1,a21[0],a20[0],a19[0],19'd0});
       // use separately assigned pins so low address structure stays valid
       sfc_a20_23={a23[0],1'b1,a21[0],a20[0]};
       host_mem_a16_19[3]=a19[0];
       #1;
       logical_block=((1-a23)*ex*4)+(a21*2)+a20;
       expected_block=mirror(logical_block,blocks);
       phys=mem_addr_out[22:20];
       check(phys==expected_block && mem_addr_out[19]==a19[0],"mirror model and A19");
   end end end
 end
 // host mailbox and protected ownership handoff
 romsel_n=1;io_write(5'h00,8'hb4);#40;
 check(arm_cmd_valid && cmd_data==8'hb4 && cmd_kind==0,"command toggled into ARM domain");
 io_write(5'h00,8'h11);#20;
 check(cmd_data==8'hb4,"BUSY blocks overwrite");
 arm_cmd_ack=1;#50;arm_cmd_ack=0;#50;
 check(!arm_cmd_valid,"command ack clears pending");
 io_write(5'h09,8'h12);#60;
 check(arm_cmd_valid && cmd_kind==4 && cmd_data==8'h12,"LENGTH_LO kind 4");
 arm_cmd_ack=1;#50;arm_cmd_ack=0;#50;
 // TX: in sys_clk domain and keeps FULL/EMPTY up to date at idle.
 io_write(5'h04,8'h6e);#50;
 check(arm_tx_valid && arm_tx_data==8'h6e,"TX data visible");
 arm_tx_ready=1;#50;arm_tx_ready=0;#40;
 check(!arm_tx_valid,"TX empty after ARM consumption without SFC writes");
 // RX: prefetch data is stable before falling /RD, pops only after rising /RD
 @(negedge sys_clk);arm_rx_data=8'h9c;arm_rx_valid=1;
 @(negedge sys_clk);arm_rx_valid=0;#40;
 rx_read(8'h9c);
 check(fifo_status[2],"RX empty updated with no additional SFC read clock");
 // A naked owner request does not revoke host until WRAM quiescence.
 host_quiesced=0;request_arm=1;repeat(6) @(negedge sys_clk);
 check(owner_state==1 && !owner_busy,"host ownership retained until quiesced");
 // no memory access under reconfiguration
 host_quiesced=1;handoff(1);
 check(!irq_assert && buf_oe_n,"host IRQ gated outside host ownership");
 // $5000 communications stay available even when ARM owns shared memory.
 address(24'h005001);romsel_n=1;rd_n=0;#5;
 check(sfc_data_oe && sfc_data_out[1] && ce_rom_n && ce_ram_n,
       "communication register accessible during ARM ownership");
 rd_n=1;
 if(errors) $fatal(1,"FAIL %0d/%0d assertions",errors,checks);
 $display("PASS Rev07 v2: %0d HDL assertions",checks);$finish;
 end
endmodule
`default_nettype wire