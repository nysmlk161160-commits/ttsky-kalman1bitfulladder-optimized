`timescale 1ns/1ps
module tb_core_bounded;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0,ds=0,ms=0,capture_s=0;
 reg [13:0] p=0;reg [14:0] s=0;
 reg [10:0] a=0;reg signed [14:0] b=0;
 wire [10:0] gain;wire signed [14:0] product;wire dd,md;
 wire div_running,mul_running,div_trial_msb,no_borrow;
 wire [14:0] denominator,remainder,next_remainder;
 wire [26:0] work_product;
 wire [25:0] next_product;
 wire [15:0] div_addend,mul_addend,sum;
 kalman_div16 div_dut (
  .clk(clk), .rst_n(rst_n), .start(ds), .p(p), .denominator(denominator),
  .remainder(remainder), .difference(sum[14:0]), .no_borrow(no_borrow),
  .trial_msb(div_trial_msb), .addend(div_addend), .next_remainder(next_remainder),
  .result(gain), .running(div_running), .done(dd)
 );
 kalman_mul16 mul_dut (
  .clk(clk), .rst_n(rst_n), .start(ms), .b(b), .product(work_product),
  .sum(sum), .addend(mul_addend), .next_product(next_product), .result(product),
  .running(mul_running), .done(md)
 );
 kalman_shared_datapath datapath (
  .clk(clk), .rst_n(rst_n), .capture_s(capture_s), .s_next(s), .div_start(ds),
  .div_running(div_running), .p(p), .div_trial_msb(div_trial_msb),
  .div_addend(div_addend), .next_remainder(next_remainder), .mul_start(ms),
  .mul_running(mul_running), .gain(a), .mul_addend(mul_addend),
  .next_product(next_product), .denominator(denominator), .remainder(remainder),
  .product(work_product), .sum(sum), .no_borrow(no_borrow)
 );
 integer fd,scan,pi,ri,ai,bi,expected,cycles,dc=0,mc=0;
 initial begin
  repeat(2) @(negedge clk);rst_n=1;
  fd=$fopen("divider_vectors.txt","r");if(!fd)$fatal(1,"divider vectors missing");
  while(!$feof(fd)) begin
   scan=$fscanf(fd,"%d %d %d\n",pi,ri,expected);if(scan!=3)$fatal(1,"bad divider row");
   // Capture S one edge before loading P, as in the top-level schedule.
   @(negedge clk);p=pi;s=pi+ri;capture_s=1;
   @(negedge clk);capture_s=0;ds=1;
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
