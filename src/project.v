`default_nettype none

module grouped_carry_adder #(
    parameter integer GROUPS = 4
) (
    input wire [4*GROUPS-1:0] a, b,
    input wire cin,
    output wire [4*GROUPS-1:0] sum,
    output wire cout
);
    wire [GROUPS-1:0] group_propagate, group_generate;
    wire [GROUPS:0] group_carry;
    assign group_carry[0] = cin;
    assign cout = group_carry[GROUPS];

    genvar group_index, prior_group;
    generate
        for (group_index = 0; group_index < GROUPS; group_index = group_index + 1) begin : carry_group
            localparam integer BASE = 4 * group_index;
            wire [3:0] p = a[BASE +: 4] ^ b[BASE +: 4];
            wire [3:0] g = a[BASE +: 4] & b[BASE +: 4];
            wire incoming = group_carry[group_index];

            assign group_propagate[group_index] = &p;
            assign group_generate[group_index] = g[3] | (p[3] & g[2])
                | (&p[3:2] & g[1]) | (&p[3:1] & g[0]);

            // Group carries are evaluated from the original carry-in and
            // earlier generate/propagate terms in parallel.
            wire [group_index:0] generated_terms;
            assign generated_terms[group_index] = group_generate[group_index];
            for (prior_group = 0; prior_group < group_index; prior_group = prior_group + 1) begin : preceding
                assign generated_terms[prior_group] = group_generate[prior_group]
                    & (&group_propagate[group_index:prior_group+1]);
            end
            assign group_carry[group_index + 1] = (|generated_terms)
                | ((&group_propagate[group_index:0]) & cin);

            // Each bit carry within a group also resolves directly from
            // the group input, with no dependency on the previous bit carry.
            wire carry1 = g[0] | (p[0] & incoming);
            wire carry2 = g[1] | (p[1] & g[0]) | (&p[1:0] & incoming);
            wire carry3 = g[2] | (p[2] & g[1]) | (&p[2:1] & g[0])
                | (&p[2:0] & incoming);
            assign sum[BASE +: 4] = p ^ {carry3, carry2, carry1, incoming};
        end
    endgenerate
endmodule

module kalman_div16 (
    input wire clk, rst_n, start,
    input wire [13:0] p,
    input wire [14:0] s,
    output wire [10:0] result,
    output reg done
);
    reg [14:0] remainder;
    reg [9:0] quotient;
    reg equal_case;
    reg [3:0] gain_index;
    reg running;
    assign result = {equal_case, quotient};
    wire [3:0] next_gain_index;
    grouped_carry_adder #(.GROUPS(1)) increment_gain (
        .a(gain_index), .b(4'd0), .cin(1'b1), .sum(next_gain_index), .cout()
    );

    // The trial shift is wiring: consume one fractional quotient bit per clock.
    wire [15:0] trial_bits = {remainder, 1'b0};
    wire [15:0] difference;
    wire no_borrow;
    wire [9:0] next_quotient = {quotient[8:0], no_borrow};
    grouped_carry_adder divider_adder (
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
                remainder <= no_borrow ? difference[14:0] : trial_bits[14:0];
                quotient <= next_quotient;
                if (gain_index == 9) begin
                    running <= 0;
                    done <= 1;
                end else begin
                    gain_index <= next_gain_index;
                end
            end
        end
    end
endmodule

module kalman_mul16 (
    input wire clk, rst_n, start,
    input wire [10:0] a,
    input wire signed [14:0] b,
    output wire signed [14:0] result,
    output reg done
);
    reg [26:0] product;
    reg [3:0] bit_count;
    reg running;
    assign result = $signed(product[24:10]);
    wire [3:0] next_bit_count;
    grouped_carry_adder #(.GROUPS(1)) increment_product (
        .a(bit_count), .b(4'd0), .cin(1'b1), .sum(next_bit_count), .cout()
    );

    // Fuse the conditional add and arithmetic shift at the register input.
    // Shift the newly computed sum, not the previous cycle's accumulator.
    wire [15:0] sum;
    wire unused_carry;
    wire [15:0] multiplicand = {b[14], b};
    wire [26:0] next_product = {sum[15], sum, product[10:1]};
    grouped_carry_adder multiplier_adder (
        .a(product[26:11]), .b(multiplicand & {16{product[0]}}),
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
                product <= {16'b0, a};
                bit_count <= 0;
                running <= 1;
            end else if (running) begin
                product <= next_product;
                if (bit_count == 10) begin
                    running <= 0;
                    done <= 1;
                end else begin
                    bit_count <= next_bit_count;
                end
            end
        end
    end
endmodule

// DIV and MUL share the work bank and one 16-bit adder.
module kalman_shared_work16 (
    input wire clk, rst_n,
    input wire capture_s,
    input wire [14:0] s_next,
    input wire div_start, mul_start,
    input wire [13:0] p,
    input wire signed [14:0] b,
    output wire [10:0] div_result,
    output reg div_done,
    output wire signed [14:0] mul_result,
    output reg mul_done
);
    reg [29:0] work;
    // Align the remainder with the multiplier's high slice. The middle
    // fourteen A inputs then read the same flops in both arithmetic phases.
    wire [14:0] denominator = {work[29:27], work[11:0]};
    wire [14:0] remainder = work[26:12];
    // Original product[26] == product[25] after reset, load and every step.
    // Represent that already-synthesized redundancy as wiring, not a new FF.
    wire [26:0] product = {work[25], work[25:0]};
    reg [9:0] quotient;
    reg equal_case;
    reg [3:0] gain_index;
    reg div_running;
    reg [3:0] bit_count;
    reg mul_running;
    assign div_result = {equal_case, quotient};
    assign mul_result = $signed(product[24:10]);
    wire [3:0] next_gain_index, next_bit_count;
    grouped_carry_adder #(.GROUPS(1)) increment_gain (
        .a(gain_index), .b(4'd0), .cin(1'b1), .sum(next_gain_index), .cout()
    );
    grouped_carry_adder #(.GROUPS(1)) increment_product (
        .a(bit_count), .b(4'd0), .cin(1'b1), .sum(next_bit_count), .cout()
    );

    wire [15:0] trial_bits = {remainder, 1'b0};
    wire [15:0] shared_sum;
    wire [15:0] difference = shared_sum;
    wire no_borrow;
    wire [9:0] next_quotient = {quotient[8:0], no_borrow};
    wire [15:0] multiplicand = {b[14], b};
    wire [15:0] mul_addend = multiplicand & {16{product[0]}};
    wire [26:0] next_product = {shared_sum[15], shared_sum, product[10:1]};
    // The top-level schedule makes the two running flags mutually exclusive.
    // The carry output is consumed only by the divider.
    wire [15:0] shared_a = {
        mul_running ? product[26] : trial_bits[15],
        work[25:12],
        mul_running & product[11]
    };
    grouped_carry_adder shared_adder (
        .a(shared_a),
        .b(mul_running ? mul_addend : ~{1'b0, denominator}),
        .cin(~mul_running),
        .sum(shared_sum), .cout(no_borrow)
    );

    // The original top-level schedule makes DIV and MUL ownership exclusive.
    // capture_s samples OLD P/R on the accepted-start edge; DIV loads live P
    // one edge later, preserving simultaneous-write/start behavior exactly.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            work <= 0;
        end else begin
            if (capture_s)
                {work[29:27], work[11:0]} <= s_next;
            if (div_start)
                work[26:12] <= {1'b0, p};
            else if (div_running)
                work[26:12] <= no_borrow ? difference[14:0] : trial_bits[14:0];
            if (mul_start)
                work[25:0] <= {15'b0, div_result};
            else if (mul_running)
                work[25:0] <= next_product[25:0];
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
                if (gain_index == 9) begin
                    div_running <= 0;
                    div_done <= 1;
                end else begin
                    gain_index <= next_gain_index;
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
                if (bit_count == 10) begin
                    mul_running <= 0;
                    mul_done <= 1;
                end else begin
                    bit_count <= next_bit_count;
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
    wire [15:0] update_sum;
    wire [13:0] alu_y = update_sum[13:0];
    grouped_carry_adder update_adder (
        .a({2'b0, alu_a}), .b({2'b0, alu_b}), .cin(do_sub), .sum(update_sum), .cout()
    );
    wire [13:0] read_result = uio_in[5] ? p_out : x_out;

    assign uo_out = uio_in[2] ? {2'b0, read_result[13:8]} : read_result[7:0];
    assign uio_out = {ready, (state != IDLE), 6'b0};
    assign uio_oe = 8'b11000000;
    wire capture_s = (state == IDLE && uio_in[4]);
    wire [15:0] denominator_sum, residual_difference;
    wire [14:0] s_next = denominator_sum[14:0];
    grouped_carry_adder denominator_adder (
        .a({2'b0, p}), .b({2'b0, r}), .cin(1'b0), .sum(denominator_sum), .cout()
    );
    grouped_carry_adder residual_adder (
        .a({{2{z[13]}}, z}), .b(~{{2{x[13]}}, x}), .cin(1'b1),
        .sum(residual_difference), .cout()
    );
    kalman_shared_work16 shared_work (
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
                    delta <= $signed(residual_difference[14:0]);
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
