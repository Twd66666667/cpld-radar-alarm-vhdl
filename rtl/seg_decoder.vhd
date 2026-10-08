library ieee;
use ieee.std_logic_1164.all;

entity seg7_decoder is
port (
    value : in  integer range 0 to 11;
    seg   : out std_logic_vector(6 downto 0)
);
end entity seg7_decoder;

architecture rtl of seg7_decoder is

begin

    process(value)
    begin
        case value is
            when 0  => 
				seg <= "1111110";
            when 1  => 
				seg <= "0110000";
            when 2  => 
				seg <= "1101101";
            when 3  => 
				seg <= "1111001";
            when 4  => 
				seg <= "0110011";
            when 5  => 
				seg <= "1011011";
            when 6  => 
				seg <= "1011111";
            when 7  => 
				seg <= "1110000";
            when 8  => 
				seg <= "1111111";
            when 9  => 
				seg <= "1111011";
            when 10 => 
				seg <= "0000001"; -- ¼õºÅ
            when 11 => 
				seg <= "0000000"; -- Ï¨Ãğ
            when others =>
                seg <= "0000000";
        end case;
    end process;

end architecture rtl;