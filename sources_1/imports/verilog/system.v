`timescale 1 ns / 1 ps

module system (
            input wire CLK,             // board clock: 100 MHz on Arty/Basys3/Nexys
            input wire RST_BTN,         // reset button
            output wire VGA_HS_O,       // horizontal sync output
            output wire VGA_VS_O,       // vertical sync output
            output wire [3:0] VGA_R,    // 4-bit VGA red output
            output wire [3:0] VGA_G,    // 4-bit VGA green output
            output wire [3:0] VGA_B,    // 4-bit VGA blue output
            input wire CPU_RESETN,
            input wire BTNU,
            input wire BTNL,
            input wire BTNR,
            input wire BTND,
            output wire [12:0] out_byte,
            output reg out_byte_en,
            output wire trap,
            output wire [6:0]      seg,
	        output wire [7:0]      an,
	        output wire           dp
               );
           
	// set this to 0 for better timing but less performance/MHz
	parameter FAST_MEMORY = 1;

	// 16384 32bit words = 64kB memory
	parameter MEM_SIZE = 16384;

	wire mem_valid;
	wire mem_instr;
	reg mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [3:0] mem_wstrb;
	reg [31:0] mem_rdata;

	wire mem_la_read;
	wire mem_la_write;
	wire [31:0] mem_la_addr;
	wire [31:0] mem_la_wdata;
	wire [3:0] mem_la_wstrb;

   reg [15:0] first_num;
   reg [15:0] second_num;
   wire [31:0] result;

   picorv32 #(.ENABLE_MUL(1)) picorv32_core
   (
		  .clk         (CLK         ),
		  .resetn      (RST_BTN     ),
		  .trap        (trap        ),
		  .mem_valid   (mem_valid   ),
		  .mem_instr   (mem_instr   ),
		  .mem_ready   (mem_ready   ),
		  .mem_addr    (mem_addr    ),
		  .mem_wdata   (mem_wdata   ),
		  .mem_wstrb   (mem_wstrb   ),
		  .mem_rdata   (mem_rdata   ),
		  .mem_la_read (mem_la_read ),
		  .mem_la_write(mem_la_write),
		  .mem_la_addr (mem_la_addr ),
		  .mem_la_wdata(mem_la_wdata),
		  .mem_la_wstrb(mem_la_wstrb)
	    );

    // top of game
    top mytop (
                .CLK (CLK),             // board clock: 100 MHz on Arty/Basys3/Nexys
                .RST_BTN (RST_BTN),         // reset button
                .VGA_HS_O (VGA_HS_O),       // horizontal sync output
                .VGA_VS_O (VGA_VS_O),       // vertical sync output
                .VGA_R (VGA_R),    // 4-bit VGA red output
                .VGA_G (VGA_G),    // 4-bit VGA green output
                .VGA_B (VGA_B),    // 4-bit VGA blue output
                .CPU_RESETN (CPU_RESETN),
                .BTNU (BTNU),
                .BTNL (BTNL),
                .BTNR (BTNR),
                .BTND (BTND),
                .target (target_reg),
                .target_save (target_save),
                .move_ready(move_ready),
                .new_button_s(new_button),
                .move_s(move)
    );
    
    // wires for move and new button
    wire [2:0] move;
    wire new_button;
    reg move_ready;

    // reg of out
    reg [31:0] out_byte_complete;
    assign out_byte = out_byte_complete[12:0];
    
    // target register for saving the color value
    reg [31:0] target_reg;
    reg target_save;

	seg7decimal sevenSeg (
		                    .x(out_byte_complete),
		                    .clk(CLK),
		                    .seg(seg[6:0]),
		                    .an(an[7:0]),
		                    .dp(dp)
	                      );

	 reg [31:0]  memory [0:MEM_SIZE-1];
`ifdef SYNTHESIS
   initial $readmemh("/home/sleal/UCR/lab_digitales/inicio-ie424/src/firmware/firmware.hex", memory);
