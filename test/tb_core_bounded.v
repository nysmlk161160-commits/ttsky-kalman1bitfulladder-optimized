`timescale 1ns/1ps
module tb_core_bounded;
 reg clk=0;always #8.333 clk=~clk;
 reg rst_n=0,ds=0,ms=0;
 reg [13:0] p=0;reg [14:0] s=0;
 reg [10:0] a=0;reg signed [14:0] b=0;
 wire [10:0] gain;wire signed [14:0] product;wire dd,md;
 kalman_div16 div_dut(clk,rst_n,ds,p,s,gain,dd);
 kalman_mul16 mul_dut(clk,rst_n,ms,a,b,product,md);
 integer fd,scan,pi,ri,ai,bi,expected,cycles,dc=0,mc=0;
 initial begin
  repeat(2) @(negedge clk);rst_n=1;
  fd=$fopen("divider_vectors.txt","r");if(!fd)$fatal(1,"divider vectors missing");
  while(!$feof(fd)) begin
   scan=$fscanf(fd,"%d %d %d\n",pi,ri,expected);if(scan!=3)$fatal(1,"bad divider row");
   @(negedge clk);p=pi;s=pi+ri;ds=1;
   @(negedge clk);ds=0;cycles=0;
   while(!dd && cycles<16) begin @(posedge clk);#1;cycles=cycles+1;end
   if(gain!==expected || !dd || cycles!==((ri==0)?0:10))$fatal(1,"DIV p=%0d r=%0d gain=%0d exp=%0d cycles=%0d",pi,ri,gain,expected,cycles);
   dc=dc+1;
  end
  $fclose(fd);fd=$fopen("multiplier_vectors.txt","r");if(!fd)$fatal(1,"multiplier vectors missing");
  while(!$feof(fd)) begin
   scan=$fscanf(fd,"%d %d %d\n",ai,bi,expected);if(scan!=3)$fatal(1,"bad multiplier row");
   @(negedge clk);a=ai;b=bi;ms=1;
   @(negedge clk);ms=0;cycles=0;
   while(!md && cycles<16) begin @(posedge clk);#1;cycles=cycles+1;end
   if($signed(product)!==expected || !md || cycles!==11)$fatal(1,"MUL a=%0d b=%0d actual=%0d exp=%0d cycles=%0d",ai,bi,$signed(product),expected,cycles);
   mc=mc+1;
  end
  $fclose(fd);$display("PASS: bounded divider=%0d multiplier=%0d",dc,mc);$finish;
 end
endmodule
