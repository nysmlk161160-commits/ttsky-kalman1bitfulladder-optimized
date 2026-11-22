`default_nettype none

module grouped_carry_adder_16bit (
    input wire [15:0] a, b,
    input wire cin,
    output wire [15:0] sum,
    output wire cout
);
    wire [15:0] p = a ^ b;
    wire [15:0] g = a & b;
    wire [3:0] group_p, group_g;
    wire [4:0] group_c;

    // Group boundary carries depend directly on group generate/propagate.
    // In particular, cout does not wait for the local sum carries.
    assign group_c[0] = cin;
    assign group_c[1] = group_g[0] | (group_p[0] & cin);
    assign group_c[2] = group_g[1] | (group_p[1] & group_g[0])
        | (&group_p[1:0] & cin);
    assign group_c[3] = group_g[2] | (group_p[2] & group_g[1])
        | (&group_p[2:1] & group_g[0]) | (&group_p[2:0] & cin);
    assign group_c[4] = group_g[3] | (group_p[3] & group_g[2])
        | (&group_p[3:2] & group_g[1]) | (&group_p[3:1] & group_g[0])
        | (&group_p[3:0] & cin);
    assign cout = group_c[4];

    genvar group_index;
    generate
        for (group_index = 0; group_index < 4; group_index = group_index + 1) begin : group
            localparam integer BASE = 4 * group_index;
            wire [3:0] gp = p[BASE +: 4];
            wire [3:0] gg = g[BASE +: 4];
            wire [3:0] carry;
            assign group_p[group_index] = &gp;
            assign group_g[group_index] = gg[3] | (gp[3] & gg[2])
                | (&gp[3:2] & gg[1]) | (&gp[3:1] & gg[0]);
            assign carry[0] = group_c[group_index];
            assign carry[1] = gg[0] | (gp[0] & carry[0]);
            assign carry[2] = gg[1] | (gp[1] & carry[1]);
            assign carry[3] = gg[2] | (gp[2] & carry[2]);
            assign sum[BASE +: 4] = gp ^ carry;
        end
    endgenerate
endmodule

// Restoring division. The datapath supplies the registered remainder and
// denominator, and returns the shared subtractor result and carry.
module kalman_div16 (
    input wire clk, rst_n, start,
    input wire [13:0] p,
    input wire [14:0] denominator, remainder, difference,
    input wire no_borrow,
    output wire trial_msb,
    output wire [15:0] addend,
    output wire [14:0] next_remainder,
    output wire [10:0] result,
    output reg running, done
);
    reg [9:0] quotient;
    reg equal_case;
    reg [3:0] gain_index;

    wire [15:0] trial_bits = {remainder, 1'b0};
    assign trial_msb = trial_bits[15];
    assign addend = ~{1'b0, denominator};
    assign next_remainder = no_borrow ? difference : trial_bits[14:0];
    assign result = {equal_case, quotient};

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            quotient <= 0;
            equal_case <= 0;
            gain_index <= 0;
            running <= 0;
            done <= 0;
        end else begin
            done <= 0;
            if (start) begin
                quotient <= 0;
                equal_case <= (denominator != 0 && p == denominator);
                gain_index <= 0;
                running <= (denominator != 0 && p != denominator);
                if (denominator == 0 || p == denominator)
                    done <= 1;
            end else if (running) begin
                quotient <= {quotient[8:0], no_borrow};
                if (gain_index == 9) begin
                    running <= 0;
                    done <= 1;
                end else begin
                    gain_index <= gain_index + 1'b1;
                end
            end
        end
    end
endmodule

// Serial signed multiplication. Fuse the conditional add and arithmetic
// shift using the shared adder sum and the registered product.
module kalman_mul16 (
    input wire clk, rst_n, start,
    input wire signed [14:0] b,
    input wire [26:0] product,
    input wire [15:0] sum,
    output wire [15:0] addend,
    output wire [25:0] next_product,
    output wire signed [14:0] result,
    output reg running, done
);
    reg [3:0] bit_count;

    wire [15:0] multiplicand = {b[14], b};
    assign addend = multiplicand & {16{product[0]}};
    assign next_product = {sum, product[10:1]};
    assign result = $signed(product[24:10]);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_count <= 0;
            running <= 0;
            done <= 0;
        end else begin
            done <= 0;
            if (start) begin
                bit_count <= 0;
                running <= 1;
            end else if (running) begin
                if (bit_count == 10) begin
                    running <= 0;
                    done <= 1;
                end else begin
                    bit_count <= bit_count + 1'b1;
                end
            end
        end
    end
endmodule

// One work bank and one adder service the mutually exclusive DIV/MUL
// requests. The controllers own algorithm state; the bank owns data.
module kalman_shared_datapath (
    input wire clk, rst_n,
    input wire capture_s,
    input wire [14:0] s_next,
    input wire div_start, div_running,
    input wire [13:0] p,
    input wire div_trial_msb,
    input wire [15:0] div_addend,
    input wire [14:0] next_remainder,
    input wire mul_start, mul_running,
    input wire [10:0] gain,
    input wire [15:0] mul_addend,
    input wire [25:0] next_product,
    output wire [14:0] denominator, remainder,
    output wire [26:0] product,
    output wire [15:0] sum,
    output wire no_borrow
);
    reg [29:0] work;
    assign denominator = {work[29:27], work[11:0]};
    assign remainder = work[26:12];
    // Sign extension supplies product[26] without another flop.
    assign product = {work[25], work[25:0]};

    // A[14:1] is identical in both modes by construction. Only A[15],
    // A[0], B and carry-in need mode selection.
    wire [15:0] shared_a = {
        mul_running ? product[26] : div_trial_msb,
        work[25:12],
        mul_running & product[11]
    };
    grouped_carry_adder_16bit shared_adder (
        .a(shared_a),
        .b(mul_running ? mul_addend : div_addend),
        .cin(~mul_running),
        .sum(sum), .cout(no_borrow)
    );

    // On accepted start, capture old P+R. The later div_start reads live P.
    // Keep the original ordering of writes to the overlapping bank slices.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            work <= 0;
        end else begin
            if (capture_s)
                {work[29:27], work[11:0]} <= s_next;
            if (div_start)
                work[26:12] <= {1'b0, p};
            else if (div_running)
                work[26:12] <= next_remainder;
            if (mul_start)
                work[25:0] <= {15'b0, gain};
            else if (mul_running)
                work[25:0] <= next_product;
        end
    end
endmodule

module tt_um_example (
    input wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input wire ena, clk, rst_n
);
    reg [13:0] z, x, p, r;
    reg signed [14:0] delta;
    reg [13:0] x_out, p_out;
    reg ready;
    reg [2:0] state;

    localparam IDLE=0, DIV_START=1, DIV_WAIT=2,
               X_START=3, X_WAIT=4, P_START=5,
               P_WAIT=6, FINISH=7;
    wire div_start = (state == DIV_START);
    wire mul_start = (state == X_START || state == P_START);
    wire [10:0] div_result;
    wire div_done, mul_done;
    wire signed [14:0] mul_result;
    // b is read live by the serial multiplier and remains stable during each run.
    wire signed [14:0] mul_b = (state == X_START || state == X_WAIT)
                                      ? delta : $signed({1'b0, p});

    // One shared 14-bit datapath: X + (K*delta) or P - (K*P).
    wire do_sub = (state == P_WAIT);
    wire [13:0] alu_a = do_sub ? p : x;
    wire [13:0] alu_b = mul_result[13:0] ^ {14{do_sub}};
    wire [13:0] alu_y = alu_a + alu_b + do_sub;
    wire [13:0] read_result = uio_in[5] ? p_out : x_out;

    assign uo_out = uio_in[2] ? {2'b0, read_result[13:8]} : read_result[7:0];
    assign uio_out = {ready, (state != IDLE), 6'b0};
    assign uio_oe = 8'b11000000;
    wire capture_s = (state == IDLE && uio_in[4]);
    wire [14:0] s_next = {1'b0, p} + {1'b0, r};
    wire div_running, mul_running, div_trial_msb, no_borrow;
    wire [14:0] denominator, remainder, next_remainder;
    wire [26:0] product;
    wire [25:0] next_product;
    wire [15:0] div_addend, mul_addend, shared_sum;

    kalman_div16 divider (
        .clk(clk), .rst_n(rst_n), .start(div_start), .p(p),
        .denominator(denominator), .remainder(remainder),
        .difference(shared_sum[14:0]), .no_borrow(no_borrow),
        .trial_msb(div_trial_msb), .addend(div_addend),
        .next_remainder(next_remainder), .result(div_result),
        .running(div_running), .done(div_done)
    );
    kalman_mul16 multiplier (
        .clk(clk), .rst_n(rst_n), .start(mul_start), .b(mul_b),
        .product(product), .sum(shared_sum), .addend(mul_addend),
        .next_product(next_product), .result(mul_result),
        .running(mul_running), .done(mul_done)
    );
    kalman_shared_datapath shared_work (
        .clk(clk), .rst_n(rst_n), .capture_s(capture_s), .s_next(s_next),
        .div_start(div_start), .div_running(div_running), .p(p),
        .div_trial_msb(div_trial_msb), .div_addend(div_addend),
        .next_remainder(next_remainder), .mul_start(mul_start),
        .mul_running(mul_running), .gain(div_result), .mul_addend(mul_addend),
        .next_product(next_product), .denominator(denominator),
        .remainder(remainder), .product(product), .sum(shared_sum),
        .no_borrow(no_borrow)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            z <= 0;
            x <= 0;
            p <= 0;
            r <= 14'd2560; // 5.0 in UQ5.9. Gain arithmetic still uses 10 fractional bits.
            delta <= 0;
            x_out <= 0;
            p_out <= 0;
            ready <= 0;
            state <= IDLE;
        end else begin
            if (state == IDLE && uio_in[3]) begin
                case (uio_in[1:0])
                    0: if (uio_in[2]) z[13:8] <= ui_in[5:0]; else z[7:0] <= ui_in;
                    1: if (uio_in[2]) x[13:8] <= ui_in[5:0]; else x[7:0] <= ui_in;
                    2: if (uio_in[2]) p[13:8] <= ui_in[5:0]; else p[7:0] <= ui_in;
                    3: if (uio_in[2]) r[13:8] <= ui_in[5:0]; else r[7:0] <= ui_in;
                endcase
            end
            case (state)
                IDLE: if (uio_in[4]) begin
                    delta <= $signed({z[13], z}) - $signed({x[13], x});
                    ready <= 0;
                    state <= DIV_START;
                end
                DIV_START: state <= DIV_WAIT;
                DIV_WAIT: if (div_done) begin
                    state <= X_START;
                end
                X_START: state <= X_WAIT;
                X_WAIT: if (mul_done) begin
                    x_out <= alu_y;
                    state <= P_START;
                end
                P_START: state <= P_WAIT;
                P_WAIT: if (mul_done) begin
                    p_out <= alu_y;
                    state <= FINISH;
                end
                FINISH: begin
                    ready <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule

`default_nettype wire
