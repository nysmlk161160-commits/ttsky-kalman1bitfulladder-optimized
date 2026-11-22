`default_nettype none

module formal_shared_adder (
    input wire [15:0] a, b,
    input wire cin,
    output wire equivalent
);
    wire [15:0] sum;
    wire cout;
    wire [16:0] expected = {1'b0, a} + {1'b0, b} + {16'b0, cin};

    grouped_carry_adder_16bit dut (
        .a(a), .b(b), .cin(cin), .sum(sum), .cout(cout)
    );
    assign equivalent = {cout, sum} == expected;
endmodule

`default_nettype wire
