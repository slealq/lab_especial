`default_nettype wire

module data_container #(
                        parameter INDEX_BITS = 6,
                        parameter OFFSET_BITS = 1,
                        parameter WAYS_BITS = 1,
                        parameter DATA_BITS = 25,
                        parameter OFFSETS = 2, // 2^ OFFSET BITS
                        parameter INDEXES  = 64, // 2^ INDEX BITS
                        parameter WAYS = 2 // 2^ WAYS_BITS
                        ) (
                           input                      clk,
                           input                      resetn,
                           input [INDEX_BITS-1:0]     index,
                           input [OFFSET_BITS-1:0]    offset,
                           input [WAYS_BITS-1:0]      way,
                           input                      write_or_read,
                           output reg [DATA_BITS-1:0] data_output,
                           input [DATA_BITS-1:0]      data_input
                           );

   // read or write selectors
   localparam WRITE_OPERATION = 'b0;
   localparam READ_OPERATION = 'b1;

   // way, index, offset -> data saved
   reg [DATA_BITS-1:0]                                data[WAYS-1:0][INDEXES-1:0][OFFSETS-1:0];

   always @(posedge clk) begin
      if (resetn) begin
         if (write_or_read == WRITE_OPERATION) begin
            data[way][index][offset] <= data_input;
         end else if (write_or_read == READ_OPERATION) begin
            data_output <= data[way][index][offset];
         end else begin
            data_output <= data_output; // latch output
         end //end else write_or_read
      end else begin
         // set all values to 0
         data_output <= 0;
      end // end else reset

   end // end always

endmodule // data_container

module cache #(
               parameter CACHE_SIZE = 1024,
               parameter BLOCK_SIZE = 2 // amount of blocks
               )(
                 input             clk,
                 input             resetn,
                 input             mem_valid_cpu, // interface with processor
                 input             mem_instr_cpu,
                 output reg        mem_ready_cpu,
                 input [31:0]      mem_addr_cpu,
                 input [31:0]      mem_wdata_cpu,
                 input [3:0]       mem_wstrb_cpu,
                 output reg [31:0] mem_rdata_cpu,
                 output reg        mem_valid_pm, // principal mem
                 output reg        mem_instr_pm,
                 input             mem_ready_pm,
                 output reg [31:0] mem_addr_pm,
                 output reg [31:0] mem_wdata_pm,
                 output reg [3:0]  mem_wstrb_pm,
                 input [31:0]      mem_rdata_pm
                 );

   // local params for containers
   localparam BLOCK_BITS  = 64;
   localparam LRU_COUNTER_BITS = 2;
   localparam INDEX_BITS = 6;
   localparam OFFSET_BITS = 1;
   localparam WAYS_BITS = 1;
   localparam TAG_BITS = 25;
   localparam OFFSETS = 2;  // 2^ OFFSET BITS
   localparam INDEXES  = 64; // 2^ INDEX BITS
   localparam WAYS = 2; // 2^ WAYS_BITS

   // ================ DEFINITION OF TAG CONTAINER ========
   reg [INDEX_BITS-1:0]            tgc_index;
   reg [OFFSET_BITS-1:0]           tgc_offset;
   reg [WAYS_BITS-1:0]             tgc_way;
   reg                             tgc_write_or_read;
   reg [TAG_BITS-1:0]              tgc_dt_input;
   wire [TAG_BITS-1:0]             tgc_dt_output;

   data_container  #(
                     .INDEX_BITS (INDEX_BITS),
                     .OFFSET_BITS (OFFSET_BITS),
                     .WAYS_BITS (WAYS_BITS),
                     .DATA_BITS (TAG_BITS), // TAG BITS data size
                     .OFFSETS (OFFSETS),
                     .INDEXES (INDEXES),
                     .WAYS (WAYS)
                     ) tag_container (
                                      .clk(clk),
                                      .resetn(resetn),
                                      .index(tgc_index),
                                      .offset(tgc_offset),
                                      .way(tgc_way),
                                      .write_or_read(tgc_write_or_read),
                                      .data_output(tgc_dt_output),
                                      .data_input(tgc_dt_input)
                                      );
   // ================ END OF TAG CONTAINER ===============

   // ============= DEFINITION OF $ DATA CONTAINER ========
   reg [INDEX_BITS-1:0]            chc_index;
   reg [OFFSET_BITS-1:0]           chc_offset;
   reg [WAYS_BITS-1:0]             chc_way;
   reg                             chc_write_or_read;
   reg [BLOCK_BITS-1:0]              chc_dt_input;
   wire [BLOCK_BITS-1:0]             chc_dt_output;

   data_container  #(
                     .INDEX_BITS (INDEX_BITS),
                     .OFFSET_BITS (OFFSET_BITS),
                     .WAYS_BITS (WAYS_BITS),
                     .DATA_BITS (BLOCK_BITS), // TWO WORDS OF 32 BITS
                     .OFFSETS (OFFSETS),
                     .INDEXES (INDEXES),
                     .WAYS (WAYS)
                     ) cache_container (
                                        .clk(clk),
                                        .resetn(resetn),
                                        .index(chc_index),
                                        .offset(chc_offset),
                                        .way(chc_way),
                                        .write_or_read(chc_write_or_read),
                                        .data_output(chc_dt_output),
                                        .data_input(chc_dt_input)
                                        );
   // ============= END OF $ DATA CONTAINER ===============

   // =========== DEFINITION OF LRU DATA CONTAINER ========
   reg [INDEX_BITS-1:0]            lru_index;
   reg [OFFSET_BITS-1:0]           lru_offset;
   reg [WAYS_BITS-1:0]             lru_way;
   reg                             lru_write_or_read;
   reg [LRU_COUNTER_BITS-1:0]              lru_dt_input;
   wire [LRU_COUNTER_BITS-1:0]             lru_dt_output;

   data_container  #(
                     .INDEX_BITS (INDEX_BITS),
                     .OFFSET_BITS (OFFSET_BITS),
                     .WAYS_BITS (WAYS_BITS),
                     .DATA_BITS (LRU_COUNTER_BITS),
                     .OFFSETS (OFFSETS),
                     .INDEXES (INDEXES),
                     .WAYS (WAYS)
                     ) lru_container (
                                      .clk(clk),
                                      .resetn(resetn),
                                      .index(lru_index),
                                      .offset(lru_offset),
                                      .way(lru_way),
                                      .write_or_read(lru_write_or_read),
                                      .data_output(lru_dt_output),
                                      .data_input(lru_dt_input)
                                      );
   // =========== END OF LRU DATA CONTAINER ===============


   // =========== WRITE AND READ CTRL LOGIC ===============
   // change manually for the amount of states
   reg [3:0]                               current_state;

   localparam STAND_BY = 1
   localparam GET_PARAMS = 2
   localparam WR_CHECK_WAYS = 3
   localparam WR_NOT_IN_CACHE 4

     localparam

   reg                                     current_way;
   reg                                     operation;
   reg                                     current_way_tag;
   reg                                     current_addr_tag;
   reg                                     current_addr_index;
   reg                                     current_addr_offset;

   always @(posedge clk) begin
      if (resetn) begin
         case (current_state)
           STAND_BY : begin // -------------------------- +
              operation <= 0;
              mem_read_cpu <= 0;
              current_way <= 0;
              current_way_tag <= 0;
              current_addr_tag <= 0;
              current_addr_index <= 0;
              current_addr_offset <= 0;

              if (|mem_wstrb && mem_valid) begin
                 current_state <= WR_CHECK_WAYS;
                 operation
              end else if (!mem_wstrb && mem_valid) begin
                 current_state <= RD_CHECK_WAYS;
              end else begin
                 current_state <= current_state;
              end // IF ELSE LOGIC
           end // STAND_BY STATE


           GET_PARAMS : begin // ------------------------ +
              current_addr_offset <= mem_addr_cpu[OFFSET_BITS-1:0];
              current_addr_index <= mem_addr_cpu[INDEX_BITS-1+OFFSET_BITS:OFFSET_BITS];
              current_addr_tag <= mem_addr_cpu[TAG_BITS-1+OFFSET_BITS+INDEX_BITS:OFFSET_BITS+INDEX_BITS];
           end

           WR_CHECK_WAYS : begin // --------------------- +
              current_way <= 0;

              if (current_way == {WAYS{1'b1}}) begin
                 // then the item you are looking for is not in $
                 current_state <= WR_NOT_IN_CACHE;
              end else if (current_way_tag == )
              end
           end // WR_CHECK_WAYS STATE

           WR_NOT_IN_CACHE : begin // ------------------- +

           end // WR_NOT_IN_CACHE STATE

           default : begin // --------------------------- +
              current_state <= STAND_BY;
           end

      end else begin
         mem_ready_cpu <= 0;
      end
   end // always @ (posedge clk)

   // ========== END OF WRITE AND READ CTRL LOGIC =========


   // tag container check
   always @(posedge clk) begin
      if (resetn) begin
         lru_index <= lru_index + 1;
         lru_offset <= lru_offset + 1;
         lru_way <= lru_way + 1;
         lru_write_or_read <= lru_write_or_read;
         lru_dt_input <= lru_dt_input + 1;
      end else begin
         lru_index <= 0;
         lru_offset <= 0;
         lru_way <= 0;
         lru_write_or_read <= 0;
         lru_dt_input <= 0;
      end
   end // always tag container check

   // sanity check
   always @ (posedge clk) begin
      // signals to cpu
      mem_rdata_cpu <= mem_rdata_pm;
      mem_ready_cpu <= mem_ready_pm;

      // create real valid pm
      mem_valid_pm <= mem_ready_pm ? 0 : mem_ready_cpu ? 0 : mem_valid_cpu;

      mem_instr_pm <= mem_instr_cpu;
      mem_addr_pm <= mem_addr_cpu;
      mem_wdata_pm <= mem_wdata_cpu;
      mem_wstrb_pm <= mem_wstrb_cpu;
   end

endmodule
