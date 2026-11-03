`default_nettype none

// Direct fixed-point operators: no iterative divider state.
module kalman_direct_gain (
    input wire [9:0] p,
    input wire [10:0] s,
    output wire [6:0] gain_code
);
    wire [15:0] numerator = {p, 6'b0};
    wire [15:0] quotient = (s == 0) ? 16'b0 : numerator / {5'b0, s};
    assign gain_code = quotient[6:0];
endmodule

// Direct multiplication. Arithmetic shift preserves floor for negatives.
module kalman_direct_scale (
    input wire [6:0] gain_code,
    input wire signed [10:0] operand,
    output wire signed [10:0] result
);
    wire signed [7:0] positive_gain = $signed({1'b0, gain_code});
    wire signed [18:0] full_product = positive_gain * operand;
    wire signed [18:0] scaled_product = full_product >>> 6;
    assign result = scaled_product[10:0];
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
    reg [9:0] x_out, p_out;
    reg ready, busy;

    // Same encoded mathematics and rounding boundaries as version6.
    wire [10:0] s = {1'b0, p} + {1'b0, r};
    wire signed [10:0] delta = $signed({z[9], z}) - $signed({x[9], x});
    wire [6:0] gain_code;
    wire signed [10:0] x_correction, p_correction;
    kalman_direct_gain gain (.p(p), .s(s), .gain_code(gain_code));
    kalman_direct_scale update_x (
        .gain_code(gain_code), .operand(delta), .result(x_correction)
    );
    kalman_direct_scale update_p (
        .gain_code(gain_code), .operand($signed({1'b0, p})), .result(p_correction)
    );
    wire signed [10:0] next_x = $signed({x[9], x}) + x_correction;
    wire signed [10:0] next_p = $signed({1'b0, p}) - p_correction;
    wire [9:0] read_result = uio_in[5] ? p_out : x_out;

    assign uo_out = uio_in[2] ? {6'b0, read_result[9:8]} : read_result[7:0];
    assign uio_out = {ready, busy, 6'b0};
    assign uio_oe = 8'b11000000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            z <= 0;
            x <= 0;
            p <= 0;
            r <= 10'd320;
            x_out <= 0;
            p_out <= 0;
            ready <= 0;
            busy <= 0;
        end else if (!busy) begin
            if (uio_in[3]) begin
                case (uio_in[1:0])
                    0: if (uio_in[2]) z[9:8] <= ui_in[1:0]; else z[7:0] <= ui_in;
                    1: if (uio_in[2]) x[9:8] <= ui_in[1:0]; else x[7:0] <= ui_in;
                    2: if (uio_in[2]) p[9:8] <= ui_in[1:0]; else p[7:0] <= ui_in;
                    3: if (uio_in[2]) r[9:8] <= ui_in[1:0]; else r[7:0] <= ui_in;
                endcase
            end
            if (uio_in[4]) begin
                ready <= 0;
                busy <= 1;
            end
        end else begin
            // One register-to-register arithmetic interval, no pipeline cuts.
            // Low ten bits preserve the legacy output modulo behaviour.
            x_out <= next_x[9:0];
            p_out <= next_p[9:0];
            ready <= 1;
            busy <= 0;
        end
    end
endmodule

`default_nettype wire
