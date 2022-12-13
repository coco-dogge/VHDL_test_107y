--FOR EP3C16Q240C8
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;
use ieee.numeric_std.all;

entity OLED128x32 is
port(    	      	                                      --接腳說明   
        ck, nReset  :in std_logic;                     --震盪輸入(149) & RESET按鈕(145) 
        TSL2561_sda : INOUT  STD_LOGIC;                 --TSL2561 IIC SDA()
        TSL2561_scl : INOUT  STD_LOGIC;                 --TSL2561 IIC SCL()                                                             

        SD178_sda  : INOUT  STD_LOGIC;                  --SD178B IIC SDA() 
        SD178_scl  : INOUT  STD_LOGIC;                  --SD178B IICSCL()     
        SD178_nrst : buffer    STD_LOGIC;                  --SD178B nRESET ()  
	
        SHT11_PIN : inout  STD_LOGIC;                   -- DHT11 PIN 

        sw    : IN std_logic_vector(7 downto 0);    --DIP SW()
        ki   : IN std_logic_vector(3 downto 0);        --BUTTON ()               
        ko  : buffer  std_logic_vector(3 downto 0);  
        debug  : OUT    STD_LOGIC;  
        	
        segout  :buffer std_logic_vector(7 downto 0);      --左邊七段顯示器資料腳()
        segout_2:buffer std_logic_vector(7 downto 0);      --右邊七段顯示器資料腳()       	        	        	
        seg_scan:buffer std_logic_vector(7 downto 0);          --右邊七段顯示器掃描腳()           
                
        BL,RES,CS,DC,SDA,SCL : OUT    STD_LOGIC;        --LCD
        
        LED:buffer std_logic_vector(15 downto 0);
        
        motor_out1,motor_out2,motor_pwm1 : OUT    STD_LOGIC
         
    );
end OLED128x32;
architecture beh of OLED128x32 is

component i2c_master is
  GENERIC(
    input_clk : INTEGER := 50_000_000; --input clock speed from user logic in Hz
    bus_clk   : INTEGER := 100_000);   --speed the i2c bus (scl) will run at in Hz
  PORT(
    clk       : IN     STD_LOGIC;                    --system clock
    reset_n   : IN     STD_LOGIC;                    --active low reset
    ena       : IN     STD_LOGIC;                    --latch in command
    addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0); --address of target slave
    rw        : IN     STD_LOGIC;                    --'0' is write, '1' is read
    data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0); --data to write to slave
    busy      : OUT    STD_LOGIC;                    --indicates transaction in progress
    data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0); --data read from slave
    ack_error : BUFFER STD_LOGIC;                    --flag if improper acknowledge from slave
    sda       : INOUT  STD_LOGIC;                    --serial data output of i2c bus
    scl       : INOUT  STD_LOGIC);                   --serial clock output of i2c bus
end component i2c_master; 

component TSL2561 is 
port(
	  clk_50M:in std_logic;
     nrst:in std_logic;

     sda       : INOUT  STD_LOGIC;                   --TSL2561 IIC SDA(161)
     scl       : INOUT  STD_LOGIC;                   --TSL2561 IIC SCL(160)                                                             
     
     TSL2561_data : OUT  std_logic_vector(14 downto 0)

     );
end component TSL2561;

component DHT11 is 
port(
	   clk_50M:in std_logic;
     nrst:in std_logic;
     dat_bus: inout std_logic;
     HU, TE:out std_logic_vector(7 downto 0);        --????, ????
     error: out std_logic
     
     );
end component DHT11;

component sync_segscan IS
PORT(
     clk:in std_logic;
     ch_0:in std_logic_vector(3 downto 0);
     ch_1:in std_logic_vector(3 downto 0);
     ch_2:in std_logic_vector(3 downto 0);
     ch_3:in std_logic_vector(3 downto 0);
     dot :in std_logic_vector(0 to 3);
     sync_segout:out std_logic_vector(7 downto 0);
     sync_segsel:out std_logic_vector(0 to 3)
    );
end component sync_segscan ;

component up_mdu2 is
   port(    
        ck:in std_logic;    
        fout:buffer std_logic   
       );
end component up_mdu2;

component up_mdu3 is
   port(    
        ck:in std_logic;    
        fout:buffer std_logic   
       );
end component up_mdu3;

component up_mdu4 is
   port(    
        ck:in std_logic;    
        fout:buffer std_logic   
       );
end component up_mdu4;

component up_mdu5 is
   port(    
        ck:in std_logic;    
        fout:buffer std_logic   
       );
end component up_mdu5;

component cmd_rom is
   port(    
        address   : IN std_logic_vector(15 downto 0); 
        data_out  : OUT std_logic_vector(7 downto 0); 
        DC_data   : OUT std_logic   
       );
end component cmd_rom;

--component raminfr is
--generic ( 
--          bits : integer := 6;                -- number of bits per RAM word
--          addr_bits : integer := 15);         -- 2^addr_bits = number of words in RAM
--
--port (clk : in std_logic;
--       we : in std_logic;
--        a : in std_logic_vector(addr_bits-1 downto 0);
--       di : in std_logic_vector(bits-1 downto 0);
--       do : out std_logic_vector(bits-1 downto 0));
--end component raminfr;   
            
type State_type3 is (sd178_init, event_check, sd178_send , sd178_d1, sd178_d2, sd178_d3, sd178_d4, sd178_d5, sd178_delay1,sd178_delay2, sd178_set_ch,sd178_play1,sd178_play2);
SIGNAL  sd178State  : State_type3; 

type State_type4 is (event_check, s0, s1, s2, s3, s4, button1_process, button2_process, button3_process, button4_process, button5_process);
SIGNAL  Main_State  : State_type4;

