// mix_columns_parallel.v
// Performs MixColumns on the entire 128-bit state combinationally.

module mix_columns_parallel (
    input  wire [127:0] data_in,
    output wire [127:0] data_out
);

    // Helper function for Galois Field (GF(2^8)) multiplication by 2 (xtime)
    function [7:0] xtime(input [7:0] b);
        xtime = (b[7] == 1'b1) ? ((b << 1) ^ 8'h1B) : (b << 1);
    endfunction

    genvar i;
    generate
        // Apply MixColumns transformation to each of the 4 columns
        for (i = 0; i < 4; i = i + 1) begin : mix_column_instance
            wire [7:0] in0, in1, in2, in3;
            wire [7:0] out0, out1, out2, out3;

            // Extract the 4 bytes of the current column
            assign in0 = data_in[(i*32) + 31 -: 8];
            assign in1 = data_in[(i*32) + 23 -: 8];
            assign in2 = data_in[(i*32) + 15 -: 8];
            assign in3 = data_in[(i*32) +  7 -: 8];

            // Perform the MixColumns matrix multiplication
            // out0 = (2 * in0) + (3 * in1) + (1 * in2) + (1 * in3)
            // out1 = (1 * in0) + (2 * in1) + (3 * in2) + (1 * in3)
            // out2 = (1 * in0) + (1 * in1) + (2 * in2) + (3 * in3)
            // out3 = (3 * in0) + (1 * in1) + (1 * in2) + (2 * in3)
            assign out0 = xtime(in0) ^ (xtime(in1) ^ in1) ^ in2 ^ in3;
            assign out1 = in0 ^ xtime(in1) ^ (xtime(in2) ^ in2) ^ in3;
            assign out2 = in0 ^ in1 ^ xtime(in2) ^ (xtime(in3) ^ in3);
            assign out3 = (xtime(in0) ^ in0) ^ in1 ^ in2 ^ xtime(in3);

            // Assign the results to the output
            assign data_out[(i*32) + 31 -: 8] = out0;
            assign data_out[(i*32) + 23 -: 8] = out1;
            assign data_out[(i*32) + 15 -: 8] = out2;
            assign data_out[(i*32) +  7 -: 8] = out3;
        end
    endgenerate

endmodule