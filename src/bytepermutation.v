module bytepermutation (
    input              clk,
    input      [7:0]   data_in,
    output     [7:0]   data_out,
    input      [3:0]   seq_in,
    input              shift_in,
    input              load_in
);

    // --- Control sequence constant ---
    // localparam [1:0] forward_seq [0:15] = {
    //     2'd3, 2'd2, 2'd1, 2'd0, 2'd3, 2'd2, 2'd1, 2'd1,
    //     2'd3, 2'd2, 2'd3, 2'd2, 2'd3, 2'd3, 2'd3, 2'd3
    // };

    // --- Sequence and control word ---
    // wire [3:0] sequence = seq_in;
    // wire [1:0] control_word = forward_seq[sequence];


    reg [1:0] control_word;

    always @(*) begin
    case (seq_in)
        4'd0 : control_word = 2'd3;
        4'd1 : control_word = 2'd2;
        4'd2 : control_word = 2'd1;
        4'd3 : control_word = 2'd0;
        4'd4 : control_word = 2'd3;
        4'd5 : control_word = 2'd2;
        4'd6 : control_word = 2'd1;
        4'd7 : control_word = 2'd1;
        4'd8 : control_word = 2'd3;
        4'd9 : control_word = 2'd2;
        4'd10: control_word = 2'd3;
        4'd11: control_word = 2'd2;
        4'd12: control_word = 2'd3;
        4'd13: control_word = 2'd3;
        4'd14: control_word = 2'd3;
        4'd15: control_word = 2'd3;
        default: control_word = 2'd3;
    endcase
end

    // --- Shift registers ---
    reg [7:0] sreg0_r [0:3];
    reg [7:0] sreg1_r [0:3];
    reg [7:0] sreg2_r [0:3];

    // --- Mux control signals ---
    reg c0, c1, c2;
    reg [1:0] c3;

    wire [1:0] ext_control = {load_in, shift_in};

    // --- Output MUX controlled by c3 ---
    assign data_out = (c3 == 2'b00) ? data_in   :
                      (c3 == 2'b01) ? sreg0_r[3] :
                      (c3 == 2'b10) ? sreg1_r[3] :
                                      sreg2_r[3];

    // --- Mux control logic ---
    always @(*) begin
        case (control_word)
            2'd0: begin
                c0 = 1'b1;
                c1 = 1'b0;
                c2 = 1'b0;
                c3 = 2'b00;
            end
            2'd1: begin
                c0 = 1'b0;
                c1 = 1'b1;
                c2 = 1'b0;
                c3 = 2'b01;
            end
            2'd2: begin
                c0 = 1'b0;
                c1 = 1'b0;
                c2 = 1'b1;
                c3 = 2'b10;
            end
            default: begin  // 2'd3
                c0 = 1'b0;
                c1 = 1'b0;
                c2 = 1'b0;
                c3 = 2'b11;
            end
        endcase
    end

    // --- Shift register behavior on clock rising edge ---
    integer i;
    always @(posedge clk) begin
        case (ext_control)
            2'b01, 2'b11: begin // shift or load+shift
                sreg0_r[0] <= (c0 == 1'b1) ? sreg2_r[3] : data_in;
                sreg1_r[0] <= (c1 == 1'b1) ? sreg2_r[3] : sreg0_r[3];
                sreg2_r[0] <= (c2 == 1'b1) ? sreg2_r[3] : sreg1_r[3];
            end
            2'b10: begin // load
                sreg0_r[0] <= data_in;
                sreg1_r[0] <= sreg0_r[3];
                sreg2_r[0] <= sreg1_r[3];
            end
            default: ; // stall (do nothing)
        endcase

        if (ext_control != 2'b00) begin // not stall
            for (i = 1; i <= 3; i = i + 1) begin
                sreg0_r[i] <= sreg0_r[i-1];
                sreg1_r[i] <= sreg1_r[i-1];
                sreg2_r[i] <= sreg2_r[i-1];
            end
        end
    end

endmodule