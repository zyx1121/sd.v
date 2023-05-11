module sd(
  // module interface
  input           clk            ,  // 100 MHz clock
  input           rst_n          ,
  output          sd_init_done   ,
  // SD interface
  input           SD_MISO        ,
  output          SD_CLK         ,
  output          SD_CS          ,
  output          SD_MOSI        ,
  // user write interface
  input           write_start    ,
  input   [31:0]  write_address  ,
  input   [15:0]  write_data     ,
  output          write_busy     ,
  output          write_request  ,
  // user read interface
  input           read_start     ,
  input   [31:0]  read_address   ,
  output          read_busy      ,
  output          read_request   ,
  output  [15:0]  read_data
);

  reg    init_sd_clk   ;
  reg    work_sd_clk   ;

  wire   init_sd_cs    ;
  wire   init_sd_mosi  ;
  wire   write_sd_cs   ;
  wire   write_sd_mosi ;
  wire   write_ready   ;
  wire   read_sd_cs    ;
  wire   read_sd_mosi  ;
  wire   read_ready    ;

  assign SD_CLK      = sd_init_done ? init_sd_clk : work_sd_clk ;
  assign SD_CS       = sd_init_done ? (write_busy ? write_sd_cs   : (read_busy ? read_sd_cs   : 1'b1)) : init_sd_cs   ;
  assign SD_MOSI     = sd_init_done ? (write_busy ? write_sd_mosi : (read_busy ? read_sd_mosi : 1'b1)) : init_sd_mosi ;
  assign write_ready = sd_init_done & !read_busy & read_start ;
  assign read_ready  = sd_init_done & !write_busy & write_start;

  // sd init clock divider
  // 100 MHz / 250 = 400 kHz

  reg [6:0] init_sd_clk_counter ;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      init_sd_clk         <= 1'b0 ;
      init_sd_clk_counter <= 1'b0 ;
    end else begin
      init_sd_clk         <= (init_sd_clk_counter >= 8'd125 - 1'b1) ? ~init_sd_clk : init_sd_clk ;
      init_sd_clk_counter <= (init_sd_clk_counter >= 8'd125 - 1'b1) ? 1'b0 : init_sd_clk_counter + 1'b1 ;
    end
  end


  // sd work clock divider
  // 100 MHz / 2 = 50 MHz

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      work_sd_clk <= 1'b0 ;
    end else begin
      work_sd_clk <= ~work_sd_clk ;
    end
  end


  // receive miso data

  reg [15:0] miso_data ;

  always @(negedge work_sd_clk or negedge rst_n) begin
    if (!rst_n) begin
      miso_data <= 16'hFFFF ;
    end else begin
      miso_data <= {miso_data[14:0], SD_MISO} ;
    end
  end


  // sd init module

  sd_init u_sd_init (
    .clk(init_sd_clk),
    .rst_n(rst_n),
    .sd_miso(SD_MISO),
    .sd_cs(init_sd_cs),
    .sd_mosi(init_sd_mosi),
    .sd_init_done(sd_init_done)
  );


  // sd write module

  sd_write u_sd_write (
    .clk(work_sd_clk),
    .rst_n(rst_n),
    .miso_data(miso_data),
    .sd_cs(write_sd_cs),
    .sd_mosi(write_sd_mosi),
    .write_ready(write_ready),
    .write_address(write_address),
    .write_data(write_data),
    .write_busy(write_busy),
    .write_request(write_request)
  );


  // sd read module

  sd_read u_sd_read (
    .clk(work_sd_clk),
    .rst_n(rst_n),
    .miso_data(miso_data),
    .sd_cs(read_sd_cs),
    .sd_mosi(read_sd_mosi),
    .read_ready(read_ready),
    .read_address(read_address),
    .read_busy(read_busy),
    .read_request(read_request),
    .read_data(read_data)
  );

endmodule