--LCD NUMBER DATA
type oled_num_16x16 is array (0 to 15,0 to 15) of std_logic_vector(0 to 15);                      --10個數值資料 + 2個英文字資??
constant num_table1:oled_num_16x16:=
(   
   (
   	X"0000",	X"0000",	X"03e0",	X"1c18",	X"300c",	X"300c",	X"7006",	X"6006",
   	X"6006",	X"6006",	X"300c",	X"300c",	X"1818",	X"07f0",	X"0000",	X"0000"
   ),
   (
	   X"0000",	X"0000",	X"0080",	X"0f80",	X"0180",	X"0180",	X"0180",	X"0180",
	   X"0180",	X"0180",	X"0180",	X"0180",	X"0180",	X"0ff0",	X"0000",	X"0000"  
   ),   
   (   
	  X"0000",	X"0000",	X"07c0",	X"1870",	X"2018",	X"4018",	X"0018",	X"0010",
	  X"0030",	X"00c0",	X"0100",	X"0600",	X"0806",	X"7ffc",	X"0000",	X"0000"   
   ),
   (
   	X"0000",	X"0000",	X"07e0",	X"1830",	X"2018",	X"0010",	X"0020",	X"01e0",
   	X"0638",	X"001c",	X"000c",	X"0008",	X"0010",	X"3fe0",	X"0000",	X"0000"
   ),
   (
   	X"0000",	X"0000",	X"0010",	X"0070",	X"00b0",	X"0130",	X"0230",	X"0c30",
   	X"1830",	X"2030",	X"7ffe",	X"0030",	X"0030",	X"0030",	X"0000",	X"0000"
   ),
   (
   	X"0000",	X"0000",	X"03fc",	X"0600",	X"0400",	X"0c00",	X"1fe0",	X"0070",
   	X"0018",	X"000c",	X"000c",	X"0008",	X"0010",	X"3fe0",	X"0000",	X"0000"
   ),
   (
   	X"0000",	X"0000",	X"003c",	X"03c0",	X"0600",	X"1800",	X"31c0",	X"3e38",
   	X"700c",	X"600c",	X"2006",	X"3004",	X"1808",	X"07f0",	X"0000",	X"0000"
   ),
   (
   	X"0000",	X"0000",	X"1ffc",	X"100c",	X"2008",	X"0018",	X"0010",	X"0030",
   	X"0060",	X"0060",	X"00c0",	X"0080",	X"0180",	X"0300",	X"0000",	X"0000"
   ),
   (
   	X"0000",	X"0000",	X"07e0",	X"1818",	X"3008",	X"3018",	X"1c30",	X"07c0",
   	X"06e0",	X"1838",	X"300c",	X"3006",	X"300c",	X"0ff0",	X"0000",	X"0000"
   ),
   (
   	X"0000",	X"0000",	X"07c0",	X"1830",	X"300c",	X"200c",	X"700c",	X"300c",
   	X"180c",	X"07fc",	X"0018",	X"0030",	X"00c0",	X"3f00",	X"0000",	X"0000"
   ),
   (
   	X"ffff",	X"ffff",	X"ffff",	X"ffff",	X"ffff",	X"ffff",	X"ffff",	X"ffff",
   	X"ffff",	X"ffff",	X"ffff",	X"ffff",	X"ffff",	X"ffff",	X"ffff",	X"ffff"
   ),
   (
	   X"0000",	X"0000",	X"ff80",	X"3078",	X"100c",	X"100c",	X"100c",	X"1038",   --R
	   X"1fc0",	X"10c0",	X"1060",	X"1030",	X"3818",	X"fe0f",	X"0000",	X"0000"
	),	
	(
		X"0000",	X"0000",	X"ffff",	X"c183",	X"8181",	X"0180",	X"0180",	X"0180",   --T 
	   X"0180",	X"0180",	X"0180",	X"0180",	X"0180",	X"0ff0",	X"0000",	X"0000"  
	),
	(
	   X"0000",	X"0000",	X"0000",	X"0000",	X"0000",	X"0000",	X"03c0",	X"0180",   --:
	   X"0000",	X"0000",	X"0000",	X"0000",	X"0180",	X"03c0",	X"0000",	X"0000"	   
	),
	(
	   X"0000",	X"07e0",	X"0ff0",	X"1818",	X"380c",	X"300c",	X"6006",	X"6006",   --逆轉
	   X"6006",	X"6006",	X"300c",	X"300c",	X"1918",	X"0f30",	X"0700",	X"0f00"	   
	),
	(
	   X"0000",	X"07e0",	X"0ff0",	X"1818",	X"380c",	X"300c",	X"6006",	X"6006",   --正轉
	   X"6006",	X"6006",	X"300c",	X"300c",	X"1898",	X"0cf0",	X"00e0",	X"00f0"		   
	)
);
type oled_num_32x32 is array (0 to 9,0 to 31) of std_logic_vector(0 to 31);
constant num_table2:oled_num_32x32:=
(	
	(
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"0007E000",X"001E7800",X"001C3800",--0
	X"003C3C00",X"00381C00",X"00381C00",X"00781E00",X"00781E00",X"00700E00",X"00700E00",X"00700E00",
	X"00700E00",X"00700E00",X"00700E00",X"00781E00",X"00781E00",X"00381C00",X"00381C00",X"003C3C00",
	X"001C3800",X"000E7000",X"0007E000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000"
	),
	(
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"0001C000",X"0007C000",X"001FC000",--1
	X"0001C000",X"0001C000",X"0001C000",X"0001C000",X"0001C000",X"0001C000",X"0001C000",X"0001C000",
	X"0001C000",X"0001C000",X"0001C000",X"0001C000",X"0001C000",X"0001C000",X"0001C000",X"0001C000",
	X"0003C000",X"0003C000",X"000FF800",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000"
	),
	(
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"000FE000",X"001DF000",X"00387800",--2
	X"00303800",X"00303C00",X"00703C00",X"00603C00",X"00003C00",X"00003800",X"00003800",X"00007800",
	X"00007000",X"0000E000",X"0000E000",X"0001C000",X"00038000",X"00070000",X"000E0000",X"000C0E00",
	X"001C0C00",X"003FFC00",X"007FFC00",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000"
	),                                                                                            
	(                                                                                             
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"000FE000",X"001CF000",X"00387800",--3
	X"00303800",X"00303800",X"00003800",X"00003000",X"00007000",X"0000E000",X"0003E000",X"000FF800",
	X"00007800",X"00003C00",X"00001C00",X"00001C00",X"00001C00",X"00001C00",X"00001800",X"00003800",
	X"00003000",X"007CE000",X"003FC000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000"
	),                                                                                   
	(
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00007000",X"00007000",X"0000F000",--4
	X"0001F000",X"0001F000",X"0003F000",X"00037000",X"00077000",X"000E7000",X"000C7000",X"001C7000",
	X"00187000",X"00387000",X"00707000",X"00607000",X"007FFE00",X"00007000",X"00007000",X"00007000",
	X"00007000",X"00007000",X"00007000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000"
	),                                                                                            
	(                                                                                             
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000C00",X"0007FC00",X"0007F800",X"000E0000",--5
	X"000E0000",X"001C0000",X"001C0000",X"001F8000",X"003FC000",X"0037E000",X"0000F000",X"00007800",
	X"00003800",X"00003800",X"00001C00",X"00001C00",X"00001C00",X"00001800",X"00003800",X"00003800",
	X"00007000",X"007CE000",X"003FC000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000"
	),                                                                                   
	(
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000C00",X"0000FC00",X"0001C000",X"00078000",--6
	X"000F0000",X"000E0000",X"001E0000",X"001C0000",X"003C0000",X"003FF000",X"007E7800",X"00783C00",
	X"00781E00",X"00781E00",X"00701E00",X"00700E00",X"00780E00",X"00380E00",X"00380E00",X"00381C00",
	X"001C1C00",X"000E3800",X"0007F000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000"
	),                                                                                            
	(                                                                                             
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"003FFC00",X"003FFC00",X"00301C00",--7
	X"00701800",X"00603800",X"00003800",X"00003800",X"00003000",X"00007000",X"00007000",X"00007000",
	X"0000E000",X"0000E000",X"0000E000",X"0001C000",X"0001C000",X"0001C000",X"0003C000",X"00038000",
	X"00038000",X"00038000",X"00070000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000"
	),                                                                                   
	(
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"000FF000",X"001C3800",X"00381800",--8
	X"00381C00",X"00381C00",X"00381C00",X"003C3800",X"001C3800",X"001F7000",X"000FC000",X"0007E000",
	X"0007F000",X"000EF800",X"001C7800",X"00383C00",X"00381C00",X"00381C00",X"00381C00",X"00381C00",
	X"003C1C00",X"001C3800",X"000FF000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000"
	),                                                                                            
	(                                                                                             
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"000FE000",X"001C7000",X"00383800",--9
	X"00383C00",X"00781C00",X"00701C00",X"00701C00",X"00701E00",X"00781E00",X"00781E00",X"00381E00",
	X"003C1C00",X"001E7C00",X"000FFC00",X"00003C00",X"00003800",X"00007800",X"0000F000",X"0000E000",
	X"0001C000",X"00078000",X"003E0000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000"
	)                                                                                  
);
type LCD_over is array (0 to 3,0 to 31) of std_logic_vector(0 to 31);
constant over_table:LCD_over:=
(
	(
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",
	X"000FF000",X"001C7800",X"00383C00",X"00381C00",X"00701E00",X"00701E00",X"00700E00",X"00700E00",
	X"00700E00",X"00780E00",X"00780C00",X"00381C00",X"003C1800",X"001E3000",X"0007E000",X"00000000",
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000"
	),                                                                                            
	(                                                                                             
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",
	X"007F3E00",X"001C1C00",X"001C1800",X"001C3800",X"000E3800",X"000E3000",X"00077000",X"00077000",
	X"00076000",X"0003E000",X"0003E000",X"0003C000",X"0001C000",X"0001C000",X"00018000",X"00000000",
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000"
	),                                                                                            
	(                                                                                             
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",
	X"000FE000",X"001CF000",X"00387000",X"00307800",X"007FF800",X"00700000",X"00700000",X"00700000",
	X"00700000",X"00700000",X"00781C00",X"00781800",X"003C3000",X"001FE000",X"000FC000",X"00000000",
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000"
	),                                                                                            
	(                                                                                             
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",
	X"00077800",X"001FF800",X"003F8000",X"00078000",X"00070000",X"00070000",X"00070000",X"00070000",
	X"00070000",X"00070000",X"00070000",X"00070000",X"00070000",X"000F0000",X"003FC000",X"00000000",
	X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000",X"00000000"
	)
);
------------------------------------------------------------------------TSL2561
SIGNAL  TSL2561_data : STD_LOGIC_VECTOR(14 DOWNTO 0);
SIGNAL  TSL2561_int  :integer range 0 to 9999;            
SIGNAL  d0, d0_last  :integer range 0 to 9999;   
SIGNAL  lx1,lx2,lx3,lx4,lx5 :integer range 0 to 9;   	                                
------------------------------------------------------------------------DHT11
SIGNAL HU_BUFF, TE_BUFF : STD_LOGIC_VECTOR(7 DOWNTO 0);  
SIGNAL DHT11_error : STD_LOGIC;   
---------------------------------------------------------------------------------------------------KEYBOARD
--SIGNAL keyin,keyin_last : std_logic_vector(0 to 15);
signal pb:std_logic_vector(3 downto 0);
signal pe,per:std_logic;
signal swr:std_logic_vector(7 downto 0);

