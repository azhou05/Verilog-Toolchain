module native_mixcolumns (
    input  wire         clk,
    input  wire         start_in,
    input  wire [7:0]   data_in,     // input data
    output wire [7:0]   data0_out,   // output data
    output wire [7:0]   data1_out,   // output data
    output wire [7:0]   data2_out,   // output data
    output wire [7:0]   data3_out    // output data
);

    // Function equivalent for scaling_2b
    function [7:0] scaling_2b(input [7:0] a);
        reg [7:0] z;
        begin
            z[7] = a[4] ^ a[2];
            z[6] = a[7] ^ a[1];
            z[5] = a[6] ^ a[3] ^ a[0];
            z[4] = a[5] ^ a[4] ^ a[3];
            z[3] = a[7] ^ a[5] ^ a[2] ^ a[0];
            z[2] = a[7] ^ a[6] ^ a[4] ^ a[3] ^ a[1];
            z[1] = a[7] ^ a[6] ^ a[5] ^ a[3] ^ a[2] ^ a[0];
            z[0] = a[6] ^ a[4] ^ a[3] ^ a[1] ^ a[0];
            scaling_2b = z;
        end
    endfunction

    // Internal signals
    reg [7:0] accum_r [0:3];
    wire [7:0] x;
    wire [7:0] s2b;
    wire [7:0] s2a;

    assign x    = data_in;
    assign s2b  = scaling_2b(x);
    assign s2a  = s2b ^ x;

    // Sequential logic
    always @(posedge clk) begin
        if (start_in) begin
            accum_r[0] <= x;
            accum_r[1] <= x;
            accum_r[2] <= s2a;
            accum_r[3] <= s2b;
        end else begin
            accum_r[0] <= x    ^ accum_r[1];
            accum_r[1] <= x    ^ accum_r[2];
            accum_r[2] <= s2a  ^ accum_r[3];
            accum_r[3] <= s2b  ^ accum_r[0];
        end
    end

    // Output assignments
    assign data0_out = accum_r[0];
    assign data1_out = accum_r[1];
    assign data2_out = accum_r[2];
    assign data3_out = accum_r[3];

endmodule