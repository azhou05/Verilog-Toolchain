// key_expansion_parallel.v
// Generates the next 128-bit round key from the current one.

module key_expansion_parallel (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         key_load_en,
    input  wire [127:0] initial_key_in,
    input  wire [3:0]   round,
    output wire [127:0] round_key_out
);
    
    reg [127:0] current_key_r;
    wire [127:0] next_key;

    // --- Key Loading and State ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_key_r <= 128'b0;
        end else if (key_load_en) begin
            current_key_r <= initial_key_in;
        end else begin
            current_key_r <= next_key;
        end
    end

    // --- Combinational Logic for Next Key Generation ---
    // Extract words from the current key
    wire [31:0] w0 = current_key_r[127:96];
    wire [31:0] w1 = current_key_r[95:64];
    wire [31:0] w2 = current_key_r[63:32];
    wire [31:0] w3 = current_key_r[31:0];

    // Core Key Schedule Operations
    // 1. RotWord: Rotate the last word [w3] left by one byte
    wire [31:0] rot_word = {w3[23:0], w3[31:24]};

    // 2. SubWord: Apply S-Box to each byte of the rotated word
    wire [31:0] sub_word;
    sbox_8bit sbox0 (.sbin(rot_word[31:24]), .sbout(sub_word[31:24]));
    sbox_8bit sbox1 (.sbin(rot_word[23:16]), .sbout(sub_word[23:16]));
    sbox_8bit sbox2 (.sbin(rot_word[15:8]),  .sbout(sub_word[15:8]));
    sbox_8bit sbox3 (.sbin(rot_word[7:0]),   .sbout(sub_word[7:0]));

    // 3. RCON: Round Constant lookup
    reg [31:0] rcon;
    always @(*) begin
        case (round)
            4'd0:  rcon = 32'h01000000;
            4'd1:  rcon = 32'h02000000;
            4'd2:  rcon = 32'h04000000;
            4'd3:  rcon = 32'h08000000;
            4'd4:  rcon = 32'h10000000;
            4'd5:  rcon = 32'h20000000;
            4'd6:  rcon = 32'h40000000;
            4'd7:  rcon = 32'h80000000;
            4'd8:  rcon = 32'h1B000000;
            4'd9:  rcon = 32'h36000000;
            default: rcon = 32'h00000000;
        endcase
    end
    
    // 4. Calculate new words for the next key
    wire [31:0] w4 = w0 ^ sub_word ^ rcon;
    wire [31:0] w5 = w1 ^ w4;
    wire [31:0] w6 = w2 ^ w5;
    wire [31:0] w7 = w3 ^ w6;
    
    assign next_key = {w4, w5, w6, w7};
    assign round_key_out = current_key_r;

endmodule