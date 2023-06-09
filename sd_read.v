/***************************************************************

  Module Name : sd_read.v
  Author      : Loki
  Description : SD card read module
  Update Log  :
    * 2023/5/11
      - initial version
    * 2023/5/22
      - refactor sd_write and sd_read module FSM
      - style update

****************************************************************/

module sd_read (
  input                clk           ,
  input                rst_n         ,
  input        [15:0]  miso_data     ,
  output  reg          sd_cs         ,
  output  reg          sd_mosi       ,
  input                read_ready    ,
  input                read_start    ,
  input        [31:0]  read_address  ,
  output  reg          read_busy     ,
  output  reg          read_request  ,
  output  reg  [15:0]  read_data
);

  reg  [2:0]  state        ;
  reg  [5:0]  cmd_counter  ;
  reg  [3:0]  bit_counter  ;
  reg  [8:0]  data_counter ;
  reg  [23:0] wait_counter ;

  wire [40:0] cmd;
  wire        receive_done ; // receive data done flag
  wire        head_done    ; // head byte done flag

  assign      cmd          = {8'h51, read_address, 1'b1} ;
  assign      receive_done = (miso_data == 16'hFF00) ? 1'b1 : 1'b0 ;
  assign      head_done    = (miso_data == 16'hFFFE) ? 1'b1 : 1'b0 ;

  localparam  IDLE         = 3'd0 ;
  localparam  SEND_CMD17   = 3'd1 ;
  localparam  WAIT_READ    = 3'd2 ;
  localparam  READ_DATA    = 3'd3 ;
  localparam  WAIT_DONE    = 3'd4 ;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bit_counter  <= 1'b0 ;
      data_counter <= 1'b0 ;
    end
    else begin
      if (state == READ_DATA || state == WAIT_DONE) begin
        bit_counter  <= (bit_counter == 4'd15) ? 1'b0 : bit_counter + 1'b1 ;
        data_counter <= (bit_counter == 4'd15) ? data_counter + 1'b1 : data_counter ;
      end else begin
        bit_counter  <= 1'b0 ;
        data_counter <= 1'b0 ;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE ;
    end
    else begin
      case (state)

        IDLE : begin
          state <= (read_ready) ? SEND_CMD17 : state ;
        end

        SEND_CMD17 : begin
          state <= (receive_done) ? WAIT_READ : state ;
        end

        WAIT_READ : begin
          state <= (head_done) ? READ_DATA : state ;
        end

        READ_DATA : begin
          state <= (bit_counter == 4'd15 && data_counter == 9'd255) ? WAIT_DONE : READ_DATA ;
        end

        WAIT_DONE : begin
          state <= (bit_counter == 4'd15 && data_counter == 9'd257) ? IDLE : state ;
        end

        default : begin
          state <= IDLE ;
        end

      endcase
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sd_cs        <= 1'b1 ;
      sd_mosi      <= 1'b1 ;
      read_busy    <= 1'b0 ;
      read_data    <= 1'b0 ;
      read_request <= 1'b0 ;
      cmd_counter  <= 1'b1 ;
      bit_counter  <= 1'b0 ;
      data_counter <= 1'b0 ;
      wait_counter <= 1'b0 ;
    end
    else begin
      case (state)

        // IDLE
        IDLE : begin
          sd_cs        <= 1'b1 ;
          sd_mosi      <= 1'b1 ;
          read_busy    <= 1'b0 ;
          read_data    <= 1'b0 ;
          read_request <= 1'b0 ;
          cmd_counter  <= 1'b1 ;
          bit_counter  <= 1'b0 ;
          data_counter <= 1'b0 ;
          wait_counter <= 1'b0 ;
        end

        // SEND_CMD17
        SEND_CMD17 : begin
          sd_cs        <= 1'b0 ;
          sd_mosi      <= (receive_done) ? 1'b1 : cmd[6'd40 - cmd_counter] ;
          read_busy    <= 1'b1 ;
          cmd_counter  <= (cmd_counter == 6'd40) ? cmd_counter : cmd_counter + 1'b1 ;
        end

        // WAIT_READ
        WAIT_READ : begin
        end

        // READ_DATA
        READ_DATA : begin
          read_request <= (bit_counter  == 4'd15) ? 1'b1 : 1'b0 ;
          read_data    <= (bit_counter  == 4'd15) ? miso_data : read_data ;
        end

        // WAIT_DONE
        WAIT_DONE : begin
        end

        // default
        default : begin
          state        <= IDLE ;
        end

      endcase
    end
  end

endmodule