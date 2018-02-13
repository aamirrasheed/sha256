module sha256(input logic clk, reset_n, start,
              input logic [31:0] message_addr, size, output_addr,
             output logic done, mem_clk, mem_we,
             output logic [15:0] mem_addr,
             output logic [31:0] mem_write_data,
              input logic [31:0] mem_read_data);
				  
	function logic [15:0] num_blocks(input logic [31:0] size);
		if((size << 3) % 512 < 447) begin
			num_blocks = (size << 3)/512 + 1;
		end else begin
			num_blocks = (size << 3)/512 + 2;
		end
	endfunction
	
	enum logic [2:0] {IDLE=3'b000 STEP1=3'b001, STEP2=3'b010, STEP3=3'b011, STEP4=3'b100} state;
	
	assign mem_clk = clk;
	
	logic [31:0] message [15:0];
	
	always_ff @(posedge clk, negedge reset_n)
	begin
		if(reset_n) begin
			done <= 0;
			state <= IDLE;
		end else begin
			case(state)
				
				IDLE: begin
					if(start) begin
						state <= STEP1;
					end
				end
				
				STEP1: begin
					// instantiate memory reading module and read from memory???
				end
				
			endcase
		end
		
	end
endmodule