`else
	 initial $readmemh("/home/sleal/UCR/lab_digitales/inicio-ie424/src/firmware/firmware.hex", memory);
`endif

   // buffers for read enable and data
	 reg [31:0]  m_read_data;
	 reg         m_read_en;

	 generate if (FAST_MEMORY) begin
      // with fast memory
		  always @(posedge CLK) begin
			   mem_ready <= 1;
			   out_byte_en <= 0;
			   target_save <= 1;

         // this is for a read
         if (mem_la_read && (mem_la_addr >> 2) < MEM_SIZE) begin
            // address is inside cpu memory
			      mem_rdata <= memory[mem_la_addr >> 2];
         end
         else begin
            // address is outside cpu memory
            if (mem_la_read && mem_la_addr == 32'h0fff_fff8) begin
               mem_rdata <= {31'b0, result};
            end 
            //new_move
            if (mem_la_read && mem_la_addr == 32'h1fff_fff0) begin
               mem_rdata <= {31'b0, new_button};
            end 
            //move
            if (mem_la_read && mem_la_addr == 32'h1fff_fff4) begin
               mem_rdata <= {31'b0, move};
            end 
         end

         // write 
			   if (mem_la_write && (mem_la_addr >> 2) < MEM_SIZE) begin
            // address is inside cpu addres
				    if (mem_la_wstrb[0]) memory[mem_la_addr >> 2][ 7: 0] <= mem_la_wdata[ 7: 0];
				    if (mem_la_wstrb[1]) memory[mem_la_addr >> 2][15: 8] <= mem_la_wdata[15: 8];
				    if (mem_la_wstrb[2]) memory[mem_la_addr >> 2][23:16] <= mem_la_wdata[23:16];
				    if (mem_la_wstrb[3]) memory[mem_la_addr >> 2][31:24] <= mem_la_wdata[31:24];
			   end
			   else
           // address outside cpu address
           begin
              if (mem_la_write && mem_la_addr == 32'h1000_0000) begin
			           out_byte_en <= 1;
			           out_byte_complete <= mem_la_wdata;
              end
              
              if (mem_la_write && mem_la_addr == 32'h0fff_fff0) begin
                 first_num <= mem_la_wdata[15:0];
			        end
              
              if (mem_la_write && mem_la_addr == 32'h0fff_fff4) begin
                 second_num <= mem_la_wdata[15:0];
              end
              
              if (mem_la_write && mem_la_addr == 32'h1fff_ff04) begin
                 move_ready <= mem_la_wdata[15:0];
              end
              
              if (mem_la_write && mem_la_addr == 32'h1fff_ff00) begin
                 target_reg <= mem_la_wdata[15:0];
                 target_save <= 1;
              end
           end
         
		  end
	 end else begin
		  always @(posedge CLK) begin
         // without fast memory
			   m_read_en <= 0;
			   mem_ready <= mem_valid && !mem_ready && m_read_en;
         
			   m_read_data <= memory[mem_addr >> 2];
			   mem_rdata <= m_read_data;
         
			   out_byte_en <= 0;
         
			   (* parallel_case *)
			   case (1)
           // memory inside cpu and mem_wstrb has NO BIT IN HIGH
				   mem_valid && !mem_ready && !mem_wstrb && (mem_addr >> 2) < MEM_SIZE: begin
					    m_read_en <= 1;
				   end
           // mem_wstrb at least one bit in high
				   mem_valid && !mem_ready && |mem_wstrb && (mem_addr >> 2) < MEM_SIZE: begin
					    if (mem_wstrb[0]) memory[mem_addr >> 2][ 7: 0] <= mem_wdata[ 7: 0];
					    if (mem_wstrb[1]) memory[mem_addr >> 2][15: 8] <= mem_wdata[15: 8];
					    if (mem_wstrb[2]) memory[mem_addr >> 2][23:16] <= mem_wdata[23:16];
					    if (mem_wstrb[3]) memory[mem_addr >> 2][31:24] <= mem_wdata[31:24];
					    mem_ready <= 1;
				   end
           // mem addrs outside cpu
           mem_valid && !mem_ready && |mem_wstrb && mem_addr == 32'h1000_0000: begin
					    out_byte_en <= 1;
					    out_byte_complete <= mem_wdata;
					    mem_ready <= 1;
				   end
			   endcase
		  end
	 end endgenerate

endmodule
