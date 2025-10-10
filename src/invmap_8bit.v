module invmap_8bit (
    input  [7:0] invmap,
    output [7:0] byte_out
);

assign byte_out[7] = invmap[7] ^ invmap[2];
assign byte_out[6] = invmap[7] ^ invmap[6] ^ invmap[3] ^ invmap[2] ^ invmap[1];
assign byte_out[5] = invmap[2];
assign byte_out[4] = invmap[7] ^ invmap[6] ^ invmap[4] ^ invmap[3] ^ invmap[1];
assign byte_out[3] = invmap[6] ^ invmap[5] ^ invmap[1];
assign byte_out[2] = invmap[7] ^ invmap[5] ^ invmap[1];
assign byte_out[1] = invmap[7] ^ invmap[5] ^ invmap[4];
assign byte_out[0] = invmap[7] ^ invmap[6] ^ invmap[5] ^ invmap[0];

endmodule