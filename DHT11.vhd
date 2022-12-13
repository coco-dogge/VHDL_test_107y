

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity DHT11 is 
port(
	   clk_50M:in std_logic;
     nrst:in std_logic;
     dat_bus: inout std_logic;
     HU, TE:out std_logic_vector(7 downto 0);        --访俱计, 放俱计
     error: out std_logic
     
     );
end DHT11;

architecture beh of DHT11 is 
	
component DHT11_BASIC is
port(
	   clk:in std_logic;
     rst:in std_logic;
     key:in std_logic;
     dat_bus: inout std_logic;
     HU, TE:out std_logic_vector(7 downto 0);        --访俱计, 放俱计
     error: out std_logic
     
     );
end component DHT11_BASIC;	
	
	
SIGNAL clk_1M, clk_2 : STD_LOGIC;	
	
begin 


   process(clk_50M)                          -- div 100
   variable cnt:integer range 0 to 50;    
   begin   
      if clk_50M='1' and clk_50M'event then      
         if cnt>= 24 then              
            clk_1M<= not clk_1M;                
            cnt:= 0;
         else          
            cnt:=cnt+1;
         end if;
      end if;  
   end process;

   process(clk_1M)    
   variable cnt:integer range 0 to 1000000;        --1MHz >> 1Hz        
   begin   
    if clk_1M='1' and clk_1M'event then          
      if cnt>= 499999 then              
         clk_2<= not clk_2;                
         cnt:= 0;
       else          
         cnt:=cnt+1;
       end if;   
    end if;  
   end process;


   u0:DHT11_BASIC
	 port map 
	 (
		  clk       => clk_1M,
		  rst       => nrst,		       
      key       => clk_2, 
      dat_bus   => dat_bus,    
      HU   => HU,      
      TE   => TE,  
                   	
      error     => error
	 );

end beh;
