library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;
library work;
	use work.livt_lang_package.all;
	use work.livt_net_drivers_ethernetlite_iaxi4liteethernetlitemaster_package.all;

entity webapp_wrapper is
	generic (
		LocalMacHex : string := "00005E00FACE";
		LocalIpHex : string := "0A000002";
		LocalPort : natural range 0 to 65535 := 80
	);
	port (
		Clk: in std_logic;
		nRst: in std_logic;
		M_AXI_AWREADY : in std_logic;
		M_AXI_WREADY : in std_logic;
		M_AXI_BRESP : in std_logic_vector(1 downto 0);
		M_AXI_BVALID : in std_logic;
		M_AXI_ARREADY : in std_logic;
		M_AXI_RDATA : in std_logic_vector(31 downto 0);
		M_AXI_RRESP : in std_logic_vector(1 downto 0);
		M_AXI_RVALID : in std_logic;
		M_AXI_AWADDR : out std_logic_vector(12 downto 0);
		M_AXI_AWVALID : out std_logic;
		M_AXI_WDATA : out std_logic_vector(31 downto 0);
		M_AXI_WSTRB : out std_logic_vector(3 downto 0);
		M_AXI_WVALID : out std_logic;
		M_AXI_BREADY : out std_logic;
		M_AXI_ARADDR : out std_logic_vector(12 downto 0);
		M_AXI_ARVALID : out std_logic;
		M_AXI_RREADY : out std_logic;
		UartRx: in std_logic;
		UartTx: out std_logic;
		EthernetFrameDetected: out std_logic
	);
    attribute X_INTERFACE_INFO : string;
    attribute X_INTERFACE_PARAMETER : string;
    attribute X_INTERFACE_INFO of M_AXI_AWREADY : signal is "xilinx.com:interface:aximm:1.0 M_AXI AWREADY";
    attribute X_INTERFACE_INFO of M_AXI_WREADY : signal is "xilinx.com:interface:aximm:1.0 M_AXI WREADY";
    attribute X_INTERFACE_INFO of M_AXI_BRESP : signal is "xilinx.com:interface:aximm:1.0 M_AXI BRESP";
    attribute X_INTERFACE_INFO of M_AXI_BVALID : signal is "xilinx.com:interface:aximm:1.0 M_AXI BVALID";
    attribute X_INTERFACE_INFO of M_AXI_ARREADY : signal is "xilinx.com:interface:aximm:1.0 M_AXI ARREADY";
    attribute X_INTERFACE_INFO of M_AXI_RDATA : signal is "xilinx.com:interface:aximm:1.0 M_AXI RDATA";
    attribute X_INTERFACE_INFO of M_AXI_RRESP : signal is "xilinx.com:interface:aximm:1.0 M_AXI RRESP";
    attribute X_INTERFACE_INFO of M_AXI_RVALID : signal is "xilinx.com:interface:aximm:1.0 M_AXI RVALID";
    attribute X_INTERFACE_INFO of M_AXI_AWADDR : signal is "xilinx.com:interface:aximm:1.0 M_AXI AWADDR";
    attribute X_INTERFACE_INFO of M_AXI_AWVALID : signal is "xilinx.com:interface:aximm:1.0 M_AXI AWVALID";
    attribute X_INTERFACE_INFO of M_AXI_WDATA : signal is "xilinx.com:interface:aximm:1.0 M_AXI WDATA";
    attribute X_INTERFACE_INFO of M_AXI_WSTRB : signal is "xilinx.com:interface:aximm:1.0 M_AXI WSTRB";
    attribute X_INTERFACE_INFO of M_AXI_WVALID : signal is "xilinx.com:interface:aximm:1.0 M_AXI WVALID";
    attribute X_INTERFACE_INFO of M_AXI_BREADY : signal is "xilinx.com:interface:aximm:1.0 M_AXI BREADY";
    attribute X_INTERFACE_INFO of M_AXI_ARADDR : signal is "xilinx.com:interface:aximm:1.0 M_AXI ARADDR";
    attribute X_INTERFACE_INFO of M_AXI_ARVALID : signal is "xilinx.com:interface:aximm:1.0 M_AXI ARVALID";
    attribute X_INTERFACE_INFO of M_AXI_RREADY : signal is "xilinx.com:interface:aximm:1.0 M_AXI RREADY";
    attribute X_INTERFACE_PARAMETER of M_AXI_AWADDR : signal is
        "XIL_INTERFACENAME M_AXI, PROTOCOL AXI4LITE, ADDR_WIDTH 13, DATA_WIDTH 32, READ_WRITE_MODE READ_WRITE";
    attribute X_INTERFACE_INFO of Clk : signal is "xilinx.com:signal:clock:1.0 Clk CLK";
    attribute X_INTERFACE_PARAMETER of Clk : signal is
        "XIL_INTERFACENAME Clk, ASSOCIATED_BUSIF M_AXI, ASSOCIATED_RESET nRst, FREQ_HZ 100000000";
    attribute X_INTERFACE_INFO of nRst : signal is "xilinx.com:signal:reset:1.0 nRst RST";
    attribute X_INTERFACE_PARAMETER of nRst : signal is "XIL_INTERFACENAME nRst, POLARITY ACTIVE_LOW";

end;

