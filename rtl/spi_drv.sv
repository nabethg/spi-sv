// SPI Master Module
//
//  This module is used to implement a SPI master. The host will want to transmit a certain number
// of SCLK pulses. This number will be placed in the n_clks port. It will always be less than or
// equal to SPI_MAXLEN.
//
// SPI bus timing
// --------------
// This SPI clock frequency should be the host clock frequency divided by CLK_DIVIDE. This value is
// guaranteed to be even and >= 4. SCLK should have a 50% duty cycle. The slave will expect to clock
// in data on the rising edge of SCLK; therefore this module should output new MOSI values on SCLK
// falling edges. Similarly, you should latch MISO input bits on the rising edges of SCLK.
//
//  Example timing diagram for n_clks = 4:
//  SCLK        ________/-\_/-\_/-\_/-\______ 
//  MOSI        ======= 3 | 2 | 1 | 0 =======
//  MISO        ======= 3 | 2 | 1 | 0 =======
//  SS_N        ------\_______________/------
//
// Command Interface
// -----------------
// The data to be transmitted on MOSI will be placed on the tx_data port. The first bit of data to
// be transmitted will be bit tx_data[n_clks-1] and the last bit transmitted will be tx_data[0].
//  On completion of the SPI transaction, rx_miso should hold the data clocked in from MISO on each
// positive edge of SCLK. rx_miso[n_clks-1] should hold the first bit and rx_miso[0] will be the last.
//
//  When the host wants to issue a SPI transaction, the host will hold the start_cmd pin high. While
// start_cmd is asserted, the host guarantees that n_clks and tx_data are valid and stable. This
// module acknowledges receipt of the command by issuing a transition on spi_drv_rdy from 1 to 0.
// This module should then being performing the SPI transaction on the SPI lines. This module indicates
// completion of the command by transitioning spi_drv_rdy from 0 to 1. rx_miso must contain valid data
// when this transition happens, and the data must remain stable until the next command starts.
//


module spi_drv #(
    parameter integer               CLK_DIVIDE  = 100, // Clock divider to indicate frequency of SCLK
    parameter integer               SPI_MAXLEN  = 32   // Maximum SPI transfer length
) (
  input                           clk,
  input                           sresetn,        // active low reset, synchronous to clk
  
  // Command interface 
  input                           start_cmd,     // Start SPI transfer
  output                          spi_drv_rdy,   // Ready to begin a transfer
  input  [$clog2(SPI_MAXLEN):0]   n_clks,        // Number of bits (SCLK pulses) for the SPI transaction
  input  [SPI_MAXLEN-1:0]         tx_data,       // Data to be transmitted out on MOSI
  output [SPI_MAXLEN-1:0]         rx_miso,       // Data read in from MISO
  
  // SPI pins
  output                          SCLK,          // SPI clock sent to the slave
  output                          MOSI,          // Master out slave in pin (data output to the slave)
  input                           MISO,          // Master in slave out pin (data input from the slave)
  output                          SS_N           // Slave select, will be 0 during a SPI transaction
);
  // Register outputs
  logic [SPI_MAXLEN-1:0] rx_shift;
  logic MOSI_reg, SS_N_reg, rdy_reg;
  assign spi_drv_rdy = rdy_reg;
  assign rx_miso     = rx_shift;
  assign MOSI        = MOSI_reg;
  assign SS_N        = SS_N_reg;

  // Transaction FSM state
  typedef enum logic [1:0] {
    IDLE,
    ASSERT_SS,
    TRANSFER,
    DEASSERT_SS
  } xact_state_t;

  xact_state_t state;
  logic [$clog2(SPI_MAXLEN):0] bit_cnt;

  // Clock divider enabled for asserted SS
  logic div_clk, strobe_rise, strobe_fall;
  clk_div #(
      .CLK_DIVIDE(CLK_DIVIDE)
  ) u_clk_div (
      .clk_in     (clk),
      .sresetn    (sresetn),
      .enable     (~SS_N_reg),
      .clk_out    (div_clk),
      .strobe_rise(strobe_rise),
      .strobe_fall(strobe_fall)
  );
  assign SCLK = div_clk & (state == TRANSFER);

  // Transaction FSM datapath
  always_ff @(posedge clk) begin
    if (!sresetn) begin
      state    <= IDLE;
      rdy_reg  <= 1'b1;
      SS_N_reg <= 1'b1;
      MOSI_reg <= 1'b0;
      bit_cnt  <= '0;
      rx_shift <= '0;
    end else begin
      // default assignments
      state    <= state;
      rdy_reg  <= rdy_reg;
      SS_N_reg <= SS_N_reg;
      MOSI_reg <= MOSI_reg;
      bit_cnt  <= bit_cnt;
      rx_shift <= rx_shift;

      case (state)
        // Wait for command
        IDLE: begin
          rdy_reg  <= 1'b1;
          SS_N_reg <= 1'b1;
          if (start_cmd) begin
            rdy_reg  <= 1'b0;
            bit_cnt  <= n_clks;
            rx_shift <= '0;
            state    <= ASSERT_SS;
          end
        end

        // Initiate transfer
        ASSERT_SS: begin
          if (~start_cmd) begin
            SS_N_reg <= 1'b0;
            MOSI_reg <= tx_data[bit_cnt-1];  // preload MSB
            state <= TRANSFER;
          end
        end

        // Shift bits
        TRANSFER: begin
          // CPHA=0, CPOL=0
          if (strobe_rise) begin
            // latch MISO on rising edge
            rx_shift[bit_cnt-1] <= MISO;
            bit_cnt <= bit_cnt - 1;
          end
          if (strobe_fall) begin
            // drive MOSI on falling edge
            if (bit_cnt > 0) MOSI_reg <= tx_data[bit_cnt-1];
            else if (bit_cnt == 0) state <= DEASSERT_SS;
          end
        end

        // Terminate transfer
        DEASSERT_SS: begin
          if (strobe_rise) begin  // delay
            SS_N_reg <= 1'b1;
            rdy_reg  <= 1'b1;
            state    <= IDLE;
          end
        end
      endcase
    end
  end  // always_ff
endmodule
