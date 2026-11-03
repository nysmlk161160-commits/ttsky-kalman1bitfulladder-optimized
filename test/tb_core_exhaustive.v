`timescale 1ns/1ps
module tb_core_exhaustive;
    reg [9:0] p=0;
    reg [10:0] s=0;
    reg [6:0] a=0;
    reg signed [10:0] b=0;
    wire [6:0] gain;
    wire signed [10:0] product;
    kalman_direct_gain div_dut(p,s,gain);
    kalman_direct_scale mul_dut(a,b,product);
    integer pi,ri,ai,bi,expected,dc=0,mc=0;
    initial begin
        for(pi=0;pi<1024;pi=pi+1) begin
            for(ri=0;ri<1024;ri=ri+1) begin
                p=pi; s=pi+ri; #1;
                expected=(pi+ri) ? (64*pi)/(pi+ri) : 0;
                if(gain !== expected)
                    $fatal(1,"DIV p=%0d r=%0d actual=%0d expected=%0d",pi,ri,gain,expected);
                dc=dc+1;
            end
        end
        for(ai=0;ai<=64;ai=ai+1) begin
            for(bi=-1024;bi<1024;bi=bi+1) begin
                a=ai; b=bi; #1;
                expected=(ai*bi) >>> 6;
                if($signed(product) !== expected)
                    $fatal(1,"MUL a=%0d b=%0d actual=%0d expected=%0d",ai,bi,$signed(product),expected);
                mc=mc+1;
            end
        end
        $display("PASS: exhaustive divider=%0d multiplier=%0d",dc,mc);
        $finish;
    end
endmodule
