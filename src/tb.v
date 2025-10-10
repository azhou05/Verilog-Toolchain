`timescale 1ns / 1ps

module aes_tb;

  // Inputs
  reg clk;
  reg rst_n;
  reg [7:0] data_in;
  reg [7:0] key_in;
  reg load_in;
  reg unload_in;
  reg start_in;

  // Outputs
  wire [7:0] data_out;
  wire busy_out;

  // Instantiate the Unit Under Test (UUT)
  aes uut (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(data_in),
    .key_in(key_in),
    .load_in(load_in),
    .unload_in(unload_in),
    .start_in(start_in),
    .data_out(data_out),
    .busy_out(busy_out)
  );

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;  // 100MHz clock

  // Test sequence
  initial begin
    // Initial values
    rst_n = 0;
    data_in = 8'h00;
    key_in = 8'h00;
    load_in = 0;
    unload_in = 0;
    start_in = 0;

    // Reset pulse
    #1000 rst_n = 1;

    ////////////////////////////////////////////
    ////////////////////////////////////////////
    ////////////////////////////////////////////
    // Load key and data
    @(posedge clk);
    data_in = 8'hA0;  // example input data
    key_in = 8'h0A;   // example key
    load_in = 1;
    unload_in = 0;
    repeat (3) @(posedge clk);

    @(posedge clk);
    data_in = 8'hB0;  // example input data
    key_in = 8'h0B;   // example key
    load_in = 1;
    unload_in = 0;
    repeat (3) @(posedge clk);    

    @(posedge clk);
    data_in = 8'hC0;  // example input data
    key_in = 8'h0C;   // example key
    load_in = 1;
    unload_in = 0;
    repeat (3) @(posedge clk);

    @(posedge clk);
    data_in = 8'hD0;  // example input data
    key_in = 8'h0D;   // example key
    load_in = 1;
    unload_in = 0;    
    repeat (3) @(posedge clk);




  
    @(posedge clk);
    load_in = 0;
    unload_in = 0;
    start_in = 1;

    repeat (143) @(posedge clk);
    start_in = 0;
    repeat (4) @(posedge clk);
    unload_in = 1;
    repeat (16) @(posedge clk);
    unload_in = 0;

  end

// always @(posedge clk) begin
//   if (unload_in) begin
//     // $display("Time %t: data_out = %02h", $time, data_out);
//     $display("data_out = %02h", data_out);    
//   end
// end

  reg [7:0] data_out_buffer [0:15];
  integer i;
  integer unload_count;

always @(posedge clk) begin
  if (unload_in) begin
    data_out_buffer[unload_count] = data_out;
    unload_count = unload_count + 1;

    if (unload_count == 16) begin
      // $write("Decrypted Output: ");
      for (i = 0; i < 16; i = i + 1) begin
        $write("%02h", data_out_buffer[i]);
      end
      $write("\n");
    end
  end else begin
    unload_count = 0; // reset counter when unload is low
  end
end


    initial  begin
    $dumpfile ("dump.vcd"); 
    $dumpvars; 
    end 

    initial 
    #3000 $finish;     
        
endmodule
