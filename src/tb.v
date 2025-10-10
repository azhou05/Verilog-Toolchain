`timescale 1ns / 1ps

module aes_tb;

  // Inputs
  reg clk;
  reg rst_n;
  reg [127:0] data_in;
  reg [127:0] key_in;
  reg start_in;

  // Outputs
  wire [127:0] data_out;
  wire busy_out;

  // Instantiate the Unit Under Test (UUT)
  // Ensure your parallel AES module is named 'aes' or update the name here.
  aes uut (
    .clk(clk),
    .rst_n(rst_n),
    .data_in(data_in),
    .key_in(key_in),
    .start_in(start_in),
    .data_out(data_out),
    .busy_out(busy_out)
  );

  // Clock generation (100MHz)
  initial clk = 0;
  always #5 clk = ~clk;

  // Test sequence
  initial begin
    // Initial values
    rst_n   = 0;
    data_in = 128'h00;
    key_in  = 128'h00;
    start_in = 0;

    // Reset pulse
    #20 rst_n = 1;

    // Wait for end of reset
    @(posedge clk);
    
    // Provide a known plaintext and key
    // AES test vector: Plaintext=00112233445566778899aabbccddeeff, Key=000102030405060708090a0b0c0d0e0f
    data_in = 128'h00112233445566778899aabbccddeeff;
    key_in  = 128'h000102030405060708090a0b0c0d0e0f;

    // Start encryption with a single-cycle pulse
    start_in = 1;
    @(posedge clk);
    start_in = 0;

    // Wait for the encryption to finish by monitoring 'busy_out'
    wait (busy_out == 1'b0);

    $display("--------------------------------------------------");
    $display("AES Encryption Complete at time %t", $time);
    $display("Plaintext:  %h", 128'h00112233445566778899aabbccddeeff);
    $display("Key:        %h", 128'h000102030405060708090a0b0c0d0e0f);
    $display("Ciphertext: %h", data_out);
    // Expected Ciphertext for the above vector: 69c4e0d86a7b0430d8cdb78070b4c55a
    $display("--------------------------------------------------");

    #100;
    $finish;
  end

  // VCD dump setup
  initial begin
    $dumpfile("dump.vcd");
    // Corrected: Explicitly dump all signals in the aes_tb scope and below.
    $dumpvars(0, aes_tb);
  end

endmodule