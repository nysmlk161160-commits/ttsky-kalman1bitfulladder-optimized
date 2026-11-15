`default_nettype none

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
    reg [10:0] s;
    reg [9:0] x_out, p_out;
    reg ready;
    reg [2:0] state;

    localparam IDLE=0, DIV_START=1, DIV_WAIT=2,
               X_START=3, X_WAIT=4, P_START=5,
               P_WAIT=6, FINISH=7;
    wire div_start = (state == DIV_START);
    wire mul_start = (state == X_START || state == P_START);
    // Diagnostic data signatures keep all four input words observable.
    // This design performs no Kalman arithmetic and is not a usable filter.
    wire [9:0] read_result = uio_in[5] ? p_out : x_out;
    assign uo_out = uio_in[2] ? {6'b0, read_result[9:8]} : read_result[7:0];
    assign uio_out = {ready, (state != IDLE), 6'b0};
    assign uio_oe = 8'b11000000;

    // Preserve the original done-pulse timing: six division iterations,
    // seven multiplication iterations. Unsigned P/R give shortcut iff R=0.
    reg [2:0] div_count, mul_count;
    reg div_running, mul_running, div_done, mul_done;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_count <= 0; mul_count <= 0;
            div_running <= 0; mul_running <= 0;
            div_done <= 0; mul_done <= 0;
        end else begin
            div_done <= 0;
            if (div_start) begin
                div_count <= 0;
                div_running <= (r != 0);
                div_done <= (r == 0);
            end else if (div_running) begin
                if (div_count == 5) begin
                    div_running <= 0;
                    div_done <= 1;
                end else div_count <= div_count + 1'b1;
            end
            mul_done <= 0;
            if (mul_start) begin
                mul_count <= 0;
                mul_running <= 1;
            end else if (mul_running) begin
                if (mul_count == 6) begin
                    mul_running <= 0;
                    mul_done <= 1;
                end else mul_count <= mul_count + 1'b1;
            end
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            z <= 0;
            x <= 0;
            p <= 0;
            r <= 10'd320;
            delta <= 0;
            s <= 0;
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
                    delta <= {z[9], z} ^ {x[9], x};
                    s <= {1'b0, p} ^ {1'b0, r};
                    ready <= 0;
                    state <= DIV_START;
                end
                DIV_START: state <= DIV_WAIT;
                DIV_WAIT: if (div_done) begin
                    state <= X_START;
                end
                X_START: state <= X_WAIT;
                X_WAIT: if (mul_done) begin
                    x_out <= delta[9:0];
                    state <= P_START;
                end
                P_START: state <= P_WAIT;
                P_WAIT: if (mul_done) begin
                    p_out <= s[9:0];
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
