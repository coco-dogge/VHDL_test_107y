--���W
--���d�ҿ�J50MHz clock ,�N��X 1KHz clock

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
entity up_mdu3 is
port(    
     ck:in std_logic;    
     fout:buffer std_logic   
    );
end up_mdu3;
architecture beh of up_mdu3 is
begin
  process(ck)    
   variable cnt:integer range 0 to 25000;
  begin   
   if ck='1' and ck'event then
     if cnt>= (25000-1) then        
        fout<=not fout;
        cnt:= 0;
      else          
        cnt:=cnt+1;
      end if;   
    end if;  
  end process;   
end beh;

