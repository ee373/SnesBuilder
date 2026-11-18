`timescale 1ns/1ps
module tb_rom_mirror_1m;
    reg sfc_a19, sfc_a20, sfc_a21, sfc_a23;
    reg exhirom_enable, host_ram;
    reg [2:0] rom_blocks_m1;
    wire [3:0] mem_a22_a19;
    integer count, errors, blocks, ex, a23, a21, a20, a19, ram;
    integer logical_block, expected_block, actual_block;
    rom_mirror_1m dut (
       .sfc_a19(sfc_a19), .sfc_a20(sfc_a20), .sfc_a21(sfc_a21),
       .sfc_a23(sfc_a23), .exhirom_enable(exhirom_enable),
       .rom_blocks_m1(rom_blocks_m1), .host_ram(host_ram),
       .mem_a22_a19(mem_a22_a19)
    );
    // Reference deliberately independent of DUT bit-equations.
    // Hardware mirror fills missing power-of-two bank windows by
    // recursively repeating the last populated power-of-two segment.
    function integer reference_mirror;
       input integer addr;
       input integer size;
       integer window, power, offset, remaining, work_addr;
       begin
          window = 1;
          while (window < size) window = window << 1;
          remaining = size;
          work_addr = addr & (window - 1);
          offset = 0;
          while (remaining > 0) begin
             power = 1;
             while ((power << 1) <= remaining) power = power << 1;
             if (work_addr < power) begin
                offset = offset + work_addr;
                remaining = 0;
             end
             else begin
                offset = offset + power;
                work_addr = work_addr - power;
                remaining = remaining - power;
                window = 1;
                while (window < remaining) window = window << 1;
                work_addr = addr & (window - 1);
             end
          end
          reference_mirror = offset;
       end
    endfunction
    initial begin
       count=0; errors=0;
       for (ex=0; ex<=1; ex=ex+1)
       for (blocks=1; blocks<=8; blocks=blocks+1)
       for (a23=0; a23<=1; a23=a23+1)
       for (a21=0; a21<=1; a21=a21+1)
       for (a20=0; a20<=1; a20=a20+1)
       for (a19=0; a19<=1; a19=a19+1)
       for (ram=0; ram<=1; ram=ram+1) begin
          if (ex || blocks<=4) begin
             exhirom_enable=ex; rom_blocks_m1=blocks-1;
             sfc_a23=a23; sfc_a21=a21; sfc_a20=a20;
             sfc_a19=a19; host_ram=ram;
             #1;
             logical_block = ((1-a23) & ex)*4 + a21*2 + a20;
             expected_block = reference_mirror(logical_block, blocks);
             actual_block = mem_a22_a19[3:1];
             if (actual_block !== expected_block ||
                 mem_a22_a19[0] !== sfc_a19) begin
                $display("FAIL size=%0d ex=%0d a23=%0d a21=%0d a20=%0d a19=%0d ram=%0d: got upper=%b expected_block=%0d", blocks,ex,a23,a21,a20,a19,ram,mem_a22_a19,expected_block);
                errors=errors+1;
             end
             count=count+1;
          end
       end
       if (errors) $fatal(1,"FAILED: %0d/%0d",errors,count);
       $display("PASS: %0d host mapper combinations",count);
       $finish;
    end
endmodule
