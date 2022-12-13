--七段顯示器 ,掃描線切換與資料切換

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;

ENTITY sync_segscan IS
PORT(
     clk:in std_logic;
     ch_0:in std_logic_vector(3 downto 0);                  --第0位元顯示資料
     ch_1:in std_logic_vector(3 downto 0);                  --第1位元顯示資料
     ch_2:in std_logic_vector(3 downto 0);                  --第2位元顯示資料
     ch_3:in std_logic_vector(3 downto 0);                  --第3位元顯示資料
--     dot :in std_logic;                   			         --第0位元DOT      
     dot :in std_logic_vector(0 to 3);  			         --DOT      
     sync_segout:out std_logic_vector(7 downto 0);          --七段顯示器資料線    
     sync_segsel:out std_logic_vector(0 to 3)               --七段顯示器掃描線
    );
END sync_segscan;

ARCHITECTURE beh OF sync_segscan IS

  type state is (s0,s1,s2,s3);
  signal scanstate:state;    
  signal sel:std_logic_vector(0 to 3);    
  signal ch_out:std_logic_vector(3 downto 0);    
  signal to_seg:std_logic_vector(6 downto 0);    

begin
 
 sync_out:process
 begin
    wait until clk='1';                            --此範例將輸入500HZ clock ,等於2ms切換一次掃描線
    case scanstate is 
       when s0 =>scanstate<=s1; sync_segout(7)<= dot(0);   --DOT 
       when s1 =>scanstate<=s2; sync_segout(7)<= dot(1);   --DOT
       when s2 =>scanstate<=s3; sync_segout(7)<= dot(2);   --DOT
       when s3 =>scanstate<=s0; sync_segout(7)<= dot(3);   --DOT
    end case;
    sync_segsel<=sel;                              --掃描線輸出
    sync_segout(6 downto 0)<= to_seg;               --資料線輸出
    	    	
 end process sync_out;

 mux_decode:process(scanstate) 
 begin
  case scanstate is                                --狀態與掃描線對映
--     when s0 =>ch_out<=ch_0;sel<="1000";           --共陽
--     when s1 =>ch_out<=ch_1;sel<="0100";
--     when s2 =>ch_out<=ch_2;sel<="0010";
--     when s3 =>ch_out<=ch_3;sel<="0001";
--     when others  =>        sel<="0000";    		
     when s0 =>ch_out<=ch_0;sel<="0111";           --共陰
     when s1 =>ch_out<=ch_1;sel<="1011";
     when s2 =>ch_out<=ch_2;sel<="1101";
     when s3 =>ch_out<=ch_3;sel<="1110";
     when others  =>        sel<="1111";    		

  end case;
 end process mux_decode;

 bcd_to_7seg:block
 begin
 WITH ch_out SELECT                                --數字與七段顯示器資料轉換 

 to_seg <=    
          "0111111" when "0000" ,    -- 0--共陰
          "0000110" when "0001" ,    -- 1
          "1011011" when "0010" ,    -- 2
          "1001111" when "0011" ,    -- 3          
          "1100110" when "0100" ,    -- 4 
          "1101101" when "0101" ,    -- 5
          "1111100" when "0110" ,    -- 6
          "0000111" when "0111" ,    -- 7
          "1111111" when "1000" ,    -- 8
          "1101111" when "1001" ,    -- 9
          "0000000" when "1010" ,    -- " "   
          "1100011" when "1011" ,    -- "度"   
          "0111001" when "1100" ,    -- "C"   
          "1101101" when "1101" ,    -- "S"   
          "1110011" when "1110" ,    -- "P"               

          "-------" when others; 
 end block bcd_to_7seg;


end beh;

