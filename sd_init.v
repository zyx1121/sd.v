/***************************************************************

  Module Name : sd_init.v
  Author      : Loki
  Description : SD card initial module
  Update Log  :
    * 2023/5/11
      - initial version
    * 2023/5/22
      - style update

****************************************************************/

module sd_init (
  input        clk           ,  // 400 kHz clock
  input        rst_n         ,
  input        sd_miso       ,
  output  reg  sd_cs         ,
  output  reg  sd_mosi       ,
  output  reg  sd_init_done
);

  reg        receive_done         ;
  reg        receive_flag         ;
  reg [47:0] receive_data         ;
  reg [5:0]  receive_data_counter ;

  always @(negedge clk or negedge rst_n) begin
    if (!rst_n) begin
      receive_done         <= 1'b0 ;
      receive_flag         <= 1'b0 ;
      receive_data         <= 1'b0 ;
      receive_data_counter <= 1'b0 ;
    end
    else begin
      if (receive_flag == 1'b0 && sd_miso == 1'b0) begin
        receive_done         <= 1'b0 ;
        receive_flag         <= 1'b1 ;
        receive_data         <= {receive_data[46:0], sd_miso} ;
        receive_data_counter <= receive_data_counter + 1'b1 ;
      end
      else if (receive_flag) begin
        receive_data         <= {receive_data[46:0], sd_miso} ;
        receive_data_counter <= (receive_data_counter >= 6'd47) ? 1'b0 : receive_data_counter + 1'b1 ;
        receive_flag         <= (receive_data_counter >= 6'd47) ? 1'b0 : 1'b1 ;
        receive_done         <= (receive_data_counter >= 6'd47) ? 1'b1 : 1'b0 ;
      end
      else begin
        receive_done         <= 1'b0 ;
      end
    end
  end

  reg [2:0] state            ;
  reg [6:0] poweron_counter  ;
  reg [7:0] overtime_counter ;
  reg [5:0] cmd_counter      ;

  localparam CMD0   = { 8'h40, 32'h00000000, 8'h95 } ;
  localparam CMD8   = { 8'h48, 32'h000001AA, 8'h87 } ;
  localparam CMD55  = { 8'h77, 32'h00000000, 8'h65 } ;
  localparam ACMD41 = { 8'h69, 32'h40000000, 8'h77 } ;

  localparam IDLE        = 3'd0 ;
  localparam SEND_CMD0   = 3'd1 ;
  localparam SEND_CMD8   = 3'd2 ;
  localparam SEND_CMD55  = 3'd3 ;
  localparam SEND_ACMD41 = 3'd4 ;
  localparam INIT_DONE   = 3'd5 ;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= IDLE ;
      poweron_counter  <= 7'd0 ;
      overtime_counter <= 7'd0 ;
    end else begin
      case (state)

        // IDLE
        IDLE : begin
          state           <= (poweron_counter >= 7'd74) ? SEND_CMD0 : IDLE ;
          poweron_counter <= (poweron_counter >= 7'd74) ? 7'd0 : poweron_counter + 1'b1 ;
        end

        // SEND_CMD0
        SEND_CMD0 : begin
          state            <= (receive_done) ?
                              ((receive_data[47:40] == 8'h01) ? SEND_CMD8 : IDLE) :
                              ((overtime_counter >= 8'd200 - 1'b1) ? IDLE : state) ;
          overtime_counter <= (receive_done) ?
                              (1'b0) :
                              ((overtime_counter >= 8'd200 - 1'b1) ? 1'b0 : overtime_counter + 1'b1) ;
        end

        // SEND_CMD8
        SEND_CMD8 : begin
          state <= (receive_done) ? ((receive_data[19:16] == 4'b0001) ? SEND_CMD55 : IDLE) : state ;
        end

        // SEND_CMD55
        SEND_CMD55 : begin
          state <= (receive_done) ? ((receive_data[47:40] == 8'h01) ? SEND_ACMD41 : state) : state ;
        end

        // SEND_ACMD41
        SEND_ACMD41 : begin
          state <= (receive_done) ? ((receive_data[47:40] == 8'h00) ? INIT_DONE : SEND_CMD55) : state ;
        end

        // INIT_DONE
        INIT_DONE : begin
          state <= INIT_DONE ;
        end

        // default
        default : begin
          state <= IDLE ;
        end

      endcase
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sd_init_done <= 1'b0 ;
      sd_cs        <= 1'b1 ;
      sd_mosi      <= 1'b1 ;
      cmd_counter  <= 1'b0 ;
    end else begin
      case (state)

        // IDLE
        IDLE : begin
          sd_init_done <= 1'b0 ;
          sd_cs        <= 1'b1 ;
          sd_mosi      <= 1'b1 ;
          cmd_counter  <= 1'b0 ;
        end

        // SEND_CMD0, SEND_CMD8, SEND_CMD55, SEND_ACMD41
        SEND_CMD0, SEND_CMD8, SEND_CMD55, SEND_ACMD41 : begin
          sd_init_done <= 1'b0 ;
          sd_cs        <= (receive_done) ? 1'b1 : 1'b0 ;
          sd_mosi      <= CMD0[6'd47 - cmd_counter] ;
          cmd_counter  <= (receive_done) ? (1'b0) : ((cmd_counter == 6'd47) ? cmd_counter : cmd_counter + 1'b1) ;
        end

        // INIT_DONE
        INIT_DONE : begin
          sd_init_done <= 1'b1 ;
          sd_cs        <= 1'b1 ;
          sd_mosi      <= 1'b1 ;
          cmd_counter  <= 1'b0 ;
        end

        // default
        default : begin
          sd_init_done <= 1'b0 ;
          sd_cs        <= 1'b1 ;
          sd_mosi      <= 1'b1 ;
          cmd_counter  <= 1'b0 ;
        end

      endcase
    end
  end

endmodule