architecture behavioural of webapp_wrapper is

    constant WEBAPP_RESET_DELAY_CYCLES : natural := 1024;
	constant LocalPortU16 : unsigned(15 downto 0) := to_unsigned(LocalPort, 16);

	signal Rst : std_logic;
	signal s_axi_out : t_iaxi4liteethernetlitemaster_out;
    signal reset_delay_counter : natural range 0 to WEBAPP_RESET_DELAY_CYCLES := 0;
    signal delayed_nRst : std_logic := '0';

	function hex_nibble(hex_char : character) return std_logic_vector is
	begin
		case hex_char is
			when '0' => return x"0";
			when '1' => return x"1";
			when '2' => return x"2";
			when '3' => return x"3";
			when '4' => return x"4";
			when '5' => return x"5";
			when '6' => return x"6";
			when '7' => return x"7";
			when '8' => return x"8";
			when '9' => return x"9";
			when 'a' | 'A' => return x"A";
			when 'b' | 'B' => return x"B";
			when 'c' | 'C' => return x"C";
			when 'd' | 'D' => return x"D";
			when 'e' | 'E' => return x"E";
			when 'f' | 'F' => return x"F";
			when others => return x"0";
		end case;
	end function;

	function hex_byte(hex_string : string; index : positive) return std_logic_vector is
	begin
		return hex_nibble(hex_string(index)) & hex_nibble(hex_string(index + 1));
	end function;

	function to_byte_array_6(b0, b1, b2, b3, b4, b5 : std_logic_vector(7 downto 0)) return logic_array_2d is
		variable result : logic_array_2d(5 downto 0, 7 downto 0);
	begin
		for i in 0 to 7 loop
			result(0, i) := b0(i);
			result(1, i) := b1(i);
			result(2, i) := b2(i);
			result(3, i) := b3(i);
			result(4, i) := b4(i);
			result(5, i) := b5(i);
		end loop;
		return result;
	end function;

	function to_byte_array_4(b0, b1, b2, b3 : std_logic_vector(7 downto 0)) return logic_array_2d is
		variable result : logic_array_2d(3 downto 0, 7 downto 0);
	begin
		for i in 0 to 7 loop
			result(0, i) := b0(i);
			result(1, i) := b1(i);
			result(2, i) := b2(i);
			result(3, i) := b3(i);
		end loop;
		return result;
	end function;

	function to_byte_array_2(b0, b1 : std_logic_vector(7 downto 0)) return logic_array_2d is
		variable result : logic_array_2d(1 downto 0, 7 downto 0);
	begin
		for i in 0 to 7 loop
			result(0, i) := b0(i);
			result(1, i) := b1(i);
		end loop;
		return result;
	end function;

begin

    -- AXI Ethernet Lite needs a few cycles after s_axi_aresetn is released
    -- before it is accessed, so keep only the ArtyWebApp AXI master reset longer.
    webapp_reset_delay_process : process (Clk)
    begin
        if rising_edge(Clk) then
            if nRst = '0' then
                reset_delay_counter <= 0;
                delayed_nRst <= '0';
            elsif reset_delay_counter < WEBAPP_RESET_DELAY_CYCLES then
                reset_delay_counter <= reset_delay_counter + 1;
                delayed_nRst <= '0';
            else
                delayed_nRst <= '1';
            end if;
        end if;
    end process;

	Rst <= not delayed_nRst;

	-- Drive M_AXI master outputs from ArtyWebApp
	M_AXI_AWADDR  <= s_axi_out.m_axi_awaddr;
	M_AXI_AWVALID <= s_axi_out.m_axi_awvalid;
	M_AXI_WDATA   <= s_axi_out.m_axi_wdata;
	M_AXI_WSTRB   <= s_axi_out.m_axi_wstrb;
	M_AXI_WVALID  <= s_axi_out.m_axi_wvalid;
	M_AXI_BREADY  <= s_axi_out.m_axi_bready;
	M_AXI_ARADDR  <= s_axi_out.m_axi_araddr;
	M_AXI_ARVALID <= s_axi_out.m_axi_arvalid;
	M_AXI_RREADY  <= s_axi_out.m_axi_rready;

	webapp_i : entity work.livt_webapp_artywebapp
		port map (
			ctor_lvt_context_in          => (clk => Clk, rst => Rst,
                tickspersecond => to_unsigned(100000000, 32),
                periodns => to_unsigned(10, 32),
                hightimens => to_unsigned(5, 32), lowtimens => to_unsigned(5, 32)),
			ctor_axi_in                  => (
				m_axi_awready => M_AXI_AWREADY,
				m_axi_wready  => M_AXI_WREADY,
				m_axi_bresp   => M_AXI_BRESP,
				m_axi_bvalid  => M_AXI_BVALID,
				m_axi_arready => M_AXI_ARREADY,
				m_axi_rdata   => M_AXI_RDATA,
				m_axi_rresp   => M_AXI_RRESP,
				m_axi_rvalid  => M_AXI_RVALID
			),
			ctor_axi_out                 => s_axi_out,
			ctor_local_mac               => to_byte_array_6(
				hex_byte(LocalMacHex, 1), hex_byte(LocalMacHex, 3), hex_byte(LocalMacHex, 5),
				hex_byte(LocalMacHex, 7), hex_byte(LocalMacHex, 9), hex_byte(LocalMacHex, 11)),
			ctor_local_ip                => to_byte_array_4(
				hex_byte(LocalIpHex, 1), hex_byte(LocalIpHex, 3),
				hex_byte(LocalIpHex, 5), hex_byte(LocalIpHex, 7)),
			ctor_local_port              => to_byte_array_2(
				std_logic_vector(LocalPortU16(15 downto 8)),
				std_logic_vector(LocalPortU16(7 downto 0))),
			ctor_ethernet_frame_detected => EthernetFrameDetected,
			ctor_uart_rx                 => UartRx,
			ctor_uart_tx                 => UartTx
		);

end;
