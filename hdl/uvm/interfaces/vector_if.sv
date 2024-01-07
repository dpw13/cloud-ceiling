interface vector_if #(
    parameter WIDTH = 1
) (input clk);
  logic [WIDTH-1:0] data;  
endinterface //vector_if