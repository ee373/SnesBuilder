`timescale 1ps/1ps

module tb_nor_timing;
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
    wire nor_nce, mem_nwe, mem_noe;
    wire [7:0] mem_d;
    wire [3:0] irq;
    assign mem_d = !nor_nce && !mem_noe ? 8'ha5 : 8'bz;
    sfcbuilder dut (
        .sys_clock(sys_clk), .bus_clock(bus_clk),
        .audio_fir_clock_out_data(fir_clk), .audio_fir_clock_out_en(1'b1),
        .audio_dsm_clock_out_data(dsm_clk), .audio_dsm_clock_out_en(1'b1),
        .resetn(resetn), .stop(1'b0), .POWER_FAIL(power_fail),
        .SFC_nRD(1'b1), .SFC_nWR(1'b1), .SFC_nROMSEL(1'b1),
        .spi_sel0_out_en(1'b0), .spi_sel1_out_en(1'b0),
        .mem_ahb_htrans(htrans), .mem_ahb_hready(ready), .mem_ahb_hwrite(hwrite),
        .mem_ahb_haddr(address), .mem_ahb_hsize(size), .mem_ahb_hburst(3'd0),
        .mem_ahb_hwdata(write_data), .mem_ahb_hreadyout(ready),
        .mem_ahb_hresp(response), .mem_ahb_hrdata(read_data),
        .MEM_nCE_ROM(nor_nce), .MEM_nWE(mem_nwe), .MEM_nOE(mem_noe),
        .MEM_D7(mem_d[7]), .MEM_D6(mem_d[6]), .MEM_D5(mem_d[5]), .MEM_D4(mem_d[4]),
        .MEM_D3(mem_d[3]), .MEM_D2(mem_d[2]), .MEM_D1(mem_d[1]), .MEM_D0(mem_d[0]),
        .local_int(irq), .DAC0_AUDIO_L(left_bit), .DAC1_AUDIO_R(right_bit)
    );


    integer fd, scenario = -1, rejected = 0, succeeded = 0, word_write;
    integer lane_index, step;
    reg logging = 0, pulse_was_active = 0;
    always @(bus_clk) begin
        #2;
        if (logging) begin
            $fwrite(fd, "%0d %b %b %b %b %b %b %b %h %h\n", scenario, bus_clk,
                    nor_nce,mem_nwe,mem_noe,ready,response,irq,dut.cpu_address,mem_d);
            if ((!mem_nwe || !mem_noe) && !pulse_was_active && dut.power_service)
                $fatal(1,"New memory strobe after synchronized power fail");
            pulse_was_active = !mem_nwe || !mem_noe;
        end else pulse_was_active = 0;
    end
    task automatic run_case(input bit wr, input integer target_lane, input integer offset);
        bit first_error;
        begin
            scenario = scenario + 1;
            #1;
            resetn=1;
            #2;
            resetn=0; power_fail=0; htrans=0;
            repeat(6) @(negedge bus_clk);
            #1 resetn=1;
            wait (dut.cpu_active);
            @(negedge sys_clk);
            logging=1;
            address=32'h61000000;
            hwrite=wr;
            htrans=2'b10;
            @(negedge sys_clk);
            htrans=0;
            write_data=32'h4321a5e8;
            first_error=0;
            fork
                begin
                    if (target_lane>=0) begin
                        wait(dut.phase==3 && dut.lane==target_lane);
                        #(offset) power_fail=1;
                    end
                end
                begin
                    while (!ready) begin
                        if (response) first_error=1;
                        @(negedge sys_clk);
                    end
                    if (response && !first_error) $fatal(1,"Missing first AHB ERROR cycle");
                    if (!response && !wr && read_data!==32'ha5a5a5a5)
                        $fatal(1,"Incorrect normal NOR read");
                    if (target_lane<0 && response) $fatal(1,"Normal NOR transfer failed");
                    if (response) rejected=rejected+1;
                    else succeeded=succeeded+1;
                    $fwrite(fd,"AHB %0d %t %b %h\n",scenario,$time,response,read_data);
                end
            join
            repeat(6) @(negedge bus_clk);
            #3 logging=0;
            if (target_lane>=0 && irq[2] !== 1) $fatal(1,"Power-fail IRQ missing");
        end
    endtask
    initial begin
        fd=$fopen("nor_trace.txt","w");
        if(!fd) $fatal(1,"Cannot open trace");
        for (word_write=0; word_write<2; word_write=word_write+1) begin
            run_case(word_write,-1,0);
            for(lane_index=0; lane_index<4; lane_index=lane_index+1)
                for(step=0; step<36; step=step+1)
                    run_case(word_write,lane_index,201+6250*step);
        end
        if (succeeded==0 || rejected==0) $fatal(1,"No success or error coverage");
        $fclose(fd);
        $display("PASS %0d NOR transactions (%0d successful, %0d AHB error)",scenario+1,succeeded,rejected);
        $finish;
    end
    initial begin
        #400000000;
        $fatal(1,"Timeout in case %0d, phase %0d, lane %0d",scenario,dut.phase,dut.lane);
    end
endmodule
