// S-Box top module
module sbox_8bit (
    input  wire [7:0] sbin,
    output wire [7:0] sbout
);
    wire [3:0] hi, lo, w1, w2, w3, w4, w5;
    wire [7:0] temp;

    assign w2 = sbin[7:4] ^ sbin[3:0];

    gf24_square_mult u1 (
        .a(sbin[7:4]),
        .z(w1)
    );

    gf24_mult u2 (
        .a(sbin[3:0]),
        .b(w2),
        .z(w3)
    );

    assign w4 = w3 ^ w1;

    gf24_inv u3 (
        .a(w4),
        .z(w5)
    );

    gf24_mult u4 (
        .a(sbin[7:4]),
        .b(w5),
        .z(hi)
    );

    gf24_mult u5 (
        .a(w2),
        .b(w5),
        .z(lo)
    );

    assign temp = {hi, lo};

    affine u6 (
        .a(temp),
        .z(sbout)
    );

endmodule

// GF(2^4) square multiplication
module gf24_square_mult(
    input  wire [3:0] a,
    output wire [3:0] z
);
    wire [1:0] x;
    assign x[0] = a[0] ^ a[1];
    assign x[1] = a[2] ^ a[3];

    assign z[3] = x[1] ^ x[0];
    assign z[2] = x[1];
    assign z[1] = x[0] ^ a[2];
    assign z[0] = a[3] ^ a[0];
endmodule

// GF(2^4) multiplier
module gf24_mult(
    input  wire [3:0] a,
    input  wire [3:0] b,
    output wire [3:0] z
);
    wire [1:0] x;
    wire y;
    assign x[1] = a[3] ^ a[2];
    assign x[0] = a[3] ^ a[0];
    assign y    = a[2] ^ a[1];

    assign z[3] = (a[3] & b[0]) ^ (a[2] & b[1]) ^ (x[0] & b[3]) ^ (a[1] & b[2]);
    assign z[2] = (a[2] & b[0]) ^ (a[1] & b[1]) ^ (x[0] & b[2]) ^ (x[1] & b[3]);
    assign z[1] = (a[1] & b[0]) ^ (x[0] & b[1]) ^ (x[1] & b[2]) ^ (y & b[3]);
    assign z[0] = (a[0] & b[0]) ^ (a[3] & b[1]) ^ (a[2] & b[2]) ^ (a[1] & b[3]);
endmodule

// GF(2^4) multiplicative inverse
module gf24_inv(
    input  wire [3:0] a,
    output reg  [3:0] z
);
    always @(*) begin
        case (a)
            4'b0000: z = 4'b0000;
            4'b0001: z = 4'b0001;
            4'b0010: z = 4'b1001;
            4'b0011: z = 4'b1110;
            4'b0100: z = 4'b1101;
            4'b0101: z = 4'b1011;
            4'b0110: z = 4'b0111;
            4'b0111: z = 4'b0110;
            4'b1000: z = 4'b1111;
            4'b1001: z = 4'b0010;
            4'b1010: z = 4'b1100;
            4'b1011: z = 4'b0101;
            4'b1100: z = 4'b1010;
            4'b1101: z = 4'b0100;
            4'b1110: z = 4'b0011;
            default: z = 4'b1000;
        endcase
    end
endmodule

// Affine transformation
module affine(
    input  wire [7:0] a,
    output wire [7:0] z
);
    assign z[7] = a[6] ^ a[4] ^ a[3] ^ 1'b1;
    assign z[6] = a[7] ^ a[6] ^ a[5] ^ a[4] ^ a[2] ^ 1'b1;
    assign z[5] = a[6] ^ a[5] ^ a[4] ^ a[1];
    assign z[4] = a[5] ^ a[4] ^ a[2] ^ a[0];
    assign z[3] = a[6] ^ a[0] ^ 1'b1;
    assign z[2] = a[7] ^ a[5] ^ a[3] ^ a[2] ^ a[1] ^ 1'b1;
    assign z[1] = a[7] ^ a[4] ^ a[1] ^ a[0] ^ 1'b1;
    assign z[0] = a[7] ^ a[5] ^ a[3] ^ a[1] ^ a[0] ^ 1'b1;
endmodule
