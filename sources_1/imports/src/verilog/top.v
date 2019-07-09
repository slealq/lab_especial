
module buttons(
    input wire CLK,
    input wire CPU_RESETN,
    input wire [15:0] BTN,
    output reg [2:0] move 
    );
    
    reg [7:0] c_up, c_down, c_left, c_right, c_space;
    reg [15:0] PBTN;
    reg up_once, left_once, right_once, down_once, space_once;
    
    assign counter = c_up[3:0];
    
    always @(posedge CLK) begin 
        if (CPU_RESETN) begin
            PBTN <= BTN;
            
            if (BTN == 16'hF01D && PBTN == 16'hF01D) begin
                c_up <= up_once ? c_up : c_up + 1;
                c_left <= 0;
                c_right <= 0;
                c_down <= 0;
                c_space <= 0;
            end else if (BTN == 16'hF01C && PBTN == 16'hF01C) begin
                c_up <= 0;
                c_left <= left_once ? c_left : c_left + 1;
                c_right <= 0;
                c_down <= 0; 
                c_space <= 0;
            end else if (BTN == 16'hF023 && PBTN == 16'hF023) begin
                c_up <= 0;
                c_left <= 0;
                c_right <= right_once ? c_right : c_right +1;
                c_down <= 0;
                c_space <= 0;
            end else if (BTN == 16'hF01B && PBTN == 16'hF01B) begin
                c_up <= 0;
                c_left <= 0;
                c_right <= 0;
                c_down <= down_once ? c_down : c_down + 1;
                c_space <= 0;
            end else if (BTN == 16'hF029 && PBTN == 16'hF029) begin
                c_up <= 0;
                c_left <= 0;
                c_right <= 0;
                c_down <= 0;
                c_space <= space_once ? c_space :c_space + 1;
            end else begin
                c_up <= 0;
                c_down <= 0;
                c_left <= 0;
                c_right <= 0;
                c_space <= 0;
            end
    
        end else begin
            c_up <= 0;
            c_down <= 0;
            c_left <= 0; 
            c_right <= 0;
            c_space <= 0;
        end
          
    end
    
    always @(posedge CLK)
    begin
        if (CPU_RESETN) begin
              case ({c_up, c_left, c_right, c_down, c_space})
                {8'hff, 32'h00000000}: begin
                                move <= 'b000;
                                up_once <= 1;
                                left_once <= 0;
                                right_once <= 0;
                                down_once <= 0;
                                space_once <= 0;
                               end
                {8'h00, 8'hff, 24'h000000}: begin 
                                      move <= 'b001;
                                      up_once <= 0;
                                      left_once <= 1;
                                      right_once <= 0;
                                      down_once <= 0;
                                      space_once <= 0;
                                    end
                {16'h0000, 8'hff, 16'h0000}: begin 
                                      move <= 'b011;
                                    up_once <= 0;
                                    left_once <= 0;
                                    right_once <= 1;
                                    down_once <= 0;    
                                    space_once <= 0;
                                     end
                {24'h000000, 8'hff, 8'h00}: begin
                                move <= 'b010;
                                up_once <= 0;
                                left_once <= 0;
                                right_once <= 0;
                                down_once <= 1;
                                space_once <= 0;
                            end
                 {32'h00000000, 8'hff}: begin
                                move <= 'b100;
                                up_once <= 0;
                                left_once <= 0;
                                right_once <= 0;
                                down_once <= 0;
                                space_once <= 1;                    
                 end
                default: begin
                          move <= 'b111;
                         end
                endcase
             end
         else begin
            move <= 'b111;
            up_once <=  0;
            left_once <= 0;
            right_once <= 0;
            down_once <= 0;
            space_once <= 0;
          end
      end
endmodule // buttons

module top(
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
    input wire         PS2_CLK,
    input wire         PS2_DATA,
    input wire [31:0] target,
    input wire target_save,
    input wire move_ready,
    output wire new_button_s,
    output wire [2:0] move_s
    );
    
    wire [31:0] keycode;
    
    reg CLK50MHZ=0;    

    always @(posedge(CLK)) begin
        CLK50MHZ<=~CLK50MHZ;
    end

    PS2Receiver keyboard (
                      .clk(CLK50MHZ),
                      .kclk(PS2_CLK),
                      .kdata(PS2_DATA),
                      .keycodeout(keycode[31:0])
                      );

    wire rst = ~RST_BTN;    // reset is active low on Arty & Nexys Video
    // wire rst = RST_BTN;  // reset is active high on Basys3 (BTNC)

    // generate a 25 MHz pixel strobe
    reg [15:0] cnt;
    reg pix_stb;
    always @(posedge CLK)
        {pix_stb, cnt} <= cnt + 16'h4000;  // divide by 4: (2^16)/4 = 0x4000

    wire [9:0] x;  // current pixel x position: 10-bit value: 0-1023
    wire [8:0] y;  // current pixel y position:  9-bit value: 0-511
    
    // reg for different prints
    reg [2:0] tictactoe [2:0][2:0];

    vga640x480 display (
        .i_clk(CLK),
        .i_pix_stb(pix_stb),
        .i_rst(rst),
        .o_hs(VGA_HS_O), 
        .o_vs(VGA_VS_O), 
        .o_x(x), 
        .o_y(y)
    );
    
    reg [2:0] new_x;
    reg [2:0] new_y;
    reg [2:0] current_x;
    reg [2:0] current_y;
    reg [2:0] red[2:0];
    wire [2:0] move; 

    buttons buttons1 (
        .CLK(CLK),
        .CPU_RESETN(CPU_RESETN),
        .BTN(keycode[15:0]),
        .move(move)
    );
    
    assign move_s = move;
    
    reg [1:0] state;
    reg new_button;
    
    assign new_button_s = new_button;
    
    // new button fsm
    always @ (posedge CLK) begin
        if (CPU_RESETN) begin
            case (state) 
                //IDLE
                2'b00: begin
                    if (move == 'b000 || move == 'b001 || move == 'b010  || move == 'b011 || move == 'b100) begin
                        new_button <= 1;
                        state <= 2'b01;
                    end else begin
                         new_button <= 0;
                         state <= 2'b00;
                    end 
                end
                
                //Wait-ready
                2'b01: begin
                    if (move_ready) begin
                        new_button <= 0;
                        state <= 2'b00;
                    end else begin
                        new_button <= new_button;
                        state <= state;
                    end
                end
            endcase 
            
        end else begin
            new_button <= 0;
            state <= 0;
        end
    end

    // update reg value
    always @ (posedge CLK) begin
        if(target_save) begin
            tictactoe[target[7:6]][target[5:4]] <= target[2:0];
        end
        else begin
            tictactoe[target[7:6]][target[5:4]] <= tictactoe[target[7:6]][target[5:4]];
        end
    end

    reg [2:0] counter_row, counter_col;
    
    always @(x) begin
    	if 	    (x <=  195) begin counter_col <= 0; end
    	else if (x > 225 && x <= 405) begin counter_col <= 1; end
    	else if (x > 435) begin counter_col <= 2; end
    	else counter_col <= 7; // 7 means white line
    end

    always @(y) begin
    	if 	    (y <= 145) begin counter_row <= 0; end
        else if (y > 175 && y <= 305) begin counter_row <= 1; end
        else if (y > 335) begin counter_row <= 2; end
        else counter_row <= 7;
    end
    
    wire [3:0] counter_sum;
    
    assign counter_sum = counter_row + counter_col;
    
    reg sq_r, sq_g, sq_b;
    
    always @ (y, x) begin
        if (counter_row == 7 || counter_col == 7) begin
            sq_r <= 1;
            sq_g <= 1;
            sq_b <= 1;
        end
        else begin
        
            case (tictactoe[counter_col][counter_row])
                3'b000: 
                    begin
                    sq_r <= 0;
                    sq_g <= 0;
                    sq_b <= 0;
                    end
                3'b001:
                    begin
                    sq_r <= 1;
                    sq_g <= 0;
                    sq_b <= 0;
                    end
                3'b010:
                    begin
                    sq_r <= 0;
                    sq_g <= 0;
                    sq_b <= 1;
                    end
                3'b011:
                    begin
                    sq_r <= 0;
                    sq_g <= 1;
                    sq_b <= 0;
                    end
                3'b110:
                    begin
                    sq_r <= 1;
                    sq_g <= 1;
                    sq_b <= 0;
                    end
                3'b101:
                    begin
                    sq_r <= 0;
                    sq_g <= 1;
                    sq_b <= 1;
                    end
                3'b111:
                    begin
                    sq_r <= 1;
                    sq_g <= 1;
                    sq_b <= 1;
                    end
                default: 
                    begin
                    sq_r <= 0;
                    sq_g <= 0;
                    sq_b <= 0;
                    end
            endcase
        end
    end
    
    assign VGA_R = {4{sq_r}};  // square a is 100% red
    assign VGA_G = {4{sq_g}};  // square a is also 100% green
    assign VGA_B = {4{sq_b}};  // square a is algo 100% blue
    
endmodule

