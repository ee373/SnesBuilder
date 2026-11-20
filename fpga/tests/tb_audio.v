`timescale 1ps/1ps

module tb_audio;
    reg sys_clk=0, bus_clk=0, fir_clk=0, dsm_clk=0;
    always #2083 sys_clk = ~sys_clk;
    always #6250 bus_clk = ~bus_clk;
    always @(bus_clk) fir_clk = bus_clk;
    always #62500 dsm_clk = ~dsm_clk;
    reg resetn=0, power_fail=0;
    reg [1:0] htrans=0;
    reg hwrite=0;
    reg [2:0] size=2;
    reg [31:0] address=0, write_data=0;
    wire ready, response, left_bit, right_bit;
    wire [31:0] read_data;
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

    function integer ramp(input integer a, b, phase, divisor);
        integer numerator;
        begin
            numerator = (b-a)*phase;
            ramp = a + (numerator < 0 ? -((-numerator+divisor-1)/divisor) :
                        numerator/divisor);
        end
    endfunction

    function integer rounded(input integer sum);
        integer divided;
        begin
            divided = (sum+1024) >>> 11;
            rounded = divided < -262144 ? -262144 : divided > 262143 ? 262143 : divided;
        end
    endfunction


    integer h[0:40];
    integer hist_l[0:8],hist_r[0:8];
    integer i,j,index,sum_l,sum_r,fir_checks=0,pcm_checks=0;
    reg [15:0] fifo_l,fifo_r;
    function integer clip_q11(input integer x);
        integer y;
        begin
            y=(x+512)>>>10;
            clip_q11=y < -65536 ? -65536 : y>65535 ? 65535 : y;
        end
    endfunction
    initial begin
        h[0]=0;
        h[1]=-15;
        h[2]=-20;
        h[3]=-10;
        h[4]=17;
        h[5]=59;
        h[6]=141;
        h[7]=196;
        h[8]=203;
        h[9]=145;
        h[10]=20;
        h[11]=-166;
        h[12]=-337;
        h[13]=-431;
        h[14]=-384;
        h[15]=-162;
        h[16]=230;
        h[17]=736;
        h[18]=1262;
        h[19]=1695;
        h[20]=1941;
        h[21]=1941;
        h[22]=1695;
        h[23]=1262;
        h[24]=736;
        h[25]=230;
        h[26]=-162;
        h[27]=-384;
        h[28]=-431;
        h[29]=-337;
        h[30]=-166;
        h[31]=20;
        h[32]=145;
        h[33]=203;
        h[34]=196;
        h[35]=141;
        h[36]=59;
        h[37]=17;
        h[38]=-10;
        h[39]=-20;
        h[40]=-15;
        for(j=0;j<9;j=j+1) begin hist_l[j]=0; hist_r[j]=0; end
    end
    always @(negedge fir_clk) if (resetn) begin
        if (dut.audio.fir_tick==1 && !dut.audio.frame_playing)
            for(i=0;i<9;i=i+1) begin hist_l[i]=0; hist_r[i]=0; end
        if (dut.audio.fir_tick==1 && dut.audio.frame_playing && dut.audio.pcm_phase==0) begin
            for(i=8;i>0;i=i-1) begin hist_l[i]=hist_l[i-1]; hist_r[i]=hist_r[i-1]; end
            hist_l[0]=dut.audio.pcm_taken ? $signed(dut.audio.pcm[15:0]) : 0;
            hist_r[0]=dut.audio.pcm_taken ? $signed(dut.audio.pcm[31:16]) : 0;
            if (dut.audio.pcm_taken) begin
                fifo_l=pcm_checks*3073-30000;
                fifo_r=20000-pcm_checks*2003;
                if (pcm_checks>=64 || dut.audio.pcm !== {fifo_r,fifo_l})
                    $fatal(1,"FIFO order mismatch");
                pcm_checks=pcm_checks+1;
            end
        end
        if (dut.audio.fir_tick==244 && dut.audio.frame_playing) begin
            sum_l=0; sum_r=0;
            for(i=0;i<9;i=i+1) begin
                index=5*i+dut.audio.pcm_phase;
                if (index<=40) begin
                    sum_l=sum_l+h[index]*hist_l[i];
                    sum_r=sum_r+h[index]*hist_r[i];
                end
            end
            if ($signed(dut.audio.filtered_l) !== clip_q11(sum_l) ||
                $signed(dut.audio.filtered_r) !== clip_q11(sum_r))
                $fatal(1,"Fused convolution mismatch at frame %0d got %0d/%0d expect %0d/%0d",
                    fir_checks,$signed(dut.audio.filtered_l),$signed(dut.audio.filtered_r),
                    clip_q11(sum_l),clip_q11(sum_r));
            fir_checks=fir_checks+1;
        end
        if (dut.audio.filter_full) $fatal(1,"FIR/DSM clock cadence overflow");
    end


    integer dsm_checks=0;
    always @(negedge dsm_clk) if (dut.audio.dsm_started) begin
        if (dut.audio.dsm_l !== (dut.audio.filter_taken ? dut.audio.filtered[16:0] : 17'd0) ||
            dut.audio.dsm_r !== (dut.audio.filter_taken ? dut.audio.filtered[33:17] : 17'd0))
            $fatal(1,"Sample hold mismatch");
        dsm_checks=dsm_checks+1;
    end

    reg [31:0] result;
    reg [15:0] sample_l, sample_r;
    integer frame;
    reg mmio_ok=0;
    initial begin
        #1 resetn=1;
        #1 resetn=0;
        #20000 resetn=1;
        transfer(32'h60002004,0,2,0,0,result);
        if (result !== 0) $fatal(1,"FIFO reset state");
        transfer(32'h60002000,0,2,0,1,result);
        transfer(32'h60002004,1,2,0,1,result);
        transfer(32'h60002000,1,1,0,1,result);
        for (frame=0; frame<64; frame=frame+1) begin
            sample_l = frame*3073-30000;
            sample_r = 20000-frame*2003;
            transfer(32'h60002000,1,2,{sample_r,sample_l},0,result);
        end
        transfer(32'h60002004,0,2,0,0,result);
        if (result !== 32'hc0) $fatal(1,"FIFO did not become full");
        transfer(32'h60002000,1,2,32'h12345678,1,result);
        transfer(32'h60002008,1,2,1,0,result);
        transfer(32'h60002008,0,2,0,0,result);
        if (result !== 1) $fatal(1,"Audio enable was not latched");
        repeat (9000) @(negedge dsm_clk);
        transfer(32'h60002004,0,2,0,0,result);
        if (result !== 32'h100) $fatal(1,"Underrun did not latch");
        power_fail=1;
        repeat (5) @(negedge dsm_clk);
        transfer(32'h60002008,0,2,0,0,result);
        if (result !== 0 || left_bit !== 0 || right_bit !== 0)
            $fatal(1,"Power fail did not stop the output");
        mmio_ok=1;
    end

    // Independent DC/duty cycle check of the 1-bit quantizer, including
    // transitions across full-scale endpoints and recovery to silence.
    reg signed [16:0] dc=0;
    reg dc_enable=0;
    wire dc_bit;
    sfcbuilder_audio_dsm dc_mod(dsm_clk,resetn,dc_enable,{dc,2'b0},dc_bit);
    task automatic test_dc(input signed [16:0] value,input integer desired);
        integer n, ones;
        begin
            @(negedge dsm_clk);
            dc = value;
            repeat (2048) @(negedge dsm_clk);
            ones=0;
            for(n=0;n<32768;n=n+1) begin
                @(negedge dsm_clk);
                if (dc_bit === 1) ones = ones+1;
                else if (dc_bit !== 0) $fatal(1,"Unknown DSM output");
            end
            if (ones < desired-8 || ones > desired+8)
                $fatal(1,"Unexpected DSM density %0d out of 32768",ones);
        end
    endtask
    initial begin
        wait(resetn);
        repeat (6) @(negedge dsm_clk);
        dc_enable=1;
        test_dc(17'sd0,16384);
        test_dc(17'sd65535,24576);
        test_dc(-17'sd65536,8192);
        test_dc(17'sd0,16384);
        if (!mmio_ok || pcm_checks != 64 || fir_checks < 320 || dsm_checks < 8000)
            $fatal(1,"Audio end-to-end coverage was incomplete");
        $display("PASS AHB/FIFO/power-fail, %0d FIR frames, %0d held DSM ticks and 4 density checks",
                 fir_checks,dsm_checks);
        $finish;
    end
    initial begin
        #25000000000;
        $fatal(1,"Simulation timed out");
    end
endmodule
