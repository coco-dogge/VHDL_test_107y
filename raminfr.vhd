
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;


entity raminfr is
generic ( 
          bits : integer := 6;               -- number of bits per RAM word
          addr_bits : integer := 15);         -- 2^addr_bits = number of words in RAM

port (clk : in std_logic;
       we : in std_logic;
        a : in std_logic_vector(addr_bits-1 downto 0);
       di : in std_logic_vector(bits-1 downto 0);
       do : out std_logic_vector(bits-1 downto 0));
end raminfr;

--Block RAM with synchronous read (read through) cont'd
architecture behavioral of raminfr is
type ram_type is array (2**addr_bits-1 downto 0) of std_logic_vector (bits-1 downto 0);
signal RAM : ram_type;
signal read_a : std_logic_vector(addr_bits-1 downto 0);

begin
process (clk)
begin
   if (clk'event and clk = '1') then
      if (we = '1') then
         RAM(conv_integer(unsigned(a))) <= di;
      end if;
      read_a <= a;
   end if;
end process;

do <= RAM(conv_integer(unsigned(read_a)));
  
end behavioral;
