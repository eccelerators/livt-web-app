-- Startup acceptance for the single-clock Arty WebApp wrapper.
-- The responsive AXI slave returns idle status; it does not model network traffic.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;
entity startup_tb is end;
architecture test of startup_tb is
 signal clk : std_logic := '0';
 signal nrst : std_logic := '0';
 signal awaddr, araddr : std_logic_vector(12 downto 0);
 signal awvalid,wvalid,bready,arvalid,rready : std_logic;
 signal wdata,rdata : std_logic_vector(31 downto 0) := (others=>'0');
 signal wstrb : std_logic_vector(3 downto 0);
 signal bvalid,rvalid : std_logic := '0';
 signal uart,detected : std_logic;
 signal reads,writes,uart_edges : natural := 0;
 signal awseen,wseen : boolean := false;
 signal captured_address : std_logic_vector(12 downto 0);
 signal captured_data : std_logic_vector(31 downto 0);
begin
 clk <= not clk after 5 ns;
 nrst <= '1' after 2 us;
 dut: entity work.webapp_wrapper port map (
 Clk=>clk,nRst=>nrst,M_AXI_AWREADY=>'1',M_AXI_WREADY=>'1',M_AXI_BRESP=>"00",M_AXI_BVALID=>bvalid,
 M_AXI_ARREADY=>'1',M_AXI_RDATA=>rdata,M_AXI_RRESP=>"00",M_AXI_RVALID=>rvalid,
 M_AXI_AWADDR=>awaddr,M_AXI_AWVALID=>awvalid,M_AXI_WDATA=>wdata,M_AXI_WSTRB=>wstrb,
 M_AXI_WVALID=>wvalid,M_AXI_BREADY=>bready,M_AXI_ARADDR=>araddr,M_AXI_ARVALID=>arvalid,M_AXI_RREADY=>rready,
 UartRx=>'1',UartTx=>uart,EthernetFrameDetected=>detected);
 process(clk) begin
 if rising_edge(clk) then
  if nrst='0' then bvalid<='0';rvalid<='0';awseen<=false;wseen<=false;
  else
   if arvalid='1' and rvalid='0' then
    rvalid<='1';rdata<=(others=>'0');reads<=reads+1;
    if unsigned(araddr)=6140 or unsigned(araddr)=8188 then
     assert writes=3 report "RX polling began before MAC initialization" severity failure;
    end if;
    if reads<8 then report "AXI read " & integer'image(to_integer(unsigned(araddr)));end if;
   elsif rready='1' then rvalid<='0';end if;
   if awvalid='1' then awseen<=true;captured_address<=awaddr;end if;
   if wvalid='1' then wseen<=true;captured_data<=wdata;end if;
   if awseen and wseen and bvalid='0' then
    bvalid<='1';awseen<=false;wseen<=false;writes<=writes+1;
    case writes is
     when 0 => assert unsigned(captured_address)=0 and captured_data=x"005E0000" report "Wrong first MAC word" severity failure;
     when 1 => assert unsigned(captured_address)=4 and captured_data=x"0000CEFA" report "Wrong second MAC word" severity failure;
     when 2 => assert unsigned(captured_address)=2044 and captured_data=x"00000003" report "Wrong MAC programming command" severity failure;
     when others => assert false report "Unexpected initialization write" severity failure;
    end case;
    report "AXI write completed";
   elsif bready='1' then bvalid<='0';end if;
  end if;
 end if;
 end process;
 process(uart) begin
 if falling_edge(uart) then uart_edges<=uart_edges+1;end if;
 end process;
 process begin
 wait for 100 us;
 report "reads=" & integer'image(reads) & " writes=" & integer'image(writes) & " UART falling edges=" & integer'image(uart_edges);
 assert reads>3 report "Ethernet driver did not poll" severity failure;
 assert writes=3 report "Ethernet MAC initialization missing" severity failure;
 assert uart_edges>0 report "Application UART did not start" severity failure;
 report "PASS: packaged wrapper boot";
 finish;
 end process;
end;
