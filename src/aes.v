// aes_parallel.v
// High-performance parallel AES implementation.

module aes (
  input         clk,
  input         rst_n,
  input  [127:0] data_in,
  input  [127:0] key_in,
  input         start_in, // Start encryption pulse
  output [127:0] data_out,
  output        busy_out
);

    // FSM States
    localparam STATE_IDLE  = 2'd0;
    localparam STATE_INIT  = 2'd1;
    localparam STATE_ROUND = 2'd2;
    localparam STATE_FINAL = 2'd3;

    reg [1:0] current_state_r, next_state;
    reg [3:0] round_r, next_round;
    reg [127:0] state_r;

    // --- Datapath Wires ---
    wire [127:0] initial_add_key_out;
    wire [127:0] sub_bytes_out;
    wire [127:0] shift_rows_out;
    wire [127:0] mix_cols_out;
    wire [127:0] round_add_key_out;
    wire [127:0] round_key;

    // --- Control Logic ---
    assign busy_out = (current_state_r != STATE_IDLE);
    assign data_out = state_r;

    // --- Key Expansion Unit ---
    key_expansion_parallel keu (
        .clk(clk),
        .rst_n(rst_n),
        .key_load_en(current_state_r == STATE_IDLE && start_in),
        .initial_key_in(key_in),
        .round(round_r),
        .round_key_out(round_key)
    );
    
    // --- State Register and FSM ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state_r <= STATE_IDLE;
            round_r <= 4'd0;
            state_r <= 128'b0;
        end else begin
            current_state_r <= next_state;
            round_r <= next_round;
            
            case (current_state_r)
                STATE_IDLE: if (start_in) state_r <= initial_add_key_out;
                STATE_INIT: state_r <= round_add_key_out; // For round 1
                STATE_ROUND: state_r <= round_add_key_out; // For rounds 2-9
                STATE_FINAL: state_r <= round_add_key_out; // For final round (no mixcols)
            endcase
        end
    end

    // --- FSM Next State Logic ---
    always @(*) begin
        next_state = current_state_r;
        next_round = round_r;
        case (current_state_r)
            STATE_IDLE: if (start_in) next_state = STATE_INIT;
            STATE_INIT: begin
                next_state = STATE_ROUND;
                next_round = round_r + 1;
            end
            STATE_ROUND: begin
                if (round_r == 4'd8) begin // After round 9 is done
                    next_state = STATE_FINAL;
                end
                next_round = round_r + 1;
            end
            STATE_FINAL: begin
                next_state = STATE_IDLE;
                next_round = 4'd0;
            end
        endcase
    end

    // --- 1. Initial AddRoundKey ---
    assign initial_add_key_out = data_in ^ key_in;

    // --- 2. SubBytes (16 S-Boxes) ---
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : sub_bytes_instance
            sbox_8bit sbox_inst (
                .sbin(state_r[(127 - 8*i) -: 8]),
                .sbout(sub_bytes_out[(127 - 8*i) -: 8])
            );
        end
    endgenerate

    // --- 3. ShiftRows (Combinational Wire Permutation) ---
    assign shift_rows_out[127:120] = sub_bytes_out[127:120]; // Row 0
    assign shift_rows_out[119:112] = sub_bytes_out[95:88];
    assign shift_rows_out[111:104] = sub_bytes_out[63:56];
    assign shift_rows_out[103:96]  = sub_bytes_out[31:24];
    
    assign shift_rows_out[95:88]   = sub_bytes_out[87:80];   // Row 1
    assign shift_rows_out[87:80]   = sub_bytes_out[55:48];
    assign shift_rows_out[79:72]   = sub_bytes_out[23:16];
    assign shift_rows_out[71:64]   = sub_bytes_out[119:112];
    
    assign shift_rows_out[63:56]   = sub_bytes_out[47:40];   // Row 2
    assign shift_rows_out[55:48]   = sub_bytes_out[15:8];
    assign shift_rows_out[47:40]   = sub_bytes_out[111:104];
    assign shift_rows_out[39:32]   = sub_bytes_out[79:72];
    
    assign shift_rows_out[31:24]   = sub_bytes_out[7:0];     // Row 3
    assign shift_rows_out[23:16]   = sub_bytes_out[103:96];
    assign shift_rows_out[15:8]    = sub_bytes_out[71:64];
    assign shift_rows_out[7:0]     = sub_bytes_out[39:32];

    // --- 4. MixColumns ---
    mix_columns_parallel mix_cols_inst (
        .data_in(shift_rows_out),
        .data_out(mix_cols_out)
    );
    
    // --- 5. AddRoundKey ---
    assign round_add_key_out = (current_state_r == STATE_FINAL) ? 
                               (shift_rows_out ^ round_key) : // Final round skips MixCols
                               (mix_cols_out ^ round_key);
endmodule