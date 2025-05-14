`timescale 1ns / 1ps

module tb_spi_drv;
  localparam CLK_PERIOD = 10;  // 100 MHz
  localparam SPI_MAXLEN = 32;
  typedef logic [$clog2(SPI_MAXLEN):0] count_t;
  localparam NUM_RAND_XACTS = 10_000;

  // DUT interfaces
  logic clk;
  logic sresetn;
  logic start_cmd;
  logic spi_drv_rdy;
  logic [$clog2(SPI_MAXLEN):0] n_clks;
  logic [SPI_MAXLEN-1:0] tx_data;
  logic [SPI_MAXLEN-1:0] rx_miso;
  logic SCLK;
  logic MOSI;
  logic MISO;
  logic SS_N;

  spi_drv #(
      .CLK_DIVIDE(4),
      .SPI_MAXLEN(SPI_MAXLEN)
  ) dut (
      .clk        (clk),
      .sresetn    (sresetn),
      .start_cmd  (start_cmd),
      .spi_drv_rdy(spi_drv_rdy),
      .n_clks     (n_clks),
      .tx_data    (tx_data),
      .rx_miso    (rx_miso),
      .SCLK       (SCLK),
      .MOSI       (MOSI),
      .MISO       (MISO),
      .SS_N       (SS_N)
  );

  task reset_dut(int unsigned n_clks = 10);
    start_cmd = 1'b0;
    sresetn   = 1'b0;
    repeat (n_clks) @(posedge clk);
    sresetn = 1'b1;
    @(posedge clk);
  endtask

  // Clock generator
  initial clk = 0;
  always #(CLK_PERIOD / 2) clk = ~clk;

  // Test result count
  int unsigned n_tests = '0, n_fails = '0;
  task flush_test_count(input string label);
    $display("%0d/%0d %s tests passed", n_tests - n_fails, n_tests, label);
    n_tests = 0;
    n_fails = 0;
  endtask

  // Task performing SPI transaction, verifying TX/RX data, and tracking results
  task spi_xact(count_t n_bits, input logic [SPI_MAXLEN-1:0] tx_pat,
                input logic [SPI_MAXLEN-1:0] rx_pat);
    bit tx_err, rx_err;
    logic [SPI_MAXLEN-1:0] tx_mosi;

    // Initialize inputs
    n_clks = n_bits;
    tx_data = tx_pat;
    tx_mosi = '0;
    MISO = rx_pat[n_bits-1];  // preload MSB

    // Pulse start_cmd
    @(posedge clk);
    start_cmd = 1'b1;
    @(negedge spi_drv_rdy);
    @(posedge clk);
    start_cmd = 1'b0;

    // Serial transfer
    for (int i = n_bits - 1; i >= 0; i--) begin
      @(posedge SCLK);
      tx_mosi[i] = MOSI;
      @(negedge SCLK);
      if (i > 0) MISO = rx_pat[i-1];
    end

    // End of transaction
    @(posedge spi_drv_rdy);

    // Track result counts
    tx_err = (tx_mosi !== tx_pat);
    rx_err = (rx_miso !== rx_pat);
    if (tx_err || rx_err) begin
      n_fails++;
      $display("Transaction error occurred!");
      if (tx_err) $display("TX error: got %0h expected %0h", tx_mosi, tx_pat);
      if (rx_err) $display("RX error: got %0h expected %0h", rx_miso, rx_pat);
      $display("\n");
    end
    n_tests++;
  endtask

  // Top-level stimulus
  initial begin
    int unsigned idle_cycles;
    logic [$clog2(SPI_MAXLEN):0] n_bits;
    logic [SPI_MAXLEN-1:0] tx_data, rx_data, mask;

    reset_dut(1);

    // Manual tests
    spi_xact(1, 1'b1, 1'b0);
    spi_xact(4, 4'hA, 4'h3);
    spi_xact(6, 6'b101011, 6'b011100);
    spi_xact(5, 5'b11011, 5'b01001);
    spi_xact(7, 7'b1010101, 7'b1100110);
    spi_xact(9, 9'b111001001, 9'b001110011);
    spi_xact(32, 32'hDEADBEEF, 32'h4B504C52);  // h4B504C52 is KPLR in ASCII :D

    flush_test_count("manual");

    // Random tests
    for (int j = 0; j < NUM_RAND_XACTS; j++) begin
      n_bits = $urandom_range(1, SPI_MAXLEN);
      mask = {SPI_MAXLEN{1'b1}} >> (SPI_MAXLEN - n_bits);
      tx_data = $urandom & mask;
      rx_data = $urandom & mask;

      spi_xact(n_bits, tx_data, rx_data);

      idle_cycles = $urandom_range(0, 15);
      repeat (idle_cycles) @(posedge clk);
    end

    flush_test_count("random");

    $finish;
  end

endmodule
