# Implementation Details

## SPI Protocol

This module should implement a SPI master. The output frequency of `SCLK` should be the host clock frequency (the frequency of the signal `clk`) divided by `CLK_DIVIDE`. `CLK_DIVIDE` is guaranteed to be even and ≥ 4. `SCLK` should have a 50% duty cycle. The slave will expect to clock in data on rising edges of `SCLK`; therefore, this module should output new `MOSI` values on `SCLK` falling edges. Similarly, you should latch `MISO` input bits on `SCLK` rising edges. (You may see this SPI mode referred to as CPHA=0, CPOL=0.) Note that `SCLK` idles low outside of a SPI transaction.

For the purposes of this assignment, there should be a minimum delay of half an `SCLK` bit period between the `SS_N` falling edge and the first `SCLK` rising edge, and between the last falling edge of `SCLK` and the `SS_N` rising edge. The waveform diagram above shows the minimum. In both cases, longer is acceptable.

## Command Interface

The remaining ports on this module make up the command interface that the rest of the system would use to control your module.

The data to be transmitted on `MOSI` will be placed on the `tx_data` port. The number of bits to be transmitted will be `n_clks`. This value is guaranteed to be ≥1 and ≤ `SPI_MAXLEN`. The first bit of data to be transmitted will be bit `tx_data[n_clks-1]` and the last bit transmitted will be `tx_data[0]`. On completion of the SPI transaction, `rx_miso` should hold the data clocked in from `MISO` on each positive edge of `SCLK`. `rx_miso[n_clks-1]` should hold the first bit and `rx_miso[0]` will be the last. This module indicates that it is ready to begin a transaction by holding `spi_drv_rdy` low.

When the host wants to issue a SPI transaction, it will set `start_cmd` high. Your module should acknowledge that it is beginning to execute the transaction by dropping `spi_drv_rdy` low. Once the host sees `spi_drv_rdy` go low, it will drop `start_cmd` low on the next host clock cycle. This completes the command handshake. Your module should raise `spi_drv_rdy` again once the transaction is complete to indicate that it is ready to being a new transaction. Received data on `rx_miso` must be present when `spi_drv_rdy` goes high and must remain stable until the next command starts.

---

> **Note:** The above content is extracted verbatim from `Kepler.Space`.