SIGNAL event_S1, event_S2, event_S3, event_S4, event_S5 , event_S6: STD_LOGIC;        
---------------------------------------------------------------------------------------------------7SEG
signal seg1:std_logic_vector(3 downto 0);
signal seg2:std_logic_vector(3 downto 0);
signal c1015:std_logic_vector(7 downto 0);
type seg_ram is array(0 to 7)of std_logic_vector(3 downto 0);
signal segr :seg_ram;
type seg_rom is array(0 to 15)of std_logic_vector(6 downto 0);
signal seg_num :seg_rom:=
(
	"1111110" ,"0110000" ,"1101101" ,"1111001" ,"0110011" ,"1011011" ,"0011111" ,"1110000" 
	,"1111111" ,"1110011" ,"1110111" ,"0011111" ,"1001110" ,"0111101" ,"1001111" ,"1000111"
);
--------------------------------------------------------------------------------------------------SD178B  
--SIGNAL  sd178_ena, sd178_rw, sd178_busy, sd178_ack_error  : std_logic;   
--SIGNAL  sd178_addr      : STD_LOGIC_VECTOR(6 DOWNTO 0);     
--SIGNAL  cnt_byte   :integer range 0 to 30; 
--SIGNAL  var_vol,var_vol_last  :integer range 0 to 9; 
signal sd178_ena, sd178_rw, sd178_busy : std_logic;
signal sd178_data_wr, sd178_data_rd : std_logic_vector(7 downto 0);
signal sdbyte : integer range 0 to 31;	--幾字元
signal sdtime: std_logic;				--延遲
signal sdsub : integer range 0 to 3;	--SD控制
signal sd_t : integer range 0 to 10_000_000;
type word_ram is array(0 to 19)of std_logic_vector(7 downto 0);                                
signal word_buf : word_ram:=( x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00");
--x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00");
 --"請你坐好謝謝" x"BD",x"D0",x"A7",x"41",x"B0",x"B5",x"A6",x"6E",x"C1",x"C2",x"C1",x"C2",x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00");
 --rt x"B7",x"4F",x"B7",x"4F",x"AD",x"44",x"AD",x"44",x"AF",x"75",x"A5",x"69",x"B7",x"52",x"BC",x"4B",x"BC",x"4B",x"00",x"00");
type wordnum_rom is array(0 to 9,0 to 1)of std_logic_vector(7 downto 0);
signal wordnum : wordnum_rom :=(
	( x"B9",x"73"),	( x"A4",x"40"),	( x"A4",x"47"),	( x"A4",x"54"),( x"A5",x"7C"),( x"A4",x"AD"),( x"A4",x"BB"),	
	
	( x"A4",x"43"),( x"A4",x"4B"),( x"A4",x"45")
);

  
-------------------------------------------------------------------------------------------other
SIGNAL  clk_1KHz,clk_1MHz, clk_100hz : STD_LOGIC;
signal rst:std_logic;
---------------------------------------------------------------       
SIGNAL  d3 :integer range 0 to 20; 

SIGNAL  mode , mode_motor :integer range 0 to 10;

------------------------------------------------------------------------------
SIGNAL  motor_speed   :integer range 0 to 10;
SIGNAL  motor_dir : STD_LOGIC;        
----------------------------------------------------------------------------LCD   
SIGNAL  clk_25MHz, clk: STD_LOGIC;
SIGNAL  x  :integer range 0 to 127; 
SIGNAL  y  :integer range 0 to 255; 
SIGNAL  d  :integer range 0 to 15;      
SIGNAL  fsm,fsm_back,fsm_back2   :integer range 0 to 150;
SIGNAL  address: STD_LOGIC_VECTOR(15 DOWNTO 0);
SIGNAL  RGB : STD_LOGIC_VECTOR(15 DOWNTO 0);
SIGNAL  add : STD_LOGIC_VECTOR(14 DOWNTO 0);
SIGNAL  e : STD_LOGIC_VECTOR(2 DOWNTO 0);
SIGNAL  data_out ,RGB_data,LCD_t  : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL  DC_data    : std_logic;   
---------------------------------------------------------------------RAM
SIGNAL we2   : std_logic;
SIGNAL a2     : std_logic_vector(14 downto 0);
SIGNAL di2, do2 : std_logic_vector(5 downto 0);
--===============================================================臨時
signal seg_a,seg_s:std_logic;



--=========================================
begin  


x<=CONV_INTEGER(add(6 DOWNTO 0));
y<=CONV_INTEGER(add(14 DOWNTO 7));


main:process(ck)            
variable t: integer range 0 to 10_000_000;
variable pbr:integer range 0 to 16;
variable start:std_logic;
variable s:integer range 0 to 31;
variable j:integer range 0 to 128;
----------------------------------------------
variable s1,s1s: integer range 0 to 10;
variable s2: integer range 0 to 10;
----------------------------------------------
variable sound:std_logic_vector(7 downto 0);
variable vol:integer range 0 to 9;
variable soun:integer range 0 to 2;
begin

if rising_edge(clk_1mhz) then
per<=pe;

if pe='1' and per='0' then
	pbr:=conv_integer(pb);
else
	pbr:=16;
end if;

if pbr=4 then
	s:=0;t:=0;
end if;

if pbr=0 then
	start:=not start;
end if;

LED(15 downto 11)<=conv_std_logic_vector(pbr,5);

