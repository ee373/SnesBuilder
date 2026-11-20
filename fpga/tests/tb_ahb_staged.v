`timescale 1ps/1ps

module tb_ahb_staged;
    reg sys_clk=0, bus_clk=0, fir_clk=0, dsm_clk=0;
    always #2083 sys_clk = ~sys_clk;
    always #6250 bus_clk = ~bus_clk;
    always #5208 fir_clk = ~fir_clk;
    always #62500 dsm_clk = ~dsm_clk;
    reg resetn=0, power_fail=0;
    reg [1:0] htrans=0;
    reg hwrite=0;
    reg [2:0] size=2;
    reg [31:0] address=0, write_data=0;
    wire ready, response, left_bit, right_bit;
    wire [31:0] read_data;
    reg pause_global_ready=0;
    wire global_ready=ready && !pause_global_ready;
    reg [23:0] sfc_addr=0;
    reg sfc_nrd=1, sfc_nwr=1;
    reg [7:0] sfc_write_data=0;
    reg [1:0] spi_sel=0;
    reg spi_en=1;
    wire sd_ncs, spi_ncs, ram_nce, nor_nce, mem_nwe, mem_noe, u1_noe, u6_noe;
    wire [7:0] mem_d, low_addr;
    wire [11:8] mem_hiz;
    wire [3:0] irq;
    reg [7:0] ram [0:255];
    assign mem_d = !sfc_nwr ? sfc_write_data : !ram_nce && !mem_noe ? ram[low_addr] : 8'bz;
    always @(negedge mem_nwe) begin
        #10;
        if (!ram_nce) ram[low_addr] = mem_d;
    end
    always @(negedge bus_clk) if (resetn && {spi_ncs,sd_ncs} == 0)
        $fatal(1,"Both SPI devices selected");
    sfcbuilder dut (
        .sys_clock(sys_clk), .bus_clock(bus_clk),
        .audio_fir_clock_out_data(fir_clk), .audio_fir_clock_out_en(1'b1),
        .audio_dsm_clock_out_data(dsm_clk), .audio_dsm_clock_out_en(1'b1),
        .resetn(resetn), .stop(1'b0), .POWER_FAIL(power_fail),
        .SFC_nRD(sfc_nrd), .SFC_nWR(sfc_nwr), .SFC_nROMSEL(1'b0),
        .SFC_A0(sfc_addr[0]), .SFC_A1(sfc_addr[1]), .SFC_A2(sfc_addr[2]), .SFC_A3(sfc_addr[3]), .SFC_A4(sfc_addr[4]), .SFC_A5(sfc_addr[5]), .SFC_A12(sfc_addr[12]), .SFC_A13(sfc_addr[13]), .SFC_A14(sfc_addr[14]), .SFC_A15(sfc_addr[15]), .SFC_A16(sfc_addr[16]), .SFC_A17(sfc_addr[17]), .SFC_A18(sfc_addr[18]), .SFC_A19(sfc_addr[19]), .SFC_A20(sfc_addr[20]), .SFC_A21(sfc_addr[21]), .SFC_A22(sfc_addr[22]), .SFC_A23(sfc_addr[23]), .MEM_A0(low_addr[0]), .MEM_A1(low_addr[1]), .MEM_A2(low_addr[2]), .MEM_A3(low_addr[3]), .MEM_A4(low_addr[4]), .MEM_A5(low_addr[5]), .MEM_A6(low_addr[6]), .MEM_A7(low_addr[7]), .MEM_A8(mem_hiz[8]), .MEM_A9(mem_hiz[9]), .MEM_A10(mem_hiz[10]), .MEM_A11(mem_hiz[11]), .MEM_D0(mem_d[0]), .MEM_D1(mem_d[1]), .MEM_D2(mem_d[2]), .MEM_D3(mem_d[3]), .MEM_D4(mem_d[4]), .MEM_D5(mem_d[5]), .MEM_D6(mem_d[6]), .MEM_D7(mem_d[7]),
        .spi_sel0_out_en(spi_en), .spi_sel1_out_en(spi_en),
        .spi_sel0_out_data(spi_sel[0]), .spi_sel1_out_data(spi_sel[1]),
        .MEM_nCE_RAM(ram_nce), .MEM_nCE_ROM(nor_nce), .MEM_nWE(mem_nwe), .MEM_nOE(mem_noe),
        .SD_nCS(sd_ncs), .SPI_NOR_nCS(spi_ncs), .U1_nOE(u1_noe), .U6_nOE(u6_noe), .local_int(irq),
        .mem_ahb_htrans(htrans), .mem_ahb_hready(global_ready), .mem_ahb_hwrite(hwrite),
        .mem_ahb_haddr(address), .mem_ahb_hsize(size), .mem_ahb_hburst(3'd0),
        .mem_ahb_hwdata(write_data), .mem_ahb_hreadyout(ready),
        .mem_ahb_hresp(response), .mem_ahb_hrdata(read_data),
        .DAC0_AUDIO_L(left_bit), .DAC1_AUDIO_R(right_bit)
    );

    task automatic transfer(input [31:0] addr, input wr, input [2:0] width,
                            input [31:0] data, input error_expected, output reg [31:0] result);
        reg saw_error_wait;
        begin
            @(negedge sys_clk);
            while (!ready) @(negedge sys_clk);
            {address,hwrite,size,htrans} = {addr,wr,width,2'b10};
            @(negedge sys_clk);
            {htrans,write_data} = {2'b00,data};
            saw_error_wait = 0;
            while (!ready) begin
                if (response) saw_error_wait = 1;
                @(negedge sys_clk);
            end
            if (response !== error_expected || (error_expected && !saw_error_wait))
                $fatal(1,"AHB response mismatch at %08x",addr);
            result = read_data;
        end
    endtask


    task automatic check_spi(input [1:0] selection, input bit enabled, input [1:0] pins);
        begin
            @(negedge bus_clk);
            {spi_en,spi_sel}={enabled,selection};
            repeat(4) @(negedge bus_clk);
            if ({spi_ncs,sd_ncs} !== pins) $fatal(1,"SPI selection %b",selection);
        end
    endtask
    task automatic check_fixed(input [23:0] addr,input [7:0] expected);
        begin
            sfc_addr=addr;
            sfc_nrd=0;
            #100;
            if (mem_d !== expected || !ram_nce || !nor_nce)
                $fatal(1,"Fixed BIOS %h %h",addr,mem_d);
            sfc_nrd=1;
            #100;
        end
    endtask
    task automatic sfc_write(input [5:0] offset,input [7:0] value);
        begin
            @(negedge bus_clk);
            sfc_addr=24'h005000+offset;
            sfc_write_data=value;
            sfc_nwr=0;
            repeat(6) @(negedge bus_clk);
            sfc_nwr=1;
            repeat(6) @(negedge bus_clk);
        end
    endtask
    task automatic sfc_read(input [5:0] offset,input [7:0] expected);
        begin
            @(negedge bus_clk);
            sfc_addr=24'h005000+offset;
            sfc_nrd=0;
            repeat(6) @(negedge bus_clk);
            if (mem_d !== expected) $fatal(1,"SFC register %h: %h expected %h",offset,mem_d,expected);
            sfc_nrd=1;
            repeat(6) @(negedge bus_clk);
        end
    endtask
    task automatic pipelined_sram_pair;
        begin
            @(negedge sys_clk);
            while (!ready) @(negedge sys_clk);
            {address,hwrite,size,htrans}={32'h6200000c,1'b1,3'd2,2'b10};
            @(negedge sys_clk);
            write_data=32'h12345678;
            address=32'h62000010;
            while (!ready) @(negedge sys_clk);
            if (response) $fatal(1,"First pipelined write rejected");
            @(negedge sys_clk);
            write_data=32'hdeadbeef;
            htrans=0;
            while (!ready) @(negedge sys_clk);
            if (response) $fatal(1,"Second pipelined write rejected");
        end
    endtask
    integer sys_edges=0, request_wait_edge=-1, response_capture_edge=-1;
    integer observed_requests=0, observed_ok=0, observed_error=0;
    reg before_ready, before_error, before_toggle, before_pending, before_issue;
    reg before_capture, before_global_ready;
    reg [31:0] before_response_data, before_write_data;
    always @(posedge sys_clk) if (resetn) begin
        sys_edges=sys_edges+1;
        before_ready=ready; before_error=response; before_toggle=dut.request_toggle;
        before_pending=dut.address_pending; before_issue=dut.request_issue;
        before_capture=dut.cpu_phase==dut.CPU_CAPTURE;
        before_response_data=dut.response_data;
        before_write_data=write_data;
        before_global_ready=global_ready;
        #1;
        if (before_pending) begin
            request_wait_edge=sys_edges;
            if (ready || dut.request_toggle!==before_toggle || !dut.request_issue)
                $fatal(1,"Missing whole-clock wait before issuing request");
        end
        if (before_issue) begin
            if (sys_edges!=request_wait_edge+1 || ready || dut.request_toggle===before_toggle ||
                dut.request_data!==before_write_data)
                $fatal(1,"Delayed HWDATA capture did not match its transfer");
            observed_requests=observed_requests+1;
        end
        if (before_capture) begin
            response_capture_edge=sys_edges;
            if (ready || response || read_data!==before_response_data)
                $fatal(1,"Response became visible before data preparation");
        end
        if (!before_ready && ready) begin
            if (read_data!==before_response_data ||
                (sys_edges-response_capture_edge)!=(response ? 3 : 2))
                $fatal(1,"Wrong cycles from registered HRDATA to HREADYOUT");
            if (response) begin
                if (!before_error) $fatal(1,"Missing HRESP while ready was low");
                observed_error=observed_error+1;
            end else observed_ok=observed_ok+1;
        end
        if (before_ready && before_error && !before_global_ready && (!ready || !response))
            $fatal(1,"Final ERROR was lost while global HREADY was low");
    end

    task automatic error_then_read;
        begin
            @(negedge sys_clk);
            while (!ready) @(negedge sys_clk);
            {address,hwrite,size,htrans}={32'h62000005,1'b0,3'd1,2'b10};
            @(negedge sys_clk);
            htrans=0;
            while (!(response && !ready)) @(negedge sys_clk);
            pause_global_ready=1;
            @(negedge sys_clk);
            if (!response || !ready || global_ready) $fatal(1,"Bad final ERROR response");
            repeat(3) @(negedge sys_clk);
            if (!response || !ready) $fatal(1,"ERROR should be held at final phase");
            {address,hwrite,size,htrans}={32'h62000004,1'b0,3'd2,2'b10};
            pause_global_ready=0;
            @(negedge sys_clk);
            htrans=0;
            if (ready || response) $fatal(1,"Next read saw the previous ERROR");
            while (!ready) @(negedge sys_clk);
            if (response || read_data!==32'hbeef5a44)
                $fatal(1,"Next transfer after ERROR lost");
        end
    endtask

    reg [3:0] prior_irq_sync, prior_irq_pipe;
    reg [3:0] raised_irq=0, cleared_irq=0;
    always @(posedge sys_clk) if (resetn) begin
        prior_irq_sync=dut.irq_sync;
        prior_irq_pipe=dut.irq_pipe;
        #1;
        if ({dut.irq_pipe,irq} !== {prior_irq_sync,prior_irq_pipe})
            $fatal(1,"IRQ pipeline lost or advanced a cycle");
        raised_irq=raised_irq | irq;
        cleared_irq=cleared_irq | (raised_irq & ~irq);
    end
    reg [31:0] result;
    initial begin
        #1 resetn=1;
        #1 resetn=0;
        #20000 resetn=1;
        wait(dut.cpu_active);
        pipelined_sram_pair();
        transfer(32'h6200000c,0,2,0,0,result);
        if (result!==32'h12345678) $fatal(1,"First pipelined address or data lost");
        transfer(32'h62000010,0,2,0,0,result);
        if (result!==32'hdeadbeef) $fatal(1,"Second pipelined address or data lost");
        transfer(32'h62000004,1,2,32'h11223344,0,result);
        transfer(32'h62000006,1,1,32'hbeef0000,0,result);
        transfer(32'h62000005,1,0,32'h00005a00,0,result);
        transfer(32'h62000005,1,1,32'hffffffff,1,result);
        transfer(32'h62000004,0,2,0,0,result);
        if (result!==32'hbeef5a44) $fatal(1,"SRAM lanes %h",result);
        error_then_read();
        check_spi(0,1,2'b11);
        check_spi(1,1,2'b10);
        check_spi(2,1,2'b01);
        check_spi(3,1,2'b11);
        check_spi(1,0,2'b11);
        transfer(32'h60000008,1,2,3,0,result);
        transfer(32'h60000000,1,2,32'ha9,0,result);
        wait(dut.sfc_active);
        #100;
        if ({u1_noe,u6_noe} !== 2'b01 || {mem_hiz,low_addr[7:6]} !== 6'bz)
            $fatal(1,"Ownership or address Hi-Z");
        transfer(32'h62000004,0,2,0,1,result);
        check_fixed(24'h00fffc,8'h00);
        check_fixed(24'h00fffd,8'h80);
        check_fixed(24'h008000,8'h5c);
        check_fixed(24'h008041,8'h00);
        check_fixed(24'h008082,8'h60);
        check_fixed(24'h0080c3,8'h2f);
        transfer(32'h60000008,1,2,2,0,result);
        sfc_addr=24'h008000;
        sfc_nrd=0;
        #100;
        if (nor_nce !== 0 || mem_d !== 8'bz) $fatal(1,"BOOT_MODE clear");
        sfc_nrd=1;
        transfer(32'h60001020,1,2,1,0,result);
        sfc_write(1,8'hb6);
        wait(irq[0]);
        sfc_write(0,1);
        wait(irq[1]);
        sfc_write(0,0);
        wait(!irq[1]);
        transfer(32'h60001004,0,2,0,0,result);
        if (result!==32'hb6) $fatal(1,"COMMAND %08h",result);
        transfer(32'h60001024,1,2,1,0,result);
        transfer(32'h6000100c,1,2,32'h5a,0,result);
        transfer(32'h6000100c,1,2,32'h69,1,result);
        sfc_read(3,8'h5a);
        sfc_write(9,2);
        transfer(32'h6000100c,1,2,32'h69,0,result);
        sfc_read(3,8'h69);
        sfc_write(5,8'h12);
        sfc_write(5,8'h34);
        transfer(32'h60001014,0,2,0,0,result);
        if (result!==32'h12) $fatal(1,"TX FIFO first %08h",result);
        transfer(32'h60001014,0,2,0,0,result);
        if (result!==32'h34) $fatal(1,"TX FIFO second %08h",result);
        transfer(32'h60001018,1,2,32'h56,0,result);
        transfer(32'h60001018,1,2,32'h78,0,result);
        sfc_read(6,8'h56);
        sfc_read(6,8'h78);
        power_fail=1;
        wait(irq[2] && dut.cpu_active);
        power_fail=0;
        repeat(8) @(negedge bus_clk);
        if (!irq[2] || !dut.cpu_active) $fatal(1,"Power-fail ownership lost after recovery");
        transfer(32'h62000004,0,2,0,0,result);
        if (result!==32'hbeef5a44) $fatal(1,"Power-fail SRAM read %h",result);
        transfer(32'h6000000c,1,2,32'h20,0,result);
        wait(dut.sfc_active && !irq[2]);
        @(negedge sys_clk);
        if (observed_requests<20 || observed_ok<10 || observed_error<3)
            $fatal(1,"Incomplete AHB stage coverage");
        if (raised_irq[2:0]!==3'b111 || cleared_irq[2:0]!==3'b111)
            $fatal(1,"Missing an interrupt assertion or release");
        $display("PASS all three IRQ assertions and releases through the additional stage");
        $display("PASS AHB staged data/response: %0d requests, %0d OK, %0d ERROR",observed_requests,observed_ok,observed_error);
        $display("PASS back-to-back AHB and SRAM lanes, arbitration and Hi-Z, BIOS fixed response and release, SPI decode, COMMAND/REPLY and TX/RX FIFOs, power-fail IRQ/ownership");
        $finish;
    end
    initial begin
        #30000000;
        $fatal(1,"Bus timeout owner %0d flags %b",dut.owner,irq);
    end
endmodule
