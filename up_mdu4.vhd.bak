--除頻
--此範例輸入50MHz clock ,將輸出 1MHz clock

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
entity up_mdu4 is
port(    
     fin:in std_logic;    
     fout:buffer std_logic   
    );
end up_mdu4;
architecture beh of up_mdu4 is
begin
  process(fin)    
   variable cnt:integer range 0 to 25;
  begin   
   if fin='1' and fin'event then
     if cnt>= (25-1) then        
        fout<=not fout;
        cnt:= 0;
      else          
        cnt:=cnt+1;
      end if;   
    end if;  
  end process;   
end beh;