case t is
when 0=>
----------------------------------------------------------
case s is
	when 0=>s1:=1;
			rst<='0';
			t:=1_000_000;
			s:=1;
			start:='0';
			s1s:=0;j:=0;--LCD
			seg_s<='0';segr<=(x"0", x"0", x"0", x"0", x"0", x"0", x"0", x"0");--SEG
			vol:=5;s2:=0;sdsub<=0;sd_t<=0;
	when 1=>rst<='1';
			case sw(1 downto 0) is
				when "00"=>s:=2;
				when "10"=>s:=3;
				when "01"=>s:=4;
				when "11"=>s:=5;
			end case;      
	when 2=>if start='1' then
				if s1s<6 then
					s1s:=s1s+1;
					s1:=s1s mod 2;
					t:=500_000;
				elsif j<128 then
					s1:=2;
					j:=j+1;
					t:=50_000;
				else
					j:=0;s1s:=0;s1:=0;
				end if;
			end if;	
	when 3=>if start='1' then
				seg_s<='1';
				t:=1_000_000;
				
				segr(7)  <= conv_std_logic_vector(lx1,4);
				segr(6)  <= conv_std_logic_vector(lx2,4);
				segr(5)  <= conv_std_logic_vector(lx3,4);
				segr(4)  <= conv_std_logic_vector(lx4,4);
				segr(3)  <= conv_std_logic_vector(lx5,4);
				
				if TSL2561_int<20 then
					seg_a<=not seg_a;
				else
					seg_a<='0';
				end if;
			end if;
	when 4=>case sdsub is
				when 0=>if start='1' then
							case s2 is
								when 0=>word_buf(0 to 1)<=(x"80" ,x"00");
										sdbyte<=2;
										sdsub<=1;
										sd_t<=0;
										s2:=1;
								when 1=>word_buf(0 to 6)<=(x"86" ,x"d2" ,x"88" ,x"27" ,x"0e" ,x"00" ,x"00");
										sdbyte<=8;
										sdsub<=1;
										sd_t<=0;
										s2:=2;
										sound:=x"d2";
								when 2=>if pbr=1 then
											vol:=vol+1;
											sound:=sound+10;
										end if;
										if pbr=2 then
											vol:=vol-1;
											sound:=sound-10;
										end if;
										if pbr=3 then
											s2:=3;
										end if;
								when 3=>word_buf(0 to 1)<=(x"80" ,x"00");
										sdbyte<=2;
										sdsub<=1;
										sd_t<=0;
										s2:=4;
								when 4=>word_buf(0 to 6)<=( x"86" ,sound ,x"88" ,x"27" ,x"0e" ,x"00" ,x"00");
										sdbyte<=8;
										sdsub<=1;
										sd_t<=500_000;
										s2:=2;
								when others=>null;
							end case;
						end if;
				when 1=>sdtime<='1';
						t:=200_000;
						sdsub<=2;
				when 2=>sdtime<='0';
						t:=sd_t;
						sdsub<=0;
						sd_t<=0;
				when others=>null;
			end case;

	when 5=>
	when others=>null;
end case;
----------------------------------------------------------		
when others=>t:=t-1;
end case;

case s1 is	
	when 0=>RGB<= not"0000000000000000";
	when 1=>RGB<= "0000000000000000";
	when others=>
				if(x=j or x=128-j)then 
					RGB<="0000000000000000";
				else 
					RGB<= "1111111111111111";
				end if;
end case;

		
		
----------------------------------------------------------------------

--
--								if sw(7 downto 6)="00" then
--									word_buf(0 to 1)<=(x"8B", x"03");--無聲道
--									sdbyte<=2;
--									sdsub<=1;
--									sd_t<=500_000;
--								elsif sw(7 downto 6)="01" then
--									word_buf(0 to 1)<=(x"8B", x"06");--右聲到
--									sdbyte<=2;
--									sdsub<=1;
--									sd_t<=500_000;
--								elsif sw(7 downto 6)="10" then
--									word_buf(0 to 1)<=(x"8B", x"05");--左聲道
--									sdbyte<=2;
--									sdsub<=1;
--									sd_t<=500_000;
--								elsif sw(7 downto 6)="11" then
--									word_buf(0 to 1)<=(x"8B", x"07");--雙聲道
--									sdbyte<=2;
--									sdsub<=1;
--									sd_t<=500_000;	
--								end if;
--		case sd_mode is
--			when 0=>
--			when 1=>case s is
--						when 0=>start:='0';
--						when 1=>s:=2;
--								vol:=5;
--						when 2=>if soun=1 then
--									vol:=vol+1;
--								elsif soun=2 then
--									vol:=vol-1;
--								end if;
--								s:=3;
--								s2:=1;
--						when 3=>if start='1' then 
--									case sdsub is
--										when 0=>case s2 is
--													when 0=>word_buf(0 to 1)<=(x"80" ,x"00" );
--															sdbyte<=2;
--															sdsub<=1;
--															start:='0';
--															s2:=0;
--													when 1=>word_buf(0 to 6)<=(x"86" ,x"d2" ,x"88" ,x"27" ,x"0e" ,x"00" ,x"00");
--															sdbyte<=8;
--															sdsub<=1;
--															sd_t<=0;
--															s2:=2;
--															sound:=x"d2";
--													when 2=>if soun=1 then
--																soun:=0;
--																vol:=vol+1;
--																sound:=sound+10;
--																word_buf(0 to 7)<=(x"80" ,x"86" ,sound ,x"88" ,x"27" ,x"0e" ,x"00" ,x"00");
--																sdbyte<=8;
--																sdsub<=1;
--																sd_t<=500_000;
--															elsif soun=2 then
--																soun:=0;
--																vol:=vol-1;
--																sound:=sound-10;
--																word_buf(0 to 7)<=(x"80" ,x"86" ,sound ,x"88" ,x"27" ,x"0e" ,x"00" ,x"00");
--																sdbyte<=8;
--																sdsub<=1;
--																sd_t<=500_000;
--															end if;
--															

															
--													when 3=>word_buf(0 to 1)<=(x"80" ,x"00" );
--															sdbyte<=2;
--															sdsub<=1;
--															sd_t<=500_000;
--															s2:=0;
--													when others=>null;
--												end case;
--									
--										when others=>null;
--									end case;
--								else
--									s2:=0;
--									start:='1';
--								end if;
--						when others=>null;
--					end case;
--			when others=>null;
--		end case;
--	
		
		
-----------------------------------------------------------------------		
end if;
      			
	   
end process;
--==============================================================================
LCD_driver:process(ck)
variable t:integer range 0 to 50_000_000;
variable c:integer range 0 to 2;
variable a:integer range 0 to 2;
variable j:integer range 0 to 128;
begin

