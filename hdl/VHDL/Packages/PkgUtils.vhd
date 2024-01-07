library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

--* General utility functions
package PkgUtils is

	--+ Conversion function
	function to_stdLogic(I : boolean) return std_logic;
	function to_boolean(I : std_ulogic) return boolean;
	
end package ; -- PkgUtils

package body PkgUtils is

	function to_stdLogic(I : boolean) return std_logic is
	begin
		if I then
			return '1';
		else
			return '0';
		end if;
	end function;

	function to_boolean(I : std_ulogic) return boolean is
	begin
		return I = '1';
	end function;

end PkgUtils; 
