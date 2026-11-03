`timescale 1ns/1ps
module tb_core_exhaustive;
    reg clk=0;
    always #5 clk=~clk;
    reg rst_n=0, ds=0, ms=0;
    reg [9:0] p=0;
    reg [10:0] s=0;
    reg [6:0] a=0;
    reg signed [10:0] b=0;
    wire [6:0] gain;
    wire signed [10:0] product;
    wire dd,md;
    kalman_div12 div_dut(clk,rst_n,ds,p,s,gain,dd);
    kalman_mul12 mul_dut(clk,rst_n,ms,a,b,product,md);
    integer pi,ri,ai,bi,cycles,expected,dc=0,mc=0;
    initial begin
        repeat(2) @(negedge clk);
        rst_n=1;
        // Every valid P/R input combination, including both shortcut cases.
        for(pi=0;pi<1024;pi=pi+1) begin
            for(ri=0;ri<1024;ri=ri+1) begin
                @(negedge clk); p=pi; s=pi+ri; ds=1;
                @(negedge clk); ds=0; cycles=0;
                while(!dd && cycles<10) begin
                    @(posedge clk); #1; cycles=cycles+1;
                end
                expected=(pi+ri) ? (64*pi)/(pi+ri) : 0;
                if(gain !== expected || !dd ||
                   cycles !== ((ri==0) ? 0 : 6))
                    $fatal(1,"DIV p=%0d r=%0d actual=%0d expected=%0d cycles=%0d",pi,ri,gain,expected,cycles);
                dc=dc+1;
            end
        end
        // All supported gains and all signed 11-bit operands.
        for(ai=0;ai<=64;ai=ai+1) begin
            for(bi=-1024;bi<1024;bi=bi+1) begin
                @(negedge clk); a=ai; b=bi; ms=1;
                @(negedge clk); ms=0; cycles=0;
                while(!md && cycles<10) begin
                    @(posedge clk); #1; cycles=cycles+1;
                end
                // Arithmetic right shift implements floor for negative values.
                expected=(ai*bi) >>> 6;
                if($signed(product) !== expected || !md || cycles!==7)
                    $fatal(1,"MUL a=%0d b=%0d actual=%0d expected=%0d cycles=%0d",ai,bi,$signed(product),expected,cycles);
                mc=mc+1;
            end
        end
        $display("PASS: exhaustive divider=%0d multiplier=%0d",dc,mc);
        $finish;
    end
endmodule
