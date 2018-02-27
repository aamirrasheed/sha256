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
	enum logic [31:0] {IDLE=0, INIT=1, ROUND_INIT=2, 
							READ_1=3, READ_2=4, READ_3=5, READ_4=6, 
							PAD=7, INIT_W=8, CHECK_IF_DONE=9, 
							WRITE_1 = 10, WRITE_2 = 11, WRITE_3 = 12,
							READ_3_1 = 13, READ_3_2 = 14} state;
		
	/* FUNCTIONS */ 
	
	// calculate total number of blocks used
	function logic [15:0] num_blocks(input logic [31:0] size = 0);
		if((size << 3) % 512 < 447) begin
			num_blocks = (size << 3)/512 + 1;
		end else begin
			num_blocks = (size << 3)/512 + 2;
		end
	endfunction
	
	// sha256 round
	function logic [255:0] sha256_op(input logic [31:0] a, b, c, d, e, f, g, h, w,
                                 input logic [7:0] t);
		logic [31:0] S1, S0, ch, maj, t1, t2; // internal signals
	begin
		 S1 = rightrotate(e, 6) ^ rightrotate(e, 11) ^ rightrotate(e, 25);
		 ch = (e & f) ^ ((~e) & g);
		 t1 = h + S1 + ch + sha256_k[t] + w;
		 S0 = rightrotate(a, 2) ^ rightrotate(a, 13) ^ rightrotate(a, 22);
		 maj = (a & b) ^ (a & c) ^ (b & c);
		 t2 = S0 + maj;

		 sha256_op = {t1 + t2, a, b, c, d + t1, e, f, g};
	end
	endfunction
	
	// right rotation
	function logic [31:0] rightrotate(input logic [31:0] x,
												 input logic [7:0] r);
	begin
		 rightrotate = (x >> r) | (x << (32-r));
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
	logic [31:0] pad_length, s0, s1;
	
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
	
	// condition to trigger if last block is zero filled with length
	logic last_block_empty;
	
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
					
					// don't know if last block empty or not
					last_block_empty <= 0;
					
					state <= ROUND_INIT;	
				end
				
				/* Happens every round */
				ROUND_INIT: begin
					
					$display("Total blocks: %d\n", total_blocks);

					// set block row counter to zero
					row <= 0;
					
					state <= READ_1;
				end
				
				/* START READING 512 BIT BLOCK */
				READ_1: begin
					//$display("READ_1\n");
					if(last_block_empty) begin
						
						// pad with zeros until last two rows are left
						for (m = 0; m < 14; m = m + 1) begin
							block[m] = 32'h00000000;
						end
						
						// fill last two rows with length
						block[14] = size >> 29; // append length of message in bits (before pre-processing)
						block[15] = size * 8;
						state <= INIT_W;
					end
					mem_we <= 0;
					mem_addr <= message_addr + mem_index;
					state <= READ_2;
				end

				// idle state to let memory propagate
				READ_2: begin
					//$display("READ_2\n");
					
					state <= READ_3;
				end
				
				READ_3: begin
					//$display("READ_3\n");
					
					// last row of message, do transition padding
					if(size/4 == mem_index) begin
						case (size % 4) // pad bit 1
							0: block[size/4 % 16] <= 32'h80000000;
							1: block[size/4 % 16] <= mem_read_data & 32'h FF000000 | 32'h 00800000;
							2: block[size/4 % 16] <= mem_read_data & 32'h FFFF0000 | 32'h 00008000;
							3: block[size/4 % 16] <= mem_read_data & 32'h FFFFFF00 | 32'h 00000080;
						endcase
						
						// check if there's enough room to put the length at end of block
						if(row < 14) begin
							
							// pad with zeros until last two rows are left
							for (m = 0; m < 14; m = m + 1) begin
								if(m >= ((size/4) % 16) + 1) 
									block[m] <= 32'h00000000;
							end
							
							// fill last two rows with length
							block[14] <= size >> 29; // append length of message in bits (before pre-processing)
							block[15] <= size * 8;
							state <= INIT_W;
						end
						
						// Not enough room to put length at end of block
						else begin
							// fill rest of block with zeros
							for (m = 0; m < 16; m = m + 1) begin
								if(m >= ((size/4) % 16) + 1) 
									block[m] <= 32'h00000000;
							end
							
							// trigger condition to fill next block with zeros and length
							last_block_empty = 1;
							state <= INIT_W;
						end
					end
					else begin
						block[row] <= mem_read_data;
						mem_index <= mem_index + 1;
						row <= row + 1;
						state <= READ_4;
					end
				end
				
				// second half padding - no empty last block
				READ_3_1: begin
				
				end
				
				READ_3_2: begin
					
				end
				
				READ_4: begin
					//$display("READ_4\n");
		
					// if last row in block has been read
					if(row % 16 == 0) begin
						state <= INIT_W;
					end
					
					// more rows to read into block	
					else begin
						state <= READ_1;
					end
				end
				
				/* END READ 512 BIT BLOCK */
				
				INIT_W:begin
					
					for(int i = 0; i < 16; i++) begin
						$display("Address: %d", i);
						$display(" Value: %h \n", block[i]);
					end
					
					for (int t = 0; t < 64; t = t + 1) begin
						if (t < 16) begin
							w[t] = block[t];
					
						end else begin
							s0 = rightrotate(w[t-15], 7) ^ rightrotate(w[t-15], 18) ^ (w[t-15] >> 3);
							s1 = rightrotate(w[t-2], 17) ^ rightrotate(w[t-2], 19) ^ (w[t-2] >> 10);
							w[t] = w[t-16] + s0 + w[t-7] + s1;
						end
					end
					
					// INITIAL HASH AT ROUND K
					a = h0;
					b = h1;
					c = h2;
					d = h3;
					e = h4;
					f = h5;
					g = h6;
					h = h7;

					// HASH ROUNDS
					for (int t = 0; t < 64; t = t + 1) begin
						{a, b, c, d, e, f, g, h} = sha256_op(a, b, c, d, e, f, g, h, w[t], t);
					end

					// FINAL HASH
					h0 = h0 + a;
					h1 = h1 + b;
					h2 = h2 + c;
					h3 = h3 + d;
					h4 = h4 + e;
					h5 = h5 + f;
					h6 = h6 + g;
					h7 = h7 + h;
					
					state <= CHECK_IF_DONE;
				
				end

				CHECK_IF_DONE: begin
					if(block_index == total_blocks) begin
						// write message digest to output memory addresses
						row <= 0;
						state <= WRITE_1;
					end else begin
						block_index <= block_index + 1;
						state <= ROUND_INIT;
					end
				end	
				
				WRITE_1: begin
					mem_we <= 1;
					mem_addr <= output_addr + row;
					case(row)
						0: mem_write_data <= h0;
						1: mem_write_data <= h1;
						2: mem_write_data <= h2;
						3: mem_write_data <= h3;
						4: mem_write_data <= h4;
						5: mem_write_data <= h5;
						6: mem_write_data <= h6;
						7: mem_write_data <= h7;
					endcase
					state <= WRITE_2;
				end
				
				WRITE_2: begin
					state <= WRITE_3;
				end
				
				WRITE_3: begin
					if(row == 7) begin
						done <= 1;
						state <= IDLE;
					end
					else begin
						row <= row + 1;
						state <= WRITE_1;
					end
				end
			endcase
		end	
	end
endmodule