library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.livt_lang_package.all;
use work.livt_lang_icontext_package.all;
use work.livt_net_iaxi4liteethernetlitemaster_package.all;
use work.livt_webapp_artywebapp_package.all;

entity uart_banner is
  generic (TEST_CLOCK_HZ : positive := 10000000);
end;
architecture test of uart_banner is
  signal clk : std_logic := '0';
  signal rst : std_logic := '1';
  signal tx : std_logic;
  signal ctx : t_icontext_in;
  constant clock_period : time := 1 sec / TEST_CLOCK_HZ;
  constant bit_time : time := (TEST_CLOCK_HZ / 115200) * clock_period; -- default 8N1
  constant banner : string := "Eccelerators GmbH" & character'val(13) & character'val(10) &
    "FPGA Conference 2026" & character'val(13) & character'val(10);
begin
  clk <= not clk after clock_period / 2;
  ctx <= (clk, rst, to_unsigned(TEST_CLOCK_HZ, 32), to_unsigned(1000000000 / TEST_CLOCK_HZ, 32),
          to_unsigned(500000000 / TEST_CLOCK_HZ, 32), to_unsigned(500000000 / TEST_CLOCK_HZ, 32));
  dut: entity work.livt_webapp_artywebapp
    generic map (LVT_CLOCK_HZ => to_unsigned(TEST_CLOCK_HZ, 32)) port map(
    ctor_axi_in => (m_axi_awready => '0', m_axi_wready => '0', m_axi_bresp => "00",
      m_axi_bvalid => '0', m_axi_arready => '0', m_axi_rdata => x"00000000",
      m_axi_rresp => "00", m_axi_rvalid => '0'),
    ctor_axi_out => open,
    ctor_local_mac => (others => (others => '0')),
    ctor_local_ip => (others => (others => '0')),
    ctor_local_port => (others => (others => '0')),
    ctor_uart_rx => '1', ctor_uart_tx => tx, ctor_ethernet_frame_detected => open,
    ctor_lvt_context_in => ctx,
    @GETTER_PORTS@);

  watchdog: process begin
    wait for 20 ms;
    assert false report "UART banner timed out" severity failure;
  end process;

  check: process
    variable received : std_logic_vector(7 downto 0);
  begin
    for boot in 1 to 2 loop
      rst <= '1'; wait for 10 * clock_period;
      rst <= '0';
      for index in banner'range loop
        wait until falling_edge(tx);
        wait for bit_time / 2;
        assert tx = '0' report "Invalid UART start bit" severity failure;
        for bit_index in 0 to 7 loop
          wait for bit_time;
          received(bit_index) := tx;
        end loop;
        wait for bit_time;
        assert tx = '1' report "Invalid UART stop bit" severity failure;
        assert received = std_logic_vector(to_unsigned(character'pos(banner(index)), 8))
          report "Incorrect banner byte at index " & integer'image(index) severity failure;
      end loop;
      -- No duplicate banner while Main continues polling an unresponsive AXI slave.
      report "Decoded banner after boot " & integer'image(boot);
      for cycle in 1 to TEST_CLOCK_HZ / 2000 loop
        wait until rising_edge(clk);
        assert tx = '1' report "Unexpected UART output after banner" severity failure;
      end loop;
    end loop;
    report "Simulation finished: WebApp UART banner and reset";
    std.env.stop;
    wait;
  end process;
end;
