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
	
	enum logic [3:0] {IDLE=4'b0000, STEP1_1=4'b0001, STEP1_2=4'b0010, STEP1_3=4'b0011, STEP1_4=4'b0100, STEP2_1=4'b1000} state;
	
	assign mem_clk = clk;
	
	logic [31:0] message [0:15];
	
	logic [15:0] count;
	
	always_ff @(posedge clk, negedge reset_n)
	begin
		if(!reset_n) begin
			done <= 0;
			state <= IDLE;
		end else begin
			case(state)
				
				IDLE: begin
					$display("idle state\n");

					if(start) begin
						state <= STEP1_1;
						count <= 0;
					end
				end
				
				STEP1_1: begin
					$display("step 1_1\n");

					mem_we <= 0;
					mem_addr <= message_addr + count;
					state <= STEP1_2;
				end
				
				STEP1_2: begin
					$display("Step 1_2\n");

					state <= STEP1_3;
				end
				
				STEP1_3: begin
					//$display("Step 1_3\n");

					message[count] <= mem_read_data;
					count <= count + 1;
					state <= STEP1_4;
				end
				
				STEP1_4: begin
					$display("Step1_4\n");

					if(count == (size >> 2)) begin
						state <= STEP2_1;
					end
					else begin
						state <= STEP1_1;
					end
				end
				
				STEP2_1: begin
					for(int i = 0; i < 64; i = i + 1) begin
						$display("Message address: %d", i);
						$display(" Message value %x\n", message[i]);
					end
					state <= IDLE;
				end
				
			endcase
		end	
	end
endmodule