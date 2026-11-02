`timescale 1ns / 1ps

// Self-checking RTL test for the unchanged Tiny Tapeout interface.
// Vectors contain Python integer-reference outputs, not RTL-derived outputs.
module tb_digit_serial;
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst_n = 0;
    reg ena = 1;
    reg [7:0] ui_in = 0;
    reg [7:0] uio_in = 0;
    wire [7:0] uo_out, uio_out, uio_oe;
    tt_um_example dut (
        .clk(clk), .rst_n(rst_n), .ena(ena), .ui_in(ui_in),
        .uio_in(uio_in), .uo_out(uo_out), .uio_out(uio_out), .uio_oe(uio_oe)
    );

    integer fd, scan, case_index, cycles, normal_cycles, shortcut_cycles;
    integer normal_count = 0, shortcut_count = 0;
    integer z, x, p, r, expected_x, expected_p, actual_x, actual_p;
    integer expected_cycles, normal_seen = -1, shortcut_seen = -1;
    reg [1023:0] vector_path;

    task write_value;
        input [1:0] address;
        input [9:0] value;
        integer upper;
        begin
            for (upper = 0; upper < 2; upper = upper + 1) begin
                @(negedge clk);
                ui_in = (value >> (8 * upper)) & 255;
                uio_in = address | (upper << 2) | 8;
                @(negedge clk);
                uio_in = 0;
            end
        end
    endtask

    task read_value;
        input integer select_p;
        output integer value;
        begin
            uio_in = select_p << 5;
            #1;
            value = uo_out;
            uio_in = (select_p << 5) | 4;
            #1;
            value = value | ((uo_out & 3) << 8);
        end
    endtask

    initial begin
        if (!$value$plusargs("VECTORS=%s", vector_path))
            $fatal(1, "Missing +VECTORS=path");
        if (!$value$plusargs("NORMAL_CYCLES=%d", normal_cycles))
            $fatal(1, "Missing expected normal cycles");
        if (!$value$plusargs("SHORTCUT_CYCLES=%d", shortcut_cycles))
            $fatal(1, "Missing expected shortcut cycles");
        fd = $fopen(vector_path, "r");
        if (fd == 0) $fatal(1, "Cannot open vectors");
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1;
        #1;
        if (uio_oe !== 8'hc0) $fatal(1, "Unexpected I/O directions");
        case_index = 0;
        while (!$feof(fd)) begin
            scan = $fscanf(fd, "%d %d %d %d %d %d\n", z, x, p, r, expected_x, expected_p);
            if (scan != 6) $fatal(1, "Invalid vector at index %0d", case_index);
            write_value(0, z[9:0]);
            write_value(1, x[9:0]);
            write_value(2, p[9:0]);
            write_value(3, r[9:0]);
            @(negedge clk);
            uio_in = 16;
            @(negedge clk);
            uio_in = 0;
            cycles = 0;
            // Same start-pulse end / rising-edge +1 ns observation as test.py.
            while ((uio_out[7] !== 1'b1) && cycles < 340) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
            end
            if (uio_out[7] !== 1'b1) $fatal(1, "Timeout at case %0d", case_index);
            expected_cycles = ((p + r == 0) || (r == 0)) ? shortcut_cycles : normal_cycles;
            if (cycles != expected_cycles)
                $fatal(1, "Latency case %0d: got %0d expected %0d", case_index, cycles, expected_cycles);
            if (expected_cycles == normal_cycles) begin
                normal_count = normal_count + 1;
                normal_seen = cycles;
            end else begin
                shortcut_count = shortcut_count + 1;
                shortcut_seen = cycles;
            end
            read_value(0, actual_x);
            read_value(1, actual_p);
            if (actual_x != expected_x || actual_p != expected_p)
                $fatal(1, "Case %0d z=%0d x=%0d p=%0d r=%0d: got (%0d,%0d) expected (%0d,%0d)",
                    case_index, z, x, p, r, actual_x, actual_p, expected_x, expected_p);
            case_index = case_index + 1;
        end
        $fclose(fd);
        $display("PASS: %0d interface vectors; normal=%0d cases at %0d cycles; shortcut=%0d cases at %0d cycles",
            case_index, normal_count, normal_seen, shortcut_count, shortcut_seen);
        $finish;
    end
endmodule
