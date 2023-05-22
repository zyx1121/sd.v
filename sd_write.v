module sd_write (
  input                clk            ,
  input                rst_n          ,
  input        [15:0]  miso_data      ,
  input                sd_init_done   ,
  output  reg          sd_cs          ,
  output  reg          sd_mosi        ,
  input                write_ready    ,
  input        [31:0]  write_address  ,
  input        [15:0]  write_data     ,
  output  reg          write_busy     ,
  output  reg          write_request
);

  reg  [2:0]  state           ;
  reg  [3:0]  bit_counter     ;
  reg  [7:0]  data_counter    ;
  reg  [5:0]  cmd_counter     ;
  reg  [15:0] write_data_temp ;

  wire [40:0] cmd             ;
  wire        receive_done    ;
  wire        write_done      ;

  assign      cmd          = {8'h58, write_address, 1'b1} ;
  assign      receive_done = (miso_data == 16'hFF00) ? 1'b1 : 1'b0 ;
  assign      write_done   = (miso_data[8:0] == 9'b0_1111_1111) ? 1'b1 : 1'b0 ;

  localparam  IDLE         = 3'd0 ;
  localparam  SEND_CMD24   = 3'd1 ;
  localparam  SEND_START   = 3'd2 ;
  localparam  SEND_DATA    = 3'd3 ;
  localparam  SEND_CRC     = 3'd4 ;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bit_counter  <= 1'b0 ;
      data_counter <= 1'b0 ;
    end else begin
        bit_counter  <= (state == SEND_START || state == SEND_DATA) ?
                        (bit_counter == 4'd15) ? 1'b0 : bit_counter + 1'b1 :
                        1'b0;
        data_counter <= (state == SEND_DATA) ?
                        (bit_counter == 4'd15) ? data_counter + 1'b1 : data_counter :
                        1'b0;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE ;
    end else begin
      case (state)

        IDLE : begin
          state <= (write_ready) ? SEND_CMD24 : IDLE ;
        end

        SEND_CMD24 : begin
          state <= (receive_done) ? SEND_START : state ;
        end

        SEND_START : begin
          state <= (bit_counter == 4'd15) ? SEND_DATA : state ;
        end

        SEND_DATA : begin
          state <= (bit_counter == 4'd15 && data_counter == 8'd255) ? SEND_CRC : state ;
        end

        SEND_CRC : begin
          state <= (write_done) ? IDLE : SEND_CRC ;
        end

        default : begin
          state <= IDLE ;
        end

      endcase
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sd_cs           <= 1'b1 ;
      sd_mosi         <= 1'b1 ;
      write_data_temp <= 1'b0 ;
      write_busy      <= 1'b0 ;
      write_request   <= 1'b0 ;
      cmd_counter     <= 1'b0 ;
      bit_counter     <= 1'b0 ;
      data_counter    <= 1'b0 ;
    end else begin
      case (state)

        // IDLE
        IDLE : begin
          sd_cs           <= 1'b1 ;
          sd_mosi         <= 1'b1 ;
          write_data_temp <= 1'b0 ;
          write_busy      <= 1'b0 ;
          write_request   <= 1'b0 ;
          cmd_counter     <= 1'b0 ;
          bit_counter     <= 1'b0 ;
          data_counter    <= 1'b0 ;
        end

        // SEND_CMD24
        SEND_CMD24 : begin
          sd_cs           <= 1'b0 ;
          sd_mosi         <= (receive_done) ? 1'b1 : cmd[6'd40 - cmd_counter] ;
          write_data_temp <= write_data ;
          write_busy      <= 1'b1 ;
          cmd_counter     <= (cmd_counter == 6'd40) ? cmd_counter : cmd_counter + 1'b1 ;
        end

        // SEND_START
        SEND_START : begin
          sd_mosi         <= (bit_counter == 4'd15) ? 1'b0 : 1'b1 ;
        end

        // SEND_DATA
        SEND_DATA : begin
          sd_mosi         <= write_data_temp[4'd15 - bit_counter] ;
          write_data_temp <= (bit_counter == 4'd15) ? write_data : write_data_temp ;
          write_request   <= (bit_counter == 4'd0 ) ? 1'b1 : 1'b0 ;
          bit_counter     <= (bit_counter == 4'd15) ? 1'b0 : bit_counter + 1'b1 ;
          data_counter    <= (bit_counter == 4'd15) ? data_counter + 1'b1 : data_counter ;
        end

        // SEND_CRC
        SEND_CRC : begin
          sd_mosi         <= 1'b1 ;
        end

        // default
        default : begin
        end

      endcase
    end
  end

endmodule
