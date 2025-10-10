module map_8bit (
    input  wire [7:0] byte_in,
    output wire [7:0] mapo
);

    assign mapo[7] = byte_in[7] ^ byte_in[5];
    assign mapo[6] = byte_in[7] ^ byte_in[5] ^ byte_in[3] ^ byte_in[2];
    assign mapo[5] = byte_in[7] ^ byte_in[6] ^ byte_in[4] ^ byte_in[1];
    assign mapo[4] = byte_in[6] ^ byte_in[5] ^ byte_in[4];
    assign mapo[3] = byte_in[4] ^ byte_in[3] ^ byte_in[1];
    assign mapo[2] = byte_in[5];
    assign mapo[1] = byte_in[6] ^ byte_in[5] ^ byte_in[4] ^ byte_in[2] ^ byte_in[1];
    assign mapo[0] = byte_in[7] ^ byte_in[6] ^ byte_in[4] ^ byte_in[3] ^ byte_in[2] ^ byte_in[1] ^ byte_in[0];

endmodule