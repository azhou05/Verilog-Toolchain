module par2ser (
    input           clk,

    input           load_par_in,
    input           load_ser_in,
    input           shift_in,

    input   [7:0]   data_serial_in,
    output  [7:0]   data_serial_out,

    input   [7:0]   data_parallel0_in,
    input   [7:0]   data_parallel1_in,
    input   [7:0]   data_parallel2_in,
    input   [7:0]   data_parallel3_in
);

    // Internal shift registers
    reg [7:0] sreg0_r, sreg1_r, sreg2_r, sreg3_r;

    // Output multiplexer
    assign data_serial_out = (load_par_in == 1'b1) ? data_parallel0_in : sreg0_r;

    // Clocked process
    always @(posedge clk) begin
        if (load_par_in == 1'b1) begin
            sreg0_r <= data_parallel1_in;
            sreg1_r <= data_parallel2_in;
            sreg2_r <= data_parallel3_in;
        end else if (shift_in == 1'b1 || load_ser_in == 1'b1) begin
            sreg0_r <= sreg1_r;
            sreg1_r <= sreg2_r;
            sreg2_r <= sreg3_r;
        end

        if (load_ser_in == 1'b1) begin
            sreg3_r <= data_serial_in;
        end
    end

endmodule