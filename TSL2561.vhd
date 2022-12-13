--TSL2561ÅX°Ê ,50MHz¿é¤J, 1¬íÅª¨ú1¦¸«G«×­È

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity TSL2561 is 
port(
	  clk_50M:in std_logic;
     nrst:in std_logic;

     sda       : INOUT  STD_LOGIC;                   --TSL2561 IIC SDA(161)
     scl       : INOUT  STD_LOGIC;                   --TSL2561 IIC SCL(160)                                                             
     
     TSL2561_data : OUT  std_logic_vector(14 downto 0)

     );
end TSL2561;

architecture beh of TSL2561 is 
	
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

--TSL2561
type State_type1 is (POWER_ON_1,POWER_ON_2,POWER_ON_3,POWER_ON_4,POWER_ON_5,
	                   s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11);
SIGNAL  IICState  : State_type1; 

SIGNAL  ena, rw, busy, ack_error  : std_logic;   
SIGNAL  addr    : STD_LOGIC_VECTOR(6 DOWNTO 0);   
SIGNAL  data_wr, data_rd   : STD_LOGIC_VECTOR(7 DOWNTO 0);   
SIGNAL  data0   : STD_LOGIC_VECTOR(15 DOWNTO 0);
	
begin 

   process(clk_50M,nrst)                --TSL2561ÅX°Ê ,1¬íÅª¨ú1¦¸«G«×­È
        
   variable cnt_delay      :integer range 0 to 50000000;    
   begin                  

      if(clk_50M'EVENT AND clk_50M='1')then 
         
         if(nrst='0')then 
            ena       <= '0';                          
            IICState  <= POWER_ON_1;                        
         else   
              
            CASE IICState IS                
                                                                             
               WHEN POWER_ON_1=>                      
                        cnt_delay:=cnt_delay+1;                                                             
                        if cnt_delay = 50000000 then            -- 1000ms
                           cnt_delay:=0; 
                           IICState <=POWER_ON_2;
                        end if;                         	
               WHEN POWER_ON_2=>                      
                        addr       <= "0111001";               --write address  0x39
                        data_wr    <= "10000000";              --0x80 | 0x00 Control Register (0h)   
                        rw         <= '0';                     --0/write                                                                     
                        IICState   <= POWER_ON_3;
               WHEN POWER_ON_3=>                      
                        ena        <= '1';                                                                    
                        IICState   <= POWER_ON_4;
               WHEN POWER_ON_4=>                      
                        if busy = '1' then                             
                           addr       <= "0111001";            --write address  0x39  
                           data_wr    <= "00000011";           --DATA = 0x03                         
                           rw         <= '0';                  --0/write                                                                                                                                                 
                           IICState   <= POWER_ON_5;
                        end if; 
               WHEN POWER_ON_5=>            
                        if busy = '0' then 
                           ena        <= '0';                                                                                                                            
                           IICState   <= s0;                                 
                        end if;

               when s0=>                                        -- S0-S15 LOOP
                        cnt_delay:=cnt_delay+1;                                                             
                        if cnt_delay = 50000000 then            -- 1000msè®€1æ¬?
                           cnt_delay:=0; 
                           IICState <=s1;
                        end if;                         	                                                	                                                                                                                                                                                    
               WHEN s1=>                      
                        addr       <= "0111001";               --write address  0x39
                        data_wr    <= "10001100";              --command 0x0C | 0x80                           
                        rw         <= '0';                     --0/write                                                                     
                        IICState   <= s2;
               WHEN s2=>                      
                        ena        <= '1';                                                                    
                        IICState   <= s3;
               WHEN s3=>                      
                        if busy = '1' then                             
                           addr       <= "0111001";               --write address  0x39                           
                           rw         <= '1';                     --1/read                                                                                                                                                  
                           IICState   <= s4;
                        end if; 
               WHEN s4=>            
                        if busy = '0' then                           	 
                          IICState   <= s5;                               
                          cnt_delay:=0;                                 
                        	ena        <= '0';                       	                                                      
                        end if;
               WHEN s5=>            
                        cnt_delay:=cnt_delay+1;                                                             
                        if cnt_delay = 10000 then            -- 200us
                           cnt_delay:=0; 
                           IICState <=s6;
                           data0(7 DOWNTO 0) <= data_rd;
                        end if; 
               WHEN s6=>                      
                        addr       <= "0111001";               --write address  0x39
                        data_wr    <= "10001101";              --command 0x0D | 0x80                           
                        rw         <= '0';                     --0/write                                                                     
                        IICState   <= s7;
               WHEN s7=>                      
                        ena        <= '1';                                                                    
                        IICState   <= s8;
               WHEN s8=>                      
                        if busy = '1' then                             
                           addr       <= "0111001";             --write address  0x39                           
                           rw         <= '1';                   --1/read                                                                                                                                                  
                           IICState   <= s9;
                        end if; 
               WHEN s9=>            
                        if busy = '0' then                                                         	 
                          IICState   <= s10;                            	
                        	ena        <= '0';                       	                                                      
                        end if;                                    	
               WHEN s10=>     
                        cnt_delay:=cnt_delay+1;                                                             
                        if cnt_delay = 10000 then            -- 200us
                           cnt_delay:=0; 
                           data0(15 DOWNTO 8) <= data_rd;
                           IICState   <= s11;                                 
                        end if;                	                           
               WHEN s11=>     
            	          TSL2561_data  <= data0(15 DOWNTO 1);   -- ADC channel 0 / 2                         	              	
                         IICState      <= s0;
                                                                                                                    	                        	               	                                                   
              when others =>                                                                         
                        IICState   <= s0;
                          
            END CASE;
                           
         end if;   

      end if; 

   end process;


   u0:i2c_master               --TSL2561ÅX°Ê ©Ò¨Ï¥ÎIIC
   generic map 
	(
		  input_clk => 50_000_000,
		  bus_clk   => 150_000               --150_000
	)
	port map 
	(
	  clk       => clk_50M,
	  reset_n   => nrst,
     
     ena       => ena, 
     addr      => addr,
     rw        => rw, 
     data_wr   => data_wr,
     busy      => busy,
     data_rd   => data_rd, 
     ack_error => ack_error,
     
     sda       => sda,
     scl       => scl
	);

end beh;
