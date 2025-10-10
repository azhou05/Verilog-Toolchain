module aes (
  input         clk,
  input         rst_n,
  input  [7:0]  data_in,
  input  [7:0]  key_in,
  
  input         load_in,
  input         unload_in,
  input         start_in,
  
  output [7:0]  data_out,
  output        busy_out
);

  // Components
  // External modules assumed to be declared elsewhere
  wire [7:0] data_in_map, key_in_map;
  wire [7:0] data_ser_to_p2s, data_sbox2_to_keu, data_to_mixc, data_to_bpu;
  wire [7:0] data_from_sbox1;
  wire       start_mixc;
  wire [7:0] data0_mixc_to_p2s, data1_mixc_to_p2s, data2_mixc_to_p2s, data3_mixc_to_p2s;
  wire       shift_bpu, load_bpu;
  wire [7:0] data_bpu_to_sbox1;
  wire       load_keu, shift_keu;
  wire [7:0] key_from_keu, key_d4_from_keu, data_keu_to_sbox2;
  wire       load_par_p2s, load_ser_p2s, shift_p2s;
  wire [7:0] data_ser_from_p2s;
  wire [3:0] round, sequence;
  wire [7:0] final_result, final_result_native;
  reg  [7:0] output_r;

  reg  [1:0] current_state_r, next_state;
  localparam LOAD = 2'd0, START = 2'd1, ACTIVE = 2'd2;

  wire [1:0] ext_control;

  reg  [3:0] round_r, sequence_r;

  // Combinational assignments
  assign data_ser_to_p2s = data_in_map;
  assign data_to_bpu     = data_ser_from_p2s ^ key_d4_from_keu;
  assign final_result_native = data_from_sbox1 ^ key_from_keu;
  assign data_to_mixc    = data_from_sbox1;
  assign data_out        = output_r;
  assign ext_control     = {load_in, unload_in};
  assign round           = round_r;
  assign sequence        = sequence_r;

  // State and sequence counters
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state_r <= LOAD;
      sequence_r      <= 4'd0;
      round_r         <= 4'd0;
    end else begin
      current_state_r <= next_state;
      case (current_state_r)
        LOAD: begin
          if (start_in || (load_in && !unload_in))
            sequence_r <= 4'd0;
          else if (unload_in && sequence_r != 4'd15)
            sequence_r <= sequence_r + 1;
          round_r <= 4'd0;
        end
        START: begin
          sequence_r <= 4'd1;
          round_r    <= 4'd0;
        end
        ACTIVE: begin
          sequence_r <= sequence_r + 1;
          if (sequence_r == 4'd15)
            round_r <= round_r + 1;
        end
      endcase
    end
  end

  // Output register
  always @(posedge clk) begin
    if (shift_bpu)
      output_r <= final_result;
  end

  // Control FSM
  reg busy_out_reg;
  assign busy_out = busy_out_reg;

  reg shift_p2s_reg, shift_keu_reg, shift_bpu_reg;
  reg load_bpu_reg, load_keu_reg, load_ser_p2s_reg;
  reg start_mixc_reg, load_par_p2s_reg;

  assign shift_p2s = shift_p2s_reg;
  assign shift_keu = shift_keu_reg;
  assign shift_bpu = shift_bpu_reg;
  assign load_bpu = load_bpu_reg;
  assign load_keu = load_keu_reg;
  assign load_ser_p2s = load_ser_p2s_reg;
  assign start_mixc = start_mixc_reg;
  assign load_par_p2s = load_par_p2s_reg;

  always @(*) begin
    busy_out_reg = 0;
    shift_p2s_reg = 0;
    shift_keu_reg = 0;
    shift_bpu_reg = 0;
    load_bpu_reg = 0;
    load_keu_reg = 0;
    load_ser_p2s_reg = 0;
    start_mixc_reg = 0;
    load_par_p2s_reg = 0;

    case (current_state_r)
      LOAD: begin
        case (ext_control)
          2'b00: ;
          2'b01: begin
            shift_p2s_reg = 1;
            shift_keu_reg = 1;
            shift_bpu_reg = 1;
          end
          2'b10: begin
            load_bpu_reg = 1;
            load_keu_reg = 1;
            load_ser_p2s_reg = 1;
          end
          2'b11: begin
            shift_keu_reg = 1;
            shift_bpu_reg = 1;
            load_bpu_reg = 1;
            load_keu_reg = 1;
            load_ser_p2s_reg = 1;
          end
        endcase
        next_state = (start_in) ? START : LOAD;
      end
      START: begin
        next_state = ACTIVE;
        if (sequence_r[1:0] == 2'b00)
          start_mixc_reg = 1;
        shift_bpu_reg = 1;
        shift_keu_reg = 1;
        shift_p2s_reg = 1;
        busy_out_reg = 1;
      end
      ACTIVE: begin
        if (sequence_r[1:0] == 2'b00) begin
          start_mixc_reg = 1;
          load_par_p2s_reg = 1;
        end
        shift_bpu_reg = 1;
        shift_keu_reg = 1;
        shift_p2s_reg = 1;
        busy_out_reg = 1;
        next_state = (round_r == 4'd9 && sequence_r == 4'd0) ? LOAD : ACTIVE;
      end
    endcase
  end

  // Instantiations
  map_8bit map_data (
    .byte_in(data_in),
    .mapo(data_in_map)
  );

  map_8bit map_key (
    .byte_in(key_in),
    .mapo(key_in_map)
  );

  invmap_8bit invmap_data (
    .invmap(final_result_native),
    .byte_out(final_result)
  );

  sbox_8bit native_sbox1 (
    .sbin(data_bpu_to_sbox1),
    .sbout(data_from_sbox1)
  );

  sbox_8bit native_sbox2 (
    .sbin(data_keu_to_sbox2),
    .sbout(data_sbox2_to_keu)
  );

  bytepermutation bpu (
    .clk(clk),
    .data_in(data_to_bpu),
    .data_out(data_bpu_to_sbox1),
    .seq_in(sequence),
    .shift_in(shift_bpu),
    .load_in(load_bpu)
  );

  keyexpansion keu (
    .clk(clk),
    .key_in(key_in_map),
    .key_out(key_from_keu),
    .key_d4_out(key_d4_from_keu),
    .data_to_sbox_out(data_keu_to_sbox2),
    .data_from_sbox_in(data_sbox2_to_keu),
    .load_in(load_keu),
    .shift_in(shift_keu),
    .seq_in(sequence),
    .round_in(round)
  );

  native_mixcolumns mixc (
    .clk(clk),
    .start_in(start_mixc),
    .data_in(data_to_mixc),
    .data0_out(data0_mixc_to_p2s),
    .data1_out(data1_mixc_to_p2s),
    .data2_out(data2_mixc_to_p2s),
    .data3_out(data3_mixc_to_p2s)
  );

  par2ser p2s (
    .clk(clk),
    .load_par_in(load_par_p2s),
    .load_ser_in(load_ser_p2s),
    .shift_in(shift_p2s),
    .data_serial_in(data_ser_to_p2s),
    .data_serial_out(data_ser_from_p2s),
    .data_parallel0_in(data0_mixc_to_p2s),
    .data_parallel1_in(data1_mixc_to_p2s),
    .data_parallel2_in(data2_mixc_to_p2s),
    .data_parallel3_in(data3_mixc_to_p2s)
  );

endmodule