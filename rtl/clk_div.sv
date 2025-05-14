/**
 * @brief Idle-low (CPHA=0), enabled clock divider with predictive edge strobes.
 *
 * Divides the host clk_in frequency by CLK_DIVIDE for an idle-low clk_out.
 * Generates one-cycle pulses on strobe_rise and strobe_fall immediately before 
 * each clk_out rising and falling transition, respectively.
 */
module clk_div #(
    parameter integer CLK_DIVIDE = 100
) (
  input  logic clk_in,
  input  logic sresetn,      // active-low synchronous reset
  input  logic enable,
  output logic clk_out,      // divided-clock
  output logic strobe_rise,  // pulse at clk_out rising
  output logic strobe_fall   // pulse at clk_out falling
);
  localparam integer DUTY_HIGH = CLK_DIVIDE / 2;  // 0.5 duty cycle

  logic [$clog2(CLK_DIVIDE)-1:0] cnt;

  always_ff @(posedge clk_in) begin
    if (!sresetn || !enable) begin
      cnt <= '0;
    end else begin
      cnt <= (cnt == CLK_DIVIDE - 1) ? '0 : cnt + 1;
    end
  end

  assign clk_out     = (cnt >= DUTY_HIGH);
  assign strobe_rise = (cnt == DUTY_HIGH - 1);
  assign strobe_fall = (cnt == CLK_DIVIDE - 1);

endmodule
