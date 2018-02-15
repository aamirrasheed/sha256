module sha256(input logic clk, reset_n, start,
              input logic [31:0] message_addr, size, output_addr,
             output logic done, mem_clk, mem_we,
             output logic [15:0] mem_addr,
             output logic [31:0] mem_write_data,
              input logic [31:0] mem_read_data);
		
	/* CONSTANTS */
	
	// constant k array
	parameter int sha256_k[0:63] = '{
		32'h428a2f98, 32'h71374491, 32'hb5c0fbcf, 32'he9b5dba5, 32'h3956c25b, 32'h59f111f1, 32'h923f82a4, 32'hab1c5ed5,
		32'hd807aa98, 32'h12835b01, 32'h243185be, 32'h550c7dc3, 32'h72be5d74, 32'h80deb1fe, 32'h9bdc06a7, 32'hc19bf174,
		32'he49b69c1, 32'hefbe4786, 32'h0fc19dc6, 32'h240ca1cc, 32'h2de92c6f, 32'h4a7484aa, 32'h5cb0a9dc, 32'h76f988da,
		32'h983e5152, 32'ha831c66d, 32'hb00327c8, 32'hbf597fc7, 32'hc6e00bf3, 32'hd5a79147, 32'h06ca6351, 32'h14292967,
		32'h27b70a85, 32'h2e1b2138, 32'h4d2c6dfc, 32'h53380d13, 32'h650a7354, 32'h766a0abb, 32'h81c2c92e, 32'h92722c85,
		32'ha2bfe8a1, 32'ha81a664b, 32'hc24b8b70, 32'hc76c51a3, 32'hd192e819, 32'hd6990624, 32'hf40e3585, 32'h106aa070,
		32'h19a4c116, 32'h1e376c08, 32'h2748774c, 32'h34b0bcb5, 32'h391c0cb3, 32'h4ed8aa4a, 32'h5b9cca4f, 32'h682e6ff3,
		32'h748f82ee, 32'h78a5636f, 32'h84c87814, 32'h8cc70208, 32'h90befffa, 32'ha4506ceb, 32'hbef9a3f7, 32'hc67178f2
	};
	
	// states
	enum logic [31:0] {IDLE=0, INIT=1, ROUND_INIT=2, READ_1=3, READ_2=4, READ_3=5, READ_4=6, PAD=7, INIT_W=8} state;
		
	/* FUNCTIONS */ 
	function logic [15:0] num_blocks(input logic [31:0] size = 0);
		if((size << 3) % 512 < 447) begin
			num_blocks = (size << 3)/512 + 1;
		end else begin
			num_blocks = (size << 3)/512 + 2;
		end
	endfunction
	
	/* VARIABLES */
	// used for pad loop
	int m;
	
	assign mem_clk = clk;
	
	// computed with num_blocks function in INIT state
	logic [15:0] total_blocks;
	
	// keep track of which block we're on
	logic [15:0] block_index;
	
	// one 512 bit block
	logic [31:0] block [0:15];
	
	// memory tracker
	logic [15:0] mem_index;
	
	// row tracker for 512 bit block
	logic [15:0] row;
	
	// used for padding
	logic [31:0] pad_length;
	
	// message digest
	logic [31:0] h0;
	logic [31:0] h1;
	logic [31:0] h2;
	logic [31:0] h3;
	logic [31:0] h4;
	logic [31:0] h5;
	logic [31:0] h6;
	logic [31:0] h7;
	
	// intermediate message digets
	logic [31:0] a;
	logic [31:0] b;
	logic [31:0] c;
	logic [31:0] d;
	logic [31:0] e;
	logic [31:0] f;
	logic [31:0] g;
	logic [31:0] h;
	
	// intermediate w array
	logic [31:0] w [0:63];
	
	always_ff @(posedge clk, negedge reset_n)
	begin
		if(!reset_n) begin
			done <= 0;
			state <= IDLE;
		end else begin
			case(state)
				
				IDLE: begin
					//$display("idle state\n");

					if(start) begin
						state <= INIT;
					end
				end
				
				/* Happens once */
				INIT: begin
					// determine number of loops
					total_blocks <= num_blocks(size);
					
					// initialize block index counter
					block_index <= 1;
					
					// message digest
					h0 = 32'h6a09e667;
					h1 = 32'hbb67ae85;
					h2 = 32'h3c6ef372;
					h3 = 32'ha54ff53a;
					h4 = 32'h510e527f;
					h5 = 32'h9b05688c;
					h6 = 32'h1f83d9ab;
					h7 = 32'h5be0cd19;
					
					// memory index
					mem_index <= 0;
					state <= ROUND_INIT;
				end
				
				/* Happens every round */
				ROUND_INIT: begin
					// set block row counter to zero
					row <= 0;
					
					// set intermediate message digest values to old message digest value
					a = h0;
					b = h1;
					c = h2;
					d = h3;
					e = h4;
					f = h5;
					g = h6;
					h = h7;
					
					state <= READ_1;
				end
				
				/* START READING 512 BIT BLOCK */
				READ_1: begin
					$display("READ_1\n");

					mem_we <= 0;
					mem_addr <= message_addr + mem_index;
					state <= READ_2;
				end
				
				READ_2: begin
					$display("READ_2\n");
					
					state <= READ_3;
				end
				
				READ_3: begin
					$display("READ_3\n");

					block[row] <= mem_read_data;
					mem_index <= mem_index + 1;
					row <= row + 1;
					state <= READ_4;
				end
				
				READ_4: begin
					$display("READ_4\n");
					
					// if last row in block has been read
					if(row % 32 == 0) begin
					
						// if this is the last block
						if(block_index == num_blocks)begin
							state <= PAD;
						end 
						// else got to SHA 256 round
						else begin
							state <= INIT_W;
						end
						
					// block not filled up
					end else begin
						state <= READ_1;
					end
				end
				
				/* END READ 512 BIT BLOCK */
				
				/* PAD IF NECESSARY */
				PAD: begin
//					// padding algorithm
//					if ((size + 1) % 64 <= 56 && (size + 1) % 64 > 0)
//						pad_length <= (size/64)*64 + 56;
//					else
//						pad_length <= (size/64+1)*64 + 56;
						

					case (size % 4) // pad bit 1
						0: block[size/4 % 16] = 32'h80000000;
						1: block[size/4 % 16] = block[size/4 % 16] & 32'h FF000000 | 32'h 00800000;
						2: block[size/4 % 16] = block[size/4 % 16] & 32'h FFFF0000 | 32'h 00008000;
						3: block[size/4 % 16] = block[size/4 % 16] & 32'h FFFFFF00 | 32'h 00000080;
					endcase

					for (m = 0; m < 13; m = m + 1) begin
						if(m >= ((size/4) % 16) + 1) 
							block[m] = 32'h00000000;
					end

					block[14] = size >> 29; // append length of message in bits (before pre-processing)
					block[15] = size * 8;
					state <= INIT_W;
				end
				
				INIT_W:begin
					for(int i = 0; i < 16; i++) begin
						$display("Address: %d", i);
						$display(" Value: %h \n", block[i]);
					end
					state <= IDLE;
				end
//				
//				COMPUTE_ABCD: begin
//				end
//				
//				COMPUTE_NEW_MD: begin
//				end
//				
//				CHECK_IF_DONE: begin
//				end
				
			endcase
		end	
	end
endmodule