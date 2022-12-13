--���W
--���d�ҿ�J50MHz clock ,�N��X 100Hz clock

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
entity up_mdu2 is
port(    
     ck:in std_logic;    
     fout:buffer std_logic   
    );
end up_mdu2;

architecture beh of up_mdu2 is
begin
  process(ck)    
   variable cnt:integer range 0 to 2000000;
  begin   
   if ck='1' and ck'event then
--     if cnt>= (500000-1) then        
--     if cnt>= (2000000-1) then              
     if cnt>= (1000000-1) then                    
        fout<=not fout;
        cnt:= 0;
      else          
        cnt:=cnt+1;
      end if;   
    end if;  
  end process;   
end beh;

