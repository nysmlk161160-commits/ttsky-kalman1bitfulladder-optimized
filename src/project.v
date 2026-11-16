`default_nettype none

module full_adder_1bit (
    input wire a, b, cin,
    output wire sum, cout
);
    assign sum = a ^ b ^ cin;
    assign cout = (a & b) | ((a ^ b) & cin);
endmodule

module ripple_adder_12bit (
    input wire [11:0] a, b,
    input wire cin,
    output wire [11:0] sum,
    output wire cout
);
    wire [12:0] c;
    assign c[0] = cin;
    assign cout = c[12];
    genvar i;
    generate
        for (i = 0; i < 12; i = i + 1) begin : bit_slice
            full_adder_1bit fa (
                .a(a[i]), .b(b[i]), .cin(c[i]),
                .sum(sum[i]), .cout(c[i + 1])
            );
        end
    endgenerate
endmodule

module kalman_div12 (
    input wire clk, rst_n, start,
    input wire [9:0] p,
    input wire [10:0] s,
    output wire [6:0] result,
    output reg done
);
    reg [10:0] remainder;
    reg [5:0] quotient;
    reg equal_case;
    reg [2:0] gain_index;
    reg running;
    assign result = {equal_case, quotient};

    // The trial shift is wiring: consume one fractional quotient bit per clock.
    wire [11:0] trial_bits = {remainder, 1'b0};
    wire [11:0] difference;
    wire no_borrow;
    wire [5:0] next_quotient = {quotient[4:0], no_borrow};
    ripple_adder_12bit divider_adder (
        .a(trial_bits), .b(~{1'b0, s}), .cin(1'b1),
        .sum(difference), .cout(no_borrow)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            remainder <= 0;
            quotient <= 0;
            equal_case <= 0;
            gain_index <= 0;
            running <= 0;
            done <= 0;
        end else begin
            done <= 0;
            if (start) begin
                remainder <= {1'b0, p};
                quotient <= 0;
                equal_case <= (s != 0 && p == s);
                gain_index <= 0;
                running <= (s != 0 && p != s);
                if (s == 0 || p == s)
                    done <= 1;
            end else if (running) begin
                remainder <= no_borrow ? difference[10:0] : trial_bits[10:0];
                quotient <= next_quotient;
                if (gain_index == 5) begin
                    running <= 0;
                    done <= 1;
                end else begin
                    gain_index <= gain_index + 1'b1;
                end
            end
        end
    end
endmodule

module kalman_mul12 (
    input wire clk, rst_n, start,
    input wire [6:0] a,
    input wire signed [10:0] b,
    output wire signed [10:0] result,
    output reg done
);
    reg [18:0] product;
    reg [2:0] bit_count;
    reg running;
    assign result = $signed(product[16:6]);

    // Fuse the conditional add and arithmetic shift at the register input.
    // Shift the newly computed sum, not the previous cycle's accumulator.
    wire [11:0] sum;
    wire unused_carry;
    wire [11:0] multiplicand = {b[10], b};
    wire [18:0] next_product = {sum[11], sum, product[6:1]};
    ripple_adder_12bit multiplier_adder (
        .a(product[18:7]), .b(multiplicand & {12{product[0]}}),
        .cin(1'b0), .sum(sum), .cout(unused_carry)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product <= 0;
            bit_count <= 0;
            running <= 0;
            done <= 0;
        end else begin
            done <= 0;
            if (start) begin
                product <= {12'b0, a};
                bit_count <= 0;
                running <= 1;
            end else if (running) begin
                product <= next_product;
                if (bit_count == 6) begin
                    running <= 0;
                    done <= 1;
                end else begin
                    bit_count <= bit_count + 1'b1;
                end
            end
        end
    end
endmodule

// Q4.6 scratch storage experiment: two arithmetic paths, original handshakes.
// Only storage is overlaid: DIV owns {S, remainder}; MUL owns work[17:0].
module kalman_shared_work12 (
    input wire clk, rst_n,
    input wire capture_s,
    input wire [10:0] s_next,
    input wire div_start, mul_start,
    input wire [9:0] p,
    input wire signed [10:0] b,
    output wire [6:0] div_result,
    output reg div_done,
    output wire signed [10:0] mul_result,
    output reg mul_done
);
    reg [21:0] work;
    wire [10:0] denominator = work[21:11];
    wire [10:0] remainder = work[10:0];
    // Original product[18] == product[17] after reset, load and every step.
    // Represent that already-synthesized redundancy as wiring, not a new FF.
    wire [18:0] product = {work[17], work[17:0]};
    reg [5:0] quotient;
    reg equal_case;
    reg [2:0] gain_index;
    reg div_running;
    reg [2:0] bit_count;
    reg mul_running;
    assign div_result = {equal_case, quotient};
    assign mul_result = $signed(product[16:6]);

    wire [11:0] trial_bits = {remainder, 1'b0};
    wire [11:0] difference;
    wire no_borrow;
    wire [5:0] next_quotient = {quotient[4:0], no_borrow};
    ripple_adder_12bit divider_adder (
        .a(trial_bits), .b(~{1'b0, denominator}), .cin(1'b1),
        .sum(difference), .cout(no_borrow)
    );
    wire [11:0] sum;
    wire unused_carry;
    wire [11:0] multiplicand = {b[10], b};
    wire [18:0] next_product = {sum[11], sum, product[6:1]};
    ripple_adder_12bit multiplier_adder (
        .a(product[18:7]), .b(multiplicand & {12{product[0]}}),
        .cin(1'b0), .sum(sum), .cout(unused_carry)
    );

    // The original top-level schedule makes DIV and MUL ownership exclusive.
    // capture_s samples OLD P/R on the accepted-start edge; DIV loads live P
    // one edge later, preserving simultaneous-write/start behavior exactly.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            work <= 0;
        end else begin
            if (capture_s)
                work[21:11] <= s_next;
            if (div_start)
                work[10:0] <= {1'b0, p};
            else if (div_running)
                work[10:0] <= no_borrow ? difference[10:0] : trial_bits[10:0];
            if (mul_start)
                work[17:0] <= {11'b0, div_result};
            else if (mul_running)
                work[17:0] <= next_product[17:0];
        end
    end

    // Retain both counters and both running/done pairs for attribution.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            quotient <= 0;
            equal_case <= 0;
            gain_index <= 0;
            div_running <= 0;
            div_done <= 0;
        end else begin
            div_done <= 0;
            if (div_start) begin
                quotient <= 0;
                equal_case <= (denominator != 0 && p == denominator);
                gain_index <= 0;
                div_running <= (denominator != 0 && p != denominator);
                if (denominator == 0 || p == denominator)
                    div_done <= 1;
            end else if (div_running) begin
                quotient <= next_quotient;
                if (gain_index == 5) begin
                    div_running <= 0;
                    div_done <= 1;
                end else begin
                    gain_index <= gain_index + 1'b1;
                end
            end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_count <= 0;
            mul_running <= 0;
            mul_done <= 0;
        end else begin
            mul_done <= 0;
            if (mul_start) begin
                bit_count <= 0;
                mul_running <= 1;
            end else if (mul_running) begin
                if (bit_count == 6) begin
                    mul_running <= 0;
                    mul_done <= 1;
                end else begin
                    bit_count <= bit_count + 1'b1;
                end
            end
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
    reg [9:0] z, x, p, r;
    reg signed [10:0] delta;
    reg [9:0] x_out, p_out;
    reg ready;
    reg [2:0] state;

    localparam IDLE=0, DIV_START=1, DIV_WAIT=2,
               X_START=3, X_WAIT=4, P_START=5,
               P_WAIT=6, FINISH=7;
    wire div_start = (state == DIV_START);
    wire mul_start = (state == X_START || state == P_START);
    wire [6:0] div_result;
    wire div_done, mul_done;
    wire signed [10:0] mul_result;
    // b is read live by the serial multiplier and remains stable during each run.
    wire signed [10:0] mul_b = (state == X_START || state == X_WAIT)
                                      ? delta : $signed({1'b0, p});

    // One shared 10-bit datapath: X + (K*delta) or P - (K*P).
    wire do_sub = (state == P_WAIT);
    wire [9:0] alu_a = do_sub ? p : x;
    wire [9:0] alu_b = mul_result[9:0] ^ {10{do_sub}};
    wire [9:0] alu_y = alu_a + alu_b + do_sub;
    wire [9:0] read_result = uio_in[5] ? p_out : x_out;

    assign uo_out = uio_in[2] ? {6'b0, read_result[9:8]} : read_result[7:0];
    assign uio_out = {ready, (state != IDLE), 6'b0};
    assign uio_oe = 8'b11000000;
    wire capture_s = (state == IDLE && uio_in[4]);
    wire [10:0] s_next = {1'b0, p} + {1'b0, r};
    kalman_shared_work12 shared_work (
        .clk(clk), .rst_n(rst_n), .capture_s(capture_s), .s_next(s_next),
        .div_start(div_start), .mul_start(mul_start), .p(p), .b(mul_b),
        .div_result(div_result), .div_done(div_done),
        .mul_result(mul_result), .mul_done(mul_done)
    );
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            z <= 0;
            x <= 0;
            p <= 0;
            r <= 10'd320;
            delta <= 0;
            x_out <= 0;
            p_out <= 0;
            ready <= 0;
            state <= IDLE;
        end else begin
            if (state == IDLE && uio_in[3]) begin
                case (uio_in[1:0])
                    0: if (uio_in[2]) z[9:8] <= ui_in[1:0]; else z[7:0] <= ui_in;
                    1: if (uio_in[2]) x[9:8] <= ui_in[1:0]; else x[7:0] <= ui_in;
                    2: if (uio_in[2]) p[9:8] <= ui_in[1:0]; else p[7:0] <= ui_in;
                    3: if (uio_in[2]) r[9:8] <= ui_in[1:0]; else r[7:0] <= ui_in;
                endcase
            end
            case (state)
                IDLE: if (uio_in[4]) begin
                    delta <= $signed({z[9], z}) - $signed({x[9], x});
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
