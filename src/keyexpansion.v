module keyexpansion (
    input  wire         clk,
    input  wire [7:0]   key_in,
    output wire [7:0]   key_out,
    output wire [7:0]   key_d4_out,
    output wire [7:0]   data_to_sbox_out,
    input  wire [7:0]   data_from_sbox_in,
    input  wire         load_in,
    input  wire         shift_in,
    input  wire [3:0]   seq_in,
    input  wire [3:0]   round_in
);

    // --- Internal Signals ---
    reg [7:0] shift_r [0:15];
    reg [7:0] rcon_value;
    reg [7:0] rotword_r;
    wire [7:0] key_out_int;

    reg d0, d1, d2, d3;
    wire [1:0] ext_control;

    assign ext_control     = {load_in, shift_in};
    assign key_out         = key_out_int;
    assign key_d4_out      = shift_r[12];
    assign data_to_sbox_out = (d0 == 1'b1) ? shift_r[13] : rotword_r;

    // --- Mux1 and Rcon XOR logic ---
    assign key_out_int = (d1 == 1'b1 && d3 == 1'b0) ? (data_from_sbox_in ^ rcon_value ^ shift_r[0]) :
                         ((d1 == 1'b1 && d3 == 1'b1) ? (data_from_sbox_in ^ shift_r[0]) : shift_r[0]);

    // --- Control signal logic (replacing localparam array) ---
    always @(*) begin
        case (seq_in)
            4'd0 : begin d0 = 1; d1 = 1; d2 = 0; d3 = 0; end // control_seq = 3'd1
            4'd1 : begin d0 = 1; d1 = 1; d2 = 0; d3 = 1; end // control_seq = 3'd2
            4'd2 : begin d0 = 1; d1 = 1; d2 = 0; d3 = 1; end // control_seq = 3'd2
            4'd3 : begin d0 = 0; d1 = 1; d2 = 0; d3 = 1; end // control_seq = 3'd3
            4'd4,
            4'd5,
            4'd6,
            4'd7,
            4'd8,
            4'd9,
            4'd10,
            4'd11: begin d0 = 0; d1 = 0; d2 = 0; d3 = 1; end // control_seq = 3'd0
            4'd12,
            4'd13,
            4'd14,
            4'd15: begin d0 = 0; d1 = 0; d2 = 1; d3 = 1; end // control_seq = 3'd4
            default: begin d0 = 0; d1 = 0; d2 = 1; d3 = 1; end
        endcase
    end

    // --- Shifter process ---
    integer i;
    always @(posedge clk) begin
        case (ext_control)
            2'b00: ; // stall
            2'b01: begin // shift
                shift_r[15] <= key_out_int;
                if (d2 == 1'b0)
                    shift_r[3] <= key_out_int ^ shift_r[4];
                else
                    shift_r[3] <= shift_r[4];
            end
            2'b10: begin // load
                shift_r[15] <= key_in;
                shift_r[3]  <= shift_r[4];
            end
            default: begin // load and shift
                shift_r[15] <= key_in;
                if (d2 == 1'b0)
                    shift_r[3] <= key_out_int ^ shift_r[4];
                else
                    shift_r[3] <= shift_r[4];
            end
        endcase

        if (shift_in || load_in) begin
            for (i = 4; i <= 14; i = i + 1)
                shift_r[i] <= shift_r[i+1];
            for (i = 0; i <= 2; i = i + 1)
                shift_r[i] <= shift_r[i+1];
        end

        if (seq_in == 4'd0)
            rotword_r <= shift_r[12];
    end

    // --- Round constant generation ---
    always @(*) begin
        case (round_in)
            4'b0000: rcon_value = 8'h01;
            4'b0001: rcon_value = 8'h2b;
            4'b0010: rcon_value = 8'h43;
            4'b0011: rcon_value = 8'h49;
            4'b0100: rcon_value = 8'h3b;
            4'b0101: rcon_value = 8'hd6;
            4'b0110: rcon_value = 8'h33;
            4'b0111: rcon_value = 8'he1;
            4'b1000: rcon_value = 8'h58;
            4'b1001: rcon_value = 8'h85;
            default: rcon_value = 8'bx;
        endcase
    end

endmodule