--if rising_edge(LCD_t(4)) then
--if (LCD_run=1) then
--	case(d)is
--		when 0=> d<=1;e<= "001";
--		when 1=> d<=2;e<= "011";            
--		when 2=> d<=3;e<= "111";
--		when 3=> d<=4;e<= "001";
--		when 4=> d<=5;e<= "011";	
--		when 5=> d<=6;e<= "111";
--		when 6=> d<=7;e<= "001";	
--		when 7=> d<=8;e<= "011";
--		when others=>d<=0;e<= "111";
--	end case;
--end if;
--end if;
if rising_edge(ck) then --=(ck'EVENT AND ck='1')
--if LCD_rst='1'then
--	t:=0;a:=0;c:=0;j:=0;
--else
--	if (LCD_mode=1) then
--		case t is
--			when 0=>t:=25_000_000;
--					if j/=128 then
--						j:=j+1;
--					else
--						c:=0;j:=0;
--					end if;
--					if c/=2 then
--						if c=0 then
--							c:=1;
--						else
--							if a=2 then
--								a:=0;c:=2;
--							else
--								c:=0;a:=a+1;
--							end if;
--						end if;
--					end if;
--					
--			when others=>if LCD_run='1' then
--							t:=t-1;
--						end if;
--						case c is
--							when 0=>RGB<= not"0000000000000000";
--							when 1=>RGB<= "0000000000000000";
--										
--							when others=>
--											if(x=j or x=128-j)then 
--											RGB<="0000000000000000";
--											else RGB<= "1111111111111111";
--											end if;
--										
--						end case;
--		end case;
--	else
--		RGB<= not"0000000000000000";
--	end if;

	
--end if;
end if; 
end process;
--==============================================================================
tsl:process(clk_1mhz)
variable cnt_step:integer range 0 to 1;
begin
if rising_edge(clk_1mhz) then
	case cnt_step is                                 --轉換TSL2561資料 
		when 0=>TSL2561_int  <= CONV_INTEGER(TSL2561_data) mod 10000;
				cnt_step := 1;
		when 1=>cnt_step:=0;
				lx1 <= (TSL2561_int / 10000) mod 10;
				lx2 <= (TSL2561_int / 1000) mod 10;
				lx3 <= (TSL2561_int / 100) mod 10;
				lx4 <= (TSL2561_int / 10) mod 10;
				lx5 <= TSL2561_int mod 10;
	end case;
end if;
end process;
--==============================================================================
sd178_dri: process(ck)  --sd178
variable t      :integer range 0 to 50_000_000;       
variable cnt_loop       :integer range 0 to 50;       
variable cnt2,s178           :integer range 0 to 20;      
variable cnt_byte : integer range 0 to 31;
begin  
      if rising_edge(ck) then  --(ck'EVENT AND ck='1')   
         if(nReset='0' or rst='0')then 
            SD178_nrst <= '0'; 
            sd178_ena  <= '0';                                      
            s178   := 0;

         else
			if t=0 then
            CASE s178 IS  
               when 0=>  
                        SD178_nrst <= '1';
                        s178 := 1; 
 						t :=  12_000_000 ;           	
               when 1=>  
                  
						--if (sdflag = '1') then 
						if (sdtime = '1') then 
							cnt_byte := sdbyte;-- 18;           	           
							-- word_buf <= word2;     
							--word_buf <= w_1;  							                 	                               
                            s178 :=2; 
                           -- led(15 downto 12) <= led(15 downto 12) + 1;
                        end if; 
                        --end if;
			   
               WHEN 2 =>                   
                                                
                        cnt2 := 0;
                        cnt_loop := 0;
                        s178 := 3;                                                                                                                               
                                                                       
               WHEN 3=>                                       --start write data

--                      sd178_addr      <= "0100000";               --write sd178_address 0x20
                        sd178_data_wr   <= word_buf(cnt_loop);	           --更換資料                         
                        sd178_rw        <= '0';                     --0/write  
                        s178      := 4;
                        
                        cnt_loop := cnt_loop + 1;                   --傳送資料上數+1 
               WHEN 4=>                      
                        sd178_ena   <= '1';                                                                    
                        s178  := 5;  

               WHEN 5=>                      
                        if sd178_busy = '1' then  
                            if cnt_loop >= cnt_byte  then 
                               sd178_ena    <= '0';
                               s178   := 7;                                                          
                            else                            
                               sd178_data_wr <= word_buf(cnt_loop);         --command    
                               sd178_rw      <= '0';                 --0/write                                                                                                                                                                             
                               cnt_loop := cnt_loop + 1;             --傳送資料上數+1
                               s178    := 6;
                           end if; 
                        end if;                         
               WHEN 6=>            
                        if sd178_busy = '0' then                             
                           sd178_ena    <= '0';                                                                                       
                           if cnt_loop >= cnt_byte  then                --cnt_byte 傳送數量
                              s178  := 7;   
                           else                           
                              s178    := 8;                                                                                                                                                                                                                                           
                           end if;          
                        end if; 
                           
               WHEN 8=>   s178 := 3;t:=500_000;      --delay10ms&redo
                           
               WHEN 7=>   s178 := 9;t:=10_000_000;   --delay0.2s&end

               WHEN 9=>                                   
						if (sdtime = '0') then                       
                            s178 :=0;
						end if;     
              when others =>                                          
                        s178    := 0;
                          
            END CASE;
         else t:=t-1;                  
		end if;
       end if;
      end if;    
end process;
--==============================================================================
key:process(clk_1Mhz)
variable x: std_logic_vector(1 downto 0);
begin

if rising_edge(clk_1Mhz) then
	case x is
		when "00"=> if ki/="1111"  then x:="01"; pb<="0000"; ko<="1110"; end if;
		when "01"=> if ki="1111" then ko<=ko(2 downto 0)& ko(3); pb<=pb+1;
					else x:="10"; pe<='1';
						if ki(3)<='0' then pb(3 downto 2)<="11";
						else pb(3 downto 2)<=not ki(2 downto 1);
						end if;  
					end if;
		when others=>if ki="1111" then x:="00"; ko<="0000";pe<='0'; end if; 
	end case;
end if;
end process;
--=================================================================
SEG_driver:process(ck)--七段顯示器
variable x:	std_logic_vector (2 downto 0);
variable t: integer range 0 to 1_000_000;
variable s: integer range 0 to 11;

begin

if rising_edge(clk_1Mhz) then

if rst='0' then
	segout<=x"00";
	segout_2<=x"00";
elsif seg_s='1' then
	x:=x+1;
	if x<4 then
		seg1<=segr(conv_integer(x));
	else
		seg2<=segr(conv_integer(x));
	end if;
	if c1015=x"00" then
		seg_scan<=not x"80";
		c1015<=x"40";
	else
		c1015<='0' & c1015(7 downto 1);
		seg_scan <= not c1015;
	end if;
	
	if c1015=x"20" then segout<="00011100";
	elsif c1015=x"40" then segout<="01111100";
	elsif c1015=x"00" then segout<="01101110";
	else
		segout(7 downto 1)  <=seg_num(conv_integer(seg1));
		segout_2(7 downto 1)<=seg_num(conv_integer(seg2));
	end if;
	
	if c1015=x"01" then
		segout_2(0)<=seg_a;
	else
		segout_2(0)<='0';
	end if;
	
end if;	
end if;

end process;

--========================================================================
BL  <= '1';
process(clk_25MHz, nReset)          -- LCD
      variable delay_1         :integer range 0 to 25000000;                                                      	               	
      variable bit_cnt         :integer RANGE 0 TO 7 := 7;
      variable hi_lo           :integer range 0 to 1;
      variable address_start,address_end   : STD_LOGIC_VECTOR(14 DOWNTO 0); 	               	
      variable disp_color      : STD_LOGIC_VECTOR(5 DOWNTO 0); 	               	
      variable pos_x_start,pos_y_start :integer range 0 to 159;  
      variable pos_x,pos_y    :integer range 0 to 39;         
      variable pos_now              :integer range 0 to 20479;   	                  
      variable varl,cnt_number,cnt_number_max   :integer range 0 to 20;                                      
      variable cnt1           :integer range 0 to 99;                  
      variable bit_index   :integer range 0 to 16; 	               	
               
	begin	
      if(nReset ='0')then 
         RES <= '1';
         DC  <= '0';                              -- command
         CS  <= '1';
         SCL <= '1';                                     	                
         fsm <= 0;
         delay_1 :=0;
         address <= "0000000000000000";
                  
       else IF(clk_25MHz'EVENT AND clk_25MHz='1')then 
                      
     

--         if (event_S1 = '1') then                    -- 開始顏色DEMO  
--                      
--            fsm <= 1;                        
--            DC  <= '0';                              -- 設為預設值
--            CS  <= '1';
--            SCL <= '1';                                     	                
--            delay_1 :=0;
--            address <= "0000000000000000";
--            
--         elsif (event_S3 = '1') then                 -- 停止顏色DEMO
--            fsm <= 0;                        
--            DC  <= '0';                              -- 設為預設值
--            CS  <= '1';
--            SCL <= '1';                                     	                
--            delay_1 :=0;
--            address <= "0000000000000000";
         
--         else
if (delay_1 )=0 then
            CASE fsm IS                                          
               when 0 =>   fsm <= 1;                           -- idle
                              
               when 1 =>                             -- 硬體RESET, 0-2 
                        RES <= '1'; 
                        delay_1 :=25000;
                         fsm <= 2;                 
--                        if delay_1 >= 25000 then     -- 1ms = 40ns x 25000
--                           delay_1 :=0;                           
--                           fsm <= 2;
--                        else
--                           delay_1:=delay_1+1;                          
--                        end if;

               when 2 =>                             
                        RES <= '0';                  -- 1ms
                        delay_1 :=25000;
                        fsm <= 3;
--                        if delay_1 >= 25000 then                     
--                           delay_1 :=0;                           
--                           fsm <= 3;
--                        else
--                           delay_1:=delay_1+1;                          
--                        end if;

               when 3 =>                            
                        RES <= '1';                  -- 120ms
                        delay_1 :=3000000;
                        fsm <= 4;
--                        if delay_1 >= 3000000 then                
--                           delay_1 :=0;  
--                           fsm   <=  4;
--                           
--                        else
--                           delay_1:=delay_1+1;                          
--                        end if;               

               when 4 =>                                --start loop ,lcd初始化命令,共85BYTES
                        if(address = "0000000001010101") then  
                           fsm        <= 5;                
                        else
                           fsm        <= 50;               
                           fsm_back   <=  4;            
                        end if;
                           
               when 5 =>   
                                    
                        delay_1 :=3000000;
                        fsm <= 6;                             -- 初始化後延遲    
--                        if delay_1 >= 3000000 then       -- 120ms                                         
--                           delay_1 :=0; 
--                           fsm     <= 6; 
--                        else
--                           delay_1:=delay_1+1;                          
--                        end if;

               when 6 =>                                -- idle   
--                        if (mode = 0) then
--                           fsm     <= 60; 
--                        elsif ((mode = 1) or (mode = 3)) then   
                           fsm     <= 10;   
--                        elsif (mode = 2) then   
--                           fsm     <= 110;                                                                                  
--                        end if;                                                                     
               
               when 10 =>                                ----------------------更新畫面,DISP_WINDOWS ,10-13     
                        address <= "0000000001001010";                     
                        fsm        <= 11;                

               when 11 =>                                --loop ,DISP_WINDOWS 命令    
                        if(address = "0000000001010101") then  --共11BYTES
                           add <= "000000000000000";
                           fsm        <= 12;                
                        else
                           fsm        <= 50;               
                           fsm_back   <= 11;            
                        end if;
                           
               when 12 =>                              -- start loop ,read ram                                 
                        hi_lo := 0;
                        we2  <= '0';
						if(add = 20480) then  fsm <= 10;LCD_t<=LCD_t+1;else add<=add+1;--fsm_back2;  -- 完成更新 --                        a2   <= address(14 downto 0);               -- set address                                           
                        fsm  <= 13; end if;                       

               when 13 =>                              -- read ram                                 
                        if(hi_lo = 0)then              -- COLOR HI BYTE 
                                                       -- R - f800   G - 07e0  B - 001f 
                           RGB_data <= RGB(15 downto 8);
                                         
                              
                           
                              fsm        <= 40;               
                              fsm_back   <= 13;            
--                           end if;
                                                                                 
                        else                             --COLOR LO BYTE                         
                           RGB_data <=  RGB(7 downto 0);
                              
                           fsm        <= 40;  
                           fsm_back   <= 12;                                                     
                        end if;                      

--               when 20 =>                                    --write ram -全部清除,全黑,20-26
--                        address <= '0' & address_start;                     
--                        fsm     <= 21;
--
--               when 21 =>                                    
--                        a2   <= address(14 downto 0);        -- set address                                                                
--                        fsm  <= 22;
--                        
--               when 22 =>                                    -- set data
--                        di2  <= disp_color;                  
--                        fsm  <= 23; 
--                        
--               when 23 =>                                    -- write
--                        we2  <= '1';
--                        fsm  <= 24; 
--
--               when 24 =>                                    -- write
--                        we2  <= '0';
--                        fsm  <= 25; 
--
--               when 25 =>                                    -- address
--                        address <= address + "0000000000000001";                                                                
--                        fsm  <= 26; 
--                        
--               when 26 =>                                    -- address
--                        if(address = address_end) then       -- 128 * 160
--                           fsm        <= fsm_back;                
--                        else
--                           fsm        <= 21;               
--                        end if;                                    
                  

               when 40 =>                             --------------------------------- write data START,40-45 
                        DC  <= '1';    
                        fsm <= 41; 
               when 41 =>                             -- CS = 0              
                        CS  <= '0';
                        bit_cnt := 7;  
                        fsm <= 42;                       
               
               when 42 =>                             -- LOOP x 8 ,set data            
                        SDA <= RGB_data(bit_cnt); 
                        fsm <= 43;                      
                        
               when 43 =>                             -- CLK = 0 
                        SCL <= '0';                           
                        fsm <= 44;
                                              
               when 44 =>                             -- CLK = 1 
                        SCL <= '1';                           
                        bit_cnt := bit_cnt - 1;
                        
                        if bit_cnt >= 7 then
                           fsm <= 45;                      
                        else
                           fsm <= 42;                                           
                        end if;
                           
               when 45 =>                             -- CS = 1              
                        CS  <= '1';                     
                        if(hi_lo = 0)then
                           hi_lo := 1;
                        else
                           hi_lo := 0; 
                           address <= address + "0000000000000001";                          
                        end if;   
                        fsm <= fsm_back;                                                               

               when 50 =>                             -------------------------- write command START,50-55
                        DC  <= DC_data;    
                        fsm <= 51;                     
                        
               when 51 =>                             -- CS = 0              
                        CS  <= '0';
                        bit_cnt := 7;  
                        fsm <= 52;                       
               
               when 52 =>                             -- LOOP x 8 ,set data            
                        SDA <= data_out(bit_cnt); 
                        fsm <= 53;                      
                        
               when 53 =>                             -- CLK = 0 
                        SCL <= '0';                           
                        fsm <= 54;
                                              
               when 54 =>                             -- CLK = 1 
                        SCL <= '1';                           
                        bit_cnt := bit_cnt - 1;
                        
                        if bit_cnt >= 7 then
                           fsm <= 55;                      
                        else
                           fsm <= 52;                                           
                        end if;
                           
               when 55 =>                             -- CS = 1              
                        CS  <= '1';
                        address <= address + "0000000000000001"; 
                        fsm <= fsm_back;             

   ----------------------------------------------------------------------------       
               when 59 =>
                                       
                        delay_1 :=25000000;
                        fsm <=fsm_back2;                                 -- delay 1s
--                        if delay_1 >= 25000000 then                     
--                           delay_1 :=0;                           
--                           fsm <= fsm_back2;
--                        else
--                           delay_1:=delay_1+1;                          
--                        end if;
   ----------------------------------------------------------------------------  MODE = "00" ,顏色展示    
--               when 60 =>                                   -- 1 修改圖型    
--                        address_start := "000000000000000";
--                        address_end   := "101000000000000";
--                        disp_color    := "111111";          -- R - f800   G - 07e0  B - 001f                    
--                        fsm       <= 20;                   
--                        fsm_back  <= 61;                             
--
--               when 61 =>                                   --更新畫面    
--                        fsm       <= 10;                   
--                        fsm_back2 <= 62;   
--
--               when 62 =>                                   -- delay 1s  
--                        delay_1 :=0; 
--                        fsm       <= 59;                           
--                        fsm_back2 <= 63;
--                                
--               when 63 =>                                  -- 2 修改圖型                                                             
--                        address_start := "000000000000000";
--                        address_end   := "001100100000000";
--                        disp_color    := "000001";         -- R"00"G"00"B"00"                   
--                        fsm       <= 20;                   
--                        fsm_back  <= 64;                             
--    
--               when 64 =>                                  -- 更新畫面    
--                        fsm       <= 10;                   
--                        fsm_back2 <= 65;
--
--               when 65 =>                                  -- delay 1s  
--                        delay_1 :=0;    
--                        fsm       <= 59;                       
--                        fsm_back2 <= 66;
--
--               when 66 =>                                  -- 3 修改圖型 
--                        address_start := "000000000000000";
--                        address_end   := "001100100000000";
--                        disp_color    := "000010";         -- R"00"G"00"B"00"                   
--                        fsm       <= 20;                   
--                        fsm_back  <= 67;
--
--               when 67 =>                                  -- 更新畫面    
--                        fsm       <= 10;                   
--                        fsm_back2 <= 68;
--
--               when 68 =>                                  -- delay 1s  
--                        delay_1 :=0; 
--                        fsm       <= 59;                           
--                        fsm_back2 <= 69;
--               
--               when 69 =>                                  -- 4
--                        address_start := "000000000000000";
--                        address_end   := "001100100000000";
--                        disp_color    := "000011";         -- R"00"G"00"B"00"                   
--                        fsm       <= 20;                   
--                        fsm_back  <= 70;
--
--               when 70 =>                                  -- 更新畫面    
--                        fsm       <= 10;                   
--                        fsm_back2 <= 71;
--
--               when 71 =>                                  -- delay 1s  
--                        delay_1 :=0;  
--                        fsm       <= 59;                          
--                        fsm_back2 <= 72;           
--
--               when 72 =>                                  -- 5
--                        address_start := "001100100000000";
--                        address_end   := "011001000000000";
--                        disp_color    := "010000";         -- R"00"G"00"B"00"                   
--                        fsm       <= 20;                   
--                        fsm_back  <= 73;
--
--               when 73 =>                                  -- 更新畫面    
--                        fsm       <= 10;                   
--                        fsm_back2 <= 74;
--
--               when 74 =>                                  -- delay 1s  
--                        delay_1 :=0;  
--                        fsm       <= 59;                          
--                        fsm_back2 <= 75; 
--
--
--               when 75 =>                                  -- 6
--                        address_start := "001100100000000";
--                        address_end   := "011001000000000";
--                        disp_color    := "100000";         -- R"00"G"00"B"00"                   
--                        fsm       <= 20;                   
--                        fsm_back  <= 76;
--
--               when 76 =>                                  -- 更新畫面    
--                        fsm       <= 10;                   
--                        fsm_back2 <= 77;
--
--               when 77 =>                                  -- delay 1s  
--                        delay_1 :=0;  
--                        fsm       <= 59;                          
--                        fsm_back2 <= 78;
--
--               when 78 =>                                  -- 7
--                        address_start := "001100100000000";
--                        address_end   := "011001000000000";
--                        disp_color    := "110000";         -- R"00"G"00"B"00"                   
--                        fsm       <= 20;                   
--                        fsm_back  <= 79;
--
--               when 79 =>                                  -- 更新畫面    
--                        fsm       <= 10;                   
--                        fsm_back2 <= 80;
--
--               when 80 =>                                  -- delay 1s  
--                        delay_1 :=0;  
--                        fsm       <= 59;                          
--                        fsm_back2 <= 81;
--
--               when 81 =>                                  -- 8
--                        address_start := "011001000000000";
--                        address_end   := "101000000000000";
--                        disp_color    := "000100";         -- R"00"G"00"B"00"                   
--                        fsm       <= 20;                   
--                        fsm_back  <= 82;
--
--               when 82 =>                                  -- 更新畫面    
--                        fsm       <= 10;                   
--                        fsm_back2 <= 83;
--
--               when 83 =>                                  -- delay 1s  
--                        delay_1 :=0;  
--                        fsm       <= 59;                          
--                        fsm_back2 <= 84;
--
--               when 84 =>                                  -- 9
--                        address_start := "011001000000000";
--                        address_end   := "101000000000000";
--                        disp_color    := "001000";         -- R"00"G"00"B"00"                   
--                        fsm       <= 20;                   
--                        fsm_back  <= 85;
--
--               when 85 =>                                  -- 更新畫面    
--                        fsm       <= 10;                   
--                        fsm_back2 <= 86;
--
--               when 86 =>                                  -- delay 1s  
--                        delay_1 :=0;  
--                        fsm       <= 59;                          
--                        fsm_back2 <= 87;
--
--               when 87 =>                                  -- 10
--                        address_start := "011001000000000";
--                        address_end   := "101000000000000";
--                        disp_color    := "001100";         -- R"00"G"00"B"00"                   
--                        fsm       <= 20;                   
--                        fsm_back  <= 88;
--
--               when 88 =>                                  -- 更新畫面    
--                        fsm       <= 10;                   
--                        fsm_back2 <= 89;
--
--               when 89 =>                                  -- delay 1s  
--                        delay_1 :=0;  
--                        fsm       <= 59;                          
--                        fsm_back2 <= 90;
--
--               when 90 =>                                  -- delay 1s  
--                        delay_1 :=0;  
--                        fsm       <= 59;                          
--                        fsm_back2 <= 91;
--                        
--               when 91 =>                                  -- LOOP,全亮
--                        address_start := "000000000000000";
--                        address_end   := "101000000000000";
--                        disp_color    := "111111";         -- R - f800   G - 07e0  B - 001f                    
--                        fsm       <= 20;                   
--                        fsm_back  <= 63;                              

   ----------------------------------------------------------------------------  MODE = "01" ,白色全亮
--               when 100 =>                                   -- 1 修改圖型    
--                        address_start := "000000000000000";
--                        address_end   := "101000000000000";
--                        disp_color    := "111100";          -- R - f800   G - 07e0  B - 001f                    
--                        fsm       <= 20;                   
--                        fsm_back  <= 101;                             
--
--               when 101 =>                                   --更新畫面    
--                        fsm       <= 10;                   
--                        fsm_back2 <= 102;   
--
--               when 102 =>                                   -- idle

   ----------------------------------------------------------------------------  MODE = "10" ,顯示文字 圖形, 光強度數值
--               when 110 =>                                   -- 清除畫面    
--                        address_start := "000000000000000";
--                        address_end   := "101000000000000";
--                        disp_color    := "111111";           -- 全亮
--                        fsm       <= 20;                   
--                        fsm_back  <= 111;                             
--
--   ----------------------------------------------------------------------------開始貼圖 
--               when 111 =>                                   -- 1.初始化變數   
--                        pos_x       := 0;
--                        pos_y       := 0;
--                        varl        := 0;                    -- 顯示文字的選擇
--                        cnt_number  := 0;                    -- 目前顯示第幾個文字                        
--                        cnt_number_max := 9;                 -- 要顯示的文字數量   
--                        cnt1        := 0;                    -- 
--                        bit_index   := 15;                   -- 
--                        fsm         <= 113;   
--                                               
--               when 112 =>                                   -- 2.設定顯示文字 & 貼圖位置                    
--               	      if (cnt_number = 0) then             --   LOOP 112-119 
--                           varl := lx1;    
--                           if TSL2561_int > 20 then
--                              disp_color  := "000000";          -- 文字的顏色,黑                                                                                                       
--                              motor_dir <= '0';                  -- 馬達反轉
--                           else
--                              disp_color  := "001100";          -- 文字的顏色,綠   
--                              motor_dir <= '1';                  -- 馬達正轉
--                           end if;                              
--                           pos_x_start  := 20;
--                           pos_y_start  := 20;                
--                        elsif (cnt_number = 1)  then                            
--                           varl := lx2;    
--                           pos_x_start  := 36;
--                           pos_y_start  := 20;                                          
--                        elsif (cnt_number = 2)  then                            
--                           varl := lx3;
--                           pos_x_start  := 52;
--                           pos_y_start  := 20;                                          
--                        elsif (cnt_number = 3)  then                                                      
--                           varl := lx4;
--                           pos_x_start  := 68;                           
--                           pos_y_start  := 20; 
--                        elsif (cnt_number = 4)  then                                                      
--                           varl := lx5;
--                           pos_x_start  := 84;                           
--                           pos_y_start  := 20;                            
--                        elsif (cnt_number = 5)  then                                                      
--                           varl := 11;                       -- 'R'
--                           disp_color  := "000000";          -- 文字的顏色,黑
--                           pos_x_start  := 20;                           
--                           pos_y_start  := 60; 
--                        elsif (cnt_number = 6)  then                                                      
--                           varl := 12;                       -- 'T'
--                           disp_color  := "000000";          -- 文字的顏色,黑
--                           pos_x_start  := 36;                           
--                           pos_y_start  := 60;   
--                        elsif (cnt_number = 7)  then                                                      
--                           varl := 13;                       -- ':'
--                           disp_color  := "000000";          -- 文字的顏色,黑
--                           pos_x_start  := 52;                           
--                           pos_y_start  := 60;  
--                        elsif (cnt_number = 8)  then   
--                           if TSL2561_int > 20 then                                                   
--                              varl := 14;                       -- '正逆轉'
--                              disp_color  := "000000";          -- 文字的顏色,黑
--                           else
--                              varl := 15;                       -- '正逆轉'
--                              disp_color  := "110000";          -- 文字的顏色,紅                              
--                           end if;      
--                           pos_x_start  := 80;                           
--                           pos_y_start  := 60;                                                                                                                                                                                         
--                        end if;
--                        fsm       <= 113;                   
--                        
--               when 113 =>                                     -- 2.設定LCD位址,範圍0 - (128*160-1)  ,111-115完成8點(1個BYTE)的資料寫入
--                        pos_now := pos_x_start + ((pos_y_start + pos_y) * 128) + pos_x;    
--                        pos_x   := pos_x + 1;
--                         
--                        fsm       <= 114;                   
--
--               when 114 =>                                     -- set address 
--                        a2   <= conv_std_logic_vector(pos_now,15);                                                                    
--                        fsm  <= 115;
--                        
--               when 115 =>                                     -- set data
--                        if(num_table(varl, cnt1)(bit_index) = '1') then                                                      
--                           di2  <= disp_color;                 --                              
--                        else
--                           di2  <= "111111";                                             
--                        end if;    
--                           
--                        fsm  <= 116; 
--                        
--               when 116 =>                                     -- write
--                        we2  <= '1';
--                        fsm  <= 117; 
--
--               when 117 =>                                     -- write
--                        we2  <= '0';
--                        
--                        if pos_x >= 16 then                    --字體寬度20
--                           pos_x := 0; 
--                           pos_y := pos_y + 1;                 --字體高度40(40/8byte = 5)
--                        end if;
--                                                                           
--                        if(bit_index = 0) then
--                           bit_index := 15;
--                           fsm  <= 118; 
--                        else   
--                           bit_index   := bit_index - 1;                                             
--                           fsm  <= 113;                         
--                        end if;
--                                                
--               when 118 =>                                                               
--                           if cnt1 >= 15 then                  --每個數字15個word(16bits)
--                              cnt1 := 0;
--                              fsm  <= 119; 
--                           else
--                              cnt1 := cnt1 + 1;                     
--                              fsm  <= 112; 
--                           end if;
--                        
--               when 119 =>                                    
--                        if (cnt_number < (cnt_number_max-1)) then  -- 顯示數量
--                           cnt_number := cnt_number + 1;           -- 指到下個數字                                                                                 
--                           pos_x       := 0;
--                           pos_y       := 0;
--                           
--                           fsm       <= 113;      
--                        else
--                           cnt_number := 0;
--                           fsm       <= 120;                                
--                        end if;   
--               
--               when 120 =>                                   --更新畫面    
--                        fsm       <= 10;                   
--                        fsm_back2 <= 121;                  
--
--               when 121 =>                                  -- delay 1s , 1秒更新1次資料  
--                        delay_1 :=0; 
--                        fsm       <= 59;                           
--                        fsm_back2 <= 110;
--               
               when others =>                          
                             
            END CASE;    
         
            
  

                  
                                        
	else delay_1 :=delay_1 -1;                             
    end if;
             end if; 
                      end if;  	   
	end process;
--=================================================================
process(nReset, clk_1KHz)           -- MOTOR-PWM
 	   variable scan_number    :integer range 0 to 9; 	 
   begin	
      if(nReset='0')then 	
         motor_out1 <= '0';
         motor_out2 <= '0';
         motor_pwm1 <= '0';
         scan_number := 0;
         
      elsif(clk_1KHz 'event and clk_1KHz ='1')then
         
         if(mode_motor = 1) then                 
            motor_out1 <= '1';
            motor_out2 <= '0';
            
            if(scan_number >= 9) then 
               scan_number := 0;
            else      
               scan_number := scan_number + 1;                        
            end if;   
               
            if(motor_speed > scan_number) then 
               motor_pwm1 <= '1';
            else      
               motor_pwm1 <= '0';
            end if; 

         elsif(mode_motor = 2) then                 --全速
            motor_pwm1 <= '1';                   
            
            if(motor_dir = '0') then
               motor_out1 <= '1';                   --正轉
               motor_out2 <= '0';            
            else           
               motor_out1 <= '0';                   --反轉
               motor_out2 <= '1';                           
            end if;   
                                                                
         else
            motor_out1 <= '0';
            motor_out2 <= '0';
            motor_pwm1 <= '0';
            scan_number := 0;            
               
         end if;                         
                                    
      end if;   

   end process;


   ------------------------------------------------------------------------零件庫 
   u0:i2c_master        --SD178驅動 所使用IIC
   generic map 
   (
	  input_clk => 50_000_000,
	  bus_clk   => 10_000               --10_000
   )
   port map 
   (
	 clk       => ck,
	 reset_n   => sd178_nrst,
    
    ena       => sd178_ena, 
    addr      => "0100000",--sd178_addr
    
    rw        => sd178_rw, 
    data_wr   => sd178_data_wr,
    busy      => sd178_busy,
    data_rd   => sd178_data_rd, 
    ack_error => open,
    sda       => SD178_sda,
    scl       => SD178_scl
   );            

   u1:TSL2561
   port map(
         clk_50M => ck,
         nrst    => nReset,    
         
         sda       => TSL2561_sda,
         scl       => TSL2561_scl,
         
         TSL2561_data => TSL2561_data

           );

   u2:DHT11
   port map(
         clk_50M => ck,
         nrst    => nReset,    
         dat_bus => SHT11_PIN,
         HU      => HU_BUFF,
         TE      => TE_BUFF,                 
         error   => DHT11_error 

           );
 
   u5:up_mdu2           --除頻電路 
   port map(      
                ck       => ck,       
	             fout      => clk_100hz
      
            );

   u6:up_mdu3           --除頻電路
   port map(      
                ck       => ck,       
	             fout      => clk_1KHz
      
            );

   u7:up_mdu4           --除頻電路 
   port map(      
                ck       => ck,       
	             fout      => clk_1MHz      
            );

   u8:up_mdu5           --除頻電路 
   port map(      
                ck       => ck,       
	             fout      => clk_25MHz      
            );

   u9:cmd_rom           --初始化命令資料
   port map 
   (
	 address   => address,
    data_out  => data_out,
    DC_data   => DC_data 
   );

--   u10:raminfr          --LCD 顯示資料暫存RAM
--   generic map 
--	 (
--		  bits        => 6,
--		  addr_bits   => 15              
--	 )            
--   port map(      
--               clk     => ck,       
--	            we      => we2,
--               a       => a2,
--               di      => di2,
--               do      => do2   
--            );
--          
                 
end beh;

