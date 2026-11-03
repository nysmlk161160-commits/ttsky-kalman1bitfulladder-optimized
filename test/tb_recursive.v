`timescale 1ns/1ps
module tb_recursive;
    reg clk=0;
    always #10 clk=~clk;
    reg rst_n=0;
    reg [7:0] ui_in=0,uio_in=0;
    wire [7:0] uo_out,uio_out,uio_oe;
    tt_um_example dut(ui_in,uo_out,uio_in,uio_out,uio_oe,1'b1,clk,rst_n);
    integer fd,records,n=0,scan,reset_flag,mode,q,z,load,x,p,r,ex,ep,ec,busy;
    integer cycles,ax,ap,last_q=-1,last_r=-1,last_mode=-1;
    reg [1023:0] vector_path;
    task write_word;
        input integer addr,value,extended;
        integer upper;
        begin
            for(upper=0;upper<2;upper=upper+1) begin
                @(negedge clk);ui_in=(value>>(8*upper))&255;
                uio_in=addr|(upper<<2)|8|(extended?16:0);
                @(negedge clk);uio_in=0;
            end
        end
    endtask
    task read_word;
        input integer sel;
        output integer value;
        begin
            uio_in=sel<<5;#1;value=uo_out;
            uio_in=(sel<<5)|4;#1;value=value|((uo_out&3)<<8);
        end
    endtask
    initial begin
        $dumpfile("recursive.vcd");$dumpvars(0,tb_recursive);
        if(!$value$plusargs("VECTORS=%s",vector_path))$fatal(1,"Missing vectors");
        fd=$fopen(vector_path,"r");records=$fopen("observed.csv","w");
        if(!fd||!records)$fatal(1,"Cannot open records");
        $fdisplay(records,"case,actual_x,actual_p,cycles");
        while(!$feof(fd)) begin
            scan=$fscanf(fd,"%d %d %d %d %d %d %d %d %d %d %d %d\n",
                reset_flag,mode,q,z,load,x,p,r,ex,ep,ec,busy);
            if(scan!=12)$fatal(1,"Malformed vector");
            if(reset_flag)begin
                @(negedge clk);rst_n=0;uio_in=0;
                repeat(2)@(posedge clk);
                @(negedge clk);rst_n=1;
                if(uio_out[7:6]!==0||uio_oe!==8'hc0)$fatal(1,"Reset status");
                last_q=-1;last_r=-1;last_mode=-1;
            end
            if(load)begin write_word(1,x,0);write_word(2,p,0);end
            if(q!=last_q)begin write_word(0,q,1);last_q=q;end
            if(r!=last_r)begin write_word(3,r,0);last_r=r;end
            if(mode!=last_mode)begin write_word(1,mode,1);last_mode=mode;end
            write_word(0,z,0);
            @(negedge clk);uio_in=16;
            @(negedge clk);uio_in=0;cycles=0;
            while(uio_out[7]!==1'b1&&cycles<50)begin
                @(posedge clk);#1;cycles=cycles+1;
                if(busy&&cycles==2)begin ui_in=0;uio_in=11;end
                if(busy&&cycles==3)uio_in=0;
                if(busy&&cycles==4)begin ui_in=255;uio_in=24;end
                if(busy&&cycles==5)uio_in=0;
                if(busy&&cycles==6)begin ui_in=0;uio_in=25;end
                if(busy&&cycles==7)uio_in=0;
            end
            uio_in=0;
            read_word(0,ax);read_word(1,ap);
            $fdisplay(records,"%0d,%0d,%0d,%0d",n,ax,ap,cycles);
            if(ax!==(ex&1023)||ap!==ep||cycles!==ec)
                $fatal(1,"Stream case=%0d got=(%0d,%0d,%0d) expected=(%0d,%0d,%0d)",n,ax,ap,cycles,ex&1023,ep,ec);
            repeat(2)@(posedge clk);
            #1;if(uio_out[7:6]!==2'b10)$fatal(1,"Ready must remain asserted");
            n=n+1;
        end
        // Abort an active recursive update, then demonstrate legacy reset mode.
        @(negedge clk);uio_in=16;
        @(negedge clk);uio_in=0;
        repeat(4)@(posedge clk);
        @(negedge clk);rst_n=0;
        repeat(2)@(posedge clk);
        @(negedge clk);rst_n=1;
        if(uio_out[7:6]!==0)$fatal(1,"Abort did not reset status");
        write_word(1,0,0);write_word(2,64,0);write_word(3,64,0);write_word(0,64,0);
        repeat(2)begin
            @(negedge clk);uio_in=16;
            @(negedge clk);uio_in=0;cycles=0;
            while(uio_out[7]!==1'b1&&cycles<50)begin @(posedge clk);#1;cycles=cycles+1;end
            read_word(0,ax);read_word(1,ap);
            if(ax!==32||ap!==32)$fatal(1,"Reset failed to restore legacy non-feedback mode");
        end
        $fclose(fd);$fclose(records);
        $display("PASS: %0d recursive/protocol samples plus abort/reset/legacy checks",n);
        $finish;
    end
endmodule
