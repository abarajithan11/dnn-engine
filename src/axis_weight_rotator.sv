/*//////////////////////////////////////////////////////////////////////////////////
Group : ABruTECH
Engineer: Abarajithan G.

Create Date: 30/12/2020
Design Name: AXIS Weight Rotator
Tool Versions: Vivado 2018.2
Description: 
            

Dependencies: 

Revision:
Revision 0.01 - File Created
Additional Comments: 

//////////////////////////////////////////////////////////////////////////////////*/

module axis_weight_rotator (
    aclk    ,
    aresetn ,
    s_axis_tready, 
    s_axis_tvalid, 
    s_axis_tlast , 
    s_axis_tdata ,
    s_axis_tkeep ,
    m_axis_tready,      
    m_axis_tvalid,   
    m_axis_tdata ,
    m_axis_tlast ,
    m_axis_tuser
  );
  parameter CORES             = 2;
  parameter WORD_WIDTH        = 8; 
  parameter KERNEL_H_MAX      = 3;   // odd number
  parameter KERNEL_W_MAX      = 3;   // odd number
  parameter IM_CIN_MAX        = 1024;
  parameter IM_BLOCKS_MAX     = 32;
  parameter IM_COLS_MAX       = 384;
  parameter WEIGHTS_DMA_BITS  = 32;

  parameter BEATS_CONFIG_3X3_1   = 21-1;
  parameter BEATS_CONFIG_1X1_1   = 13-1;

  parameter BRAM_LATENCY =  2;

  localparam BITS_KERNEL_W_MAX = $clog2(KERNEL_W_MAX);
  localparam BITS_KERNEL_H_MAX = $clog2(KERNEL_H_MAX);

  parameter I_KERNEL_W_1         = 0;
  parameter I_KERNEL_H_1         = I_KERNEL_W_1 + BITS_KERNEL_W_MAX + 0;
  parameter I_OTHER              = I_KERNEL_H_1 + BITS_KERNEL_H_MAX;
  parameter I_IS_CONFIG          = I_OTHER + 0;  
  parameter I_CONV_IS_1X1        = I_OTHER + 1;
  parameter I_LRELU_IS_TOP       = I_OTHER + 2;
  parameter I_LRELU_IS_BOTTOM    = I_OTHER + 3;
  parameter I_CONV_IS_COLS_1_K2  = I_OTHER + 4;
  parameter TUSER_WIDTH_CONV     = I_OTHER + 5;

  localparam BITS_CONFIG_COUNT    = $clog2(BEATS_CONFIG_3X3_1);
  localparam M_WIDTH              = WORD_WIDTH*CORES*KERNEL_W_MAX;

  localparam BRAM_W_WIDTH = M_WIDTH;
  localparam BRAM_R_WIDTH = M_WIDTH;
  localparam BRAM_R_DEPTH = KERNEL_H_MAX * IM_CIN_MAX + BEATS_CONFIG_3X3_1;
  localparam BRAM_W_DEPTH = BRAM_R_DEPTH * BRAM_R_WIDTH / BRAM_W_WIDTH;

  localparam BITS_R_ADDR       = $clog2(BRAM_R_DEPTH);
  localparam BITS_W_ADDR       = $clog2(BRAM_W_DEPTH);
  localparam BITS_IM_CIN       = $clog2(IM_CIN_MAX);
  localparam BITS_IM_BLOCKS    = $clog2(IM_BLOCKS_MAX);
  localparam BITS_IM_COLS      = $clog2(IM_COLS_MAX);

  input logic aclk;
  input logic aresetn;

  output logic s_axis_tready;
  input  logic s_axis_tvalid;
  input  logic s_axis_tlast ;
  input  logic [WEIGHTS_DMA_BITS   -1:0] s_axis_tdata;
  input  logic [WEIGHTS_DMA_BITS/8 -1:0] s_axis_tkeep;

  input  logic m_axis_tready;
  output logic m_axis_tvalid;
  output logic m_axis_tlast ;
  output logic [TUSER_WIDTH_CONV-1:0] m_axis_tuser;
  output logic [M_WIDTH         -1:0] m_axis_tdata;

  logic [WORD_WIDTH-1:0] s_data [WEIGHTS_DMA_BITS/WORD_WIDTH-1:0];
  logic [WORD_WIDTH-1:0] m_data [CORES-1:0][KERNEL_W_MAX-1:0];

  assign s_data = {>>{s_axis_tdata}};
  assign {>>{m_axis_tdata}} = m_data;

  typedef logic logic_2_t [2];
  typedef logic [BITS_CONFIG_COUNT-1:0] config_2_t [2];

  logic dw_m_ready, dw_m_valid, dw_m_last, dw_s_valid, dw_s_ready;
  logic [TUSER_WIDTH_CONV-1:0] dw_m_user;
  logic [M_WIDTH         -1:0] dw_m_data;
  
  logic state_dw_next, state_dw, s_handshake, s_last_handshake;

  logic dw_m_handshake, dw_m_last_handshake;
  logic i_read, i_write, tog_i_read, tog_i_write;

  logic_2_t done_read_next, done_write_next, clken_ref;
  logic_2_t done_read, done_write, bram_resetn, bram_wen, bram_w_full, bram_m_ready, bram_m_valid;

  logic[M_WIDTH-1:0]      bram_m_data  [2];
  
  logic [BITS_R_ADDR-1:0] s_r_addr_max; 
  logic [BITS_R_ADDR-1:0] s_r_addr_min; 
  logic [BITS_R_ADDR-1:0] r_addr_min      [2];
  logic [BITS_R_ADDR-1:0] r_addr_max      [2];
  logic [BITS_W_ADDR-1:0] w_addr_max_next [2];
  logic [BITS_W_ADDR-1:0] w_addr_max      [2];
  logic [BITS_CONFIG_COUNT-1:0] count_config, count_config_next;
  logic [BITS_CONFIG_COUNT-1:0] ref_config_1 [2];

  logic [BITS_KERNEL_W_MAX-1:0] s_kw_1, ref_1_kw [2];
  logic [BITS_KERNEL_H_MAX-1:0] s_kh_1    , count_kh    , count_next_kh    , ref_1_kh     [2];
  logic [BITS_IM_CIN      -1:0] s_cin_1   , count_cin   , count_next_cin   , ref_1_cin    [2];
  logic [BITS_IM_COLS     -1:0] s_cols_1  , count_cols  , count_next_cols  , ref_1_cols   [2];
  logic [BITS_IM_BLOCKS   -1:0] s_blocks_1, count_blocks, count_next_blocks, ref_1_blocks [2];

  logic en_count_kh, en_count_cin, en_count_cols, en_count_blocks, en_count_config;

  logic last_kh, last_cin, last_cols, last_blocks;
  logic last_next_kh, last_next_cin, last_next_cols, last_next_blocks;

  axis_dw_weights_input DW (
    .aclk           (aclk),
    .aresetn        (aresetn),
    .s_axis_tvalid  (dw_s_valid     ),
    .s_axis_tready  (dw_s_ready     ),
    .s_axis_tdata   (s_axis_tdata   ),
    .s_axis_tkeep   (s_axis_tkeep   ),
    .s_axis_tlast   (s_axis_tlast   ),
    .m_axis_tvalid  (dw_m_valid     ),
    .m_axis_tready  (dw_m_ready     ),
    .m_axis_tdata   (dw_m_data      ),
    .m_axis_tlast   (dw_m_last      )
  );
  /*
    Extract s_data into inputs of ref registers
    This will give error if SUM_BITS > WEIGHTS_DMA_BITS
  */
  localparam SUM_BITS = BITS_KERNEL_W_MAX + BITS_KERNEL_H_MAX + BITS_IM_CIN + BITS_IM_COLS + BITS_IM_BLOCKS;
  assign {s_blocks_1, s_cols_1, s_cin_1, s_kh_1, s_kw_1} = s_axis_tdata[SUM_BITS-1:0];
  
  // s_r_addr_max = (s_kh_1+1)*(s_cin_1+1) = (s_kh_1 * s_cin_1) + s_kh_1 + s_cin_1 +1
  assign s_r_addr_max = (s_kh_1 * s_cin_1) + s_kh_1 + s_cin_1 + s_r_addr_min;
  assign s_r_addr_min = (s_kh_1==0 ? BEATS_CONFIG_1X1_1 : BEATS_CONFIG_3X3_1) + 1;

  assign dw_m_handshake      = dw_m_valid  && dw_m_ready;
  assign dw_m_last_handshake = dw_m_handshake && dw_m_last;

  /*
    STATE MACHINE: WRITE
  */

  localparam W_IDLE_S     = 0;
  localparam W_GET_REF_S  = 1;
  localparam W_WRITE_S    = 2;
  localparam W_FILL_S     = 3;
  localparam W_SWITCH_S   = 4;
  localparam BITS_W_STATE = 3;

  logic [BITS_W_STATE-1:0] state_write, state_write_next;

  always_comb begin
    state_write_next = state_write;
    unique case (state_write)
      W_IDLE_S    : if (done_read    [i_write]) state_write_next = W_GET_REF_S;
      W_GET_REF_S : if (s_handshake           ) state_write_next = W_WRITE_S;
      W_WRITE_S   : if (dw_m_last_handshake   ) state_write_next = W_FILL_S;    // dw_m_last_handshake and bram_w_full[w_i] should be same
      W_FILL_S    : if (bram_m_valid [i_write]) state_write_next = W_SWITCH_S;
      W_SWITCH_S  : state_write_next = W_IDLE_S;
    endcase 
  end

  register #(
    .WORD_WIDTH   (BITS_W_STATE), 
    .RESET_VALUE  (W_IDLE_S)
  ) STATE_W (
    .clock        (aclk),
    .clock_enable (1'b1),
    .resetn       (aresetn),
    .data_in      (state_write_next),
    .data_out     (state_write)
  );

  /*
    STATE MACHINE: READ
  */

  localparam R_IDLE_S        = 0;
  localparam R_PASS_CONFIG_S = 1;
  localparam R_READ_S        = 2;
  localparam R_SWITCH_S      = 3;
  localparam BITS_R_STATE    = 2;

  logic [BITS_R_STATE-1:0] state_read, state_read_next;

  always_comb begin

      en_count_config   = 0;
      en_count_kh       = 0; 
      count_config_next = (ref_1_kh[i_read] == 0) ? BEATS_CONFIG_1X1_1 : BEATS_CONFIG_3X3_1;

    unique case (state_read)
      R_IDLE_S        : begin
                          en_count_config = 1;
                        end
      R_PASS_CONFIG_S : begin
                          count_config_next  = count_config -1;
                          en_count_config    = m_axis_tready;
                        end
      R_READ_S        : begin
                          en_count_kh    = m_axis_tready;
                        end
      R_SWITCH_S      : begin
                        end
    endcase 

    state_read_next = state_read;
    unique case (state_read)
      R_IDLE_S        : if (done_write [i_read])                               state_read_next = R_PASS_CONFIG_S;
      R_PASS_CONFIG_S : if (count_config == 0)                                 state_read_next = R_READ_S;
      R_READ_S        : if (en_count_blocks && (count_blocks == ref_1_blocks)) state_read_next = R_SWITCH_S;
      R_SWITCH_S      : state_read_next = R_IDLE_S;
    endcase 
  end

  register #(
    .WORD_WIDTH   (BITS_R_STATE), 
    .RESET_VALUE  (R_IDLE_S)
  ) STATE_R (
    .clock        (aclk),
    .clock_enable (1'b1),
    .resetn       (aresetn),
    .data_in      (state_read_next),
    .data_out     (state_read)
  );

  assign tog_i_write = state_write == W_SWITCH_S;
  assign tog_i_read  = state_read  == R_SWITCH_S;

  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) I_WRITE (
    .clock        (aclk),
    .clock_enable (tog_i_write),
    .resetn       (aresetn),
    .data_in      (~i_write),
    .data_out     ( i_write)
  );
  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) I_READ (
    .clock        (aclk),
    .clock_enable (tog_i_read),
    .resetn       (aresetn),
    .data_in      (~i_read),
    .data_out     ( i_read)
  );
  
    /*
    FSM to bypass DATAWIDTH CONVERTER

    - slave side is smaller (32 bits)
    - get config bits from slave side
  */

  localparam DW_BLOCK_S = 0;
  localparam DW_PASS_S  = 1;
 
  assign s_handshake      = s_axis_tready && s_axis_tvalid;
  assign s_last_handshake = s_handshake   && s_axis_tlast;

  always_comb begin
    if (state_dw == DW_BLOCK_S) begin
      dw_m_ready    = 0;
      dw_s_valid    = 0;
      s_axis_tready = (state_write == W_GET_REF_S);

      if (s_last_handshake) state_dw_next = DW_PASS_S;
    end
    else begin
      dw_m_ready = (state_write == W_WRITE_S);
      dw_s_valid = s_axis_tvalid;
      s_axis_tready = dw_s_ready;

      if (s_last_handshake) state_dw_next = DW_BLOCK_S;
    end
  end

  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (DW_BLOCK_S)
  ) STATE_DW (
    .clock        (aclk),
    .clock_enable (1'b1),
    .resetn       (aresetn),
    .data_in      (state_dw_next),
    .data_out     (state_dw)
  );

  generate
    for (genvar i=0; i<2; i++) begin

      always_comb begin
        bram_resetn     [i] = 1;
        bram_wen        [i] = 0;
        clken_ref       [i] = 0;
        done_write_next [i] = done_write[i];
        
        if (i==i_write) begin
          unique case (state_write)
            W_IDLE_S    : begin
                          end
            W_GET_REF_S : begin
                            done_write_next [i] = 0;
                            bram_resetn     [i] = 0;
                            clken_ref       [i] = 1;
                          end
            W_WRITE_S   : begin
                            bram_wen[i] = dw_m_handshake;
                          end
            W_FILL_S    : begin
                          end
            W_SWITCH_S  : begin
                            done_write_next[i] = 1;
                          end
          endcase 
        end

        done_read_next[i]    = done_read[i];

        if (i==i_read) begin
          unique case (state_read)
            R_IDLE_S        : begin
                              end
            R_PASS_CONFIG_S : begin
                                done_read_next [i] = 0;
                              end
            R_READ_S        : begin
                              end
            R_SWITCH_S      : begin
                                done_read_next [i] = 1;
                              end
          endcase 
        end
      end

      always_valid_cyclic_bram #(
        .W_DEPTH (BRAM_W_DEPTH), 
        .W_WIDTH (BRAM_W_WIDTH),
        .R_WIDTH (BRAM_R_WIDTH),
        .LATENCY (BRAM_LATENCY),
        .IP_TYPE (2)
      ) BRAM (
        .clk          (aclk),
        .clken        (1'b1),
        .resetn       (aresetn && bram_resetn [i]),
        .s_data       (dw_m_data),
        .s_valid_ready(bram_wen    [i]),
        .m_data       (bram_m_data [i]),
        .m_ready      (bram_m_ready[i]),
        .w_full       (bram_w_full [i]),
        .r_addr_min   (r_addr_min  [i]),
        .r_addr_max   (r_addr_max  [i]),
        .w_addr_max   (w_addr_max  [i])
      );
      
      register #(
        .WORD_WIDTH   (1), 
        .RESET_VALUE  (0)
      ) DONE_WRITE (
        .clock        (aclk),
        .clock_enable (1'b1),
        .resetn       (aresetn),
        .data_in      (done_write_next[i]),
        .data_out     (done_write     [i])
      );
      register #(
        .WORD_WIDTH   (1), 
        .RESET_VALUE  (1)
      ) DONE_READ (
        .clock        (aclk),
        .clock_enable (1'b1),
        .resetn       (aresetn),
        .data_in      (done_read_next[i]),
        .data_out     (done_read     [i])
      );
      register #(
        .WORD_WIDTH   (BITS_W_ADDR), 
        .RESET_VALUE  (0)
      ) W_ADDR_MAX (
        .clock        (aclk),
        .clock_enable (1'b1),
        .resetn       (aresetn),
        .data_in      (w_addr_max_next[i]),
        .data_out     (w_addr_max     [i])
      );

      /*
        REFERENCE REGISTERS

        - clken_ref [i_write] = (state == W_GET_REF_S)
      */

      register #(
        .WORD_WIDTH   (BITS_KERNEL_W_MAX), 
        .RESET_VALUE  (0)
      ) REF_KW_1 (
        .clock        (aclk),
        .resetn       (aresetn),
        .data_in      (s_kw_1),
        .clock_enable (clken_ref [i]),
        .data_out     (ref_1_kw  [i])
      );
      register #(
        .WORD_WIDTH   (BITS_KERNEL_H_MAX), 
        .RESET_VALUE  (0)
      ) REF_KH_1 (
        .clock        (aclk),
        .resetn       (aresetn),
        .data_in      (s_kh_1),
        .clock_enable (clken_ref [i]),
        .data_out     (ref_1_kh  [i])
      );
      register #(
        .WORD_WIDTH   (BITS_IM_CIN), 
        .RESET_VALUE  (0)
      ) REF_CIN_1 (
        .clock        (aclk),
        .resetn       (aresetn),
        .data_in      (s_cin_1),
        .clock_enable (clken_ref  [i]),
        .data_out     (ref_1_cin  [i])
      );
      register #(
        .WORD_WIDTH   (BITS_IM_COLS), 
        .RESET_VALUE  (0)
      ) REF_COLS_1 (
        .clock        (aclk),
        .resetn       (aresetn),
        .data_in      (s_cols_1),
        .clock_enable (clken_ref  [i]),
        .data_out     (ref_1_cols [i])
      );
      register #(
        .WORD_WIDTH   (BITS_IM_BLOCKS), 
        .RESET_VALUE  (0)
      ) REF_BLOCKS_1 (
        .clock        (aclk),
        .resetn       (aresetn),
        .data_in      (s_blocks_1),
        .clock_enable (clken_ref    [i]),
        .data_out     (ref_1_blocks [i])
      );

      /*
        Address Max, Min registers:
      */
      register #(
        .WORD_WIDTH   (BITS_R_ADDR), 
        .RESET_VALUE  (0)
      ) R_ADDR_MIN (
        .clock        (aclk),
        .clock_enable (clken_ref  [i]),
        .resetn       (aresetn),
        .data_in      (s_r_addr_min),
        .data_out     (r_addr_min [i])
      );
      register #(
        .WORD_WIDTH   (BITS_R_ADDR), 
        .RESET_VALUE  (0)
      ) R_ADDR_MAX (
        .clock        (aclk),
        .clock_enable (clken_ref  [i]),
        .resetn       (aresetn),
        .data_in      (s_r_addr_max),
        .data_out     (r_addr_max [i])
      );

    end
  endgenerate

  /*
    COUNTER REGISTERS

    - en_count_config = (state_read == R_PASS_CONFIG_S) ? m_axis_tready : 0;
    - en_count_kh    = (state_read == R_READ_S       ) ? m_axis_tready : 0;
  */

  register #(
    .WORD_WIDTH   (BITS_CONFIG_COUNT), 
    .RESET_VALUE  (0)
  ) CONFIG_COUNT (
    .clock        (aclk),
    .resetn       (aresetn),
    .clock_enable (en_count_config),
    .data_in      (count_config_next),
    .data_out     (count_config)
  );

  assign count_next_kh     = last_kh     ? ref_1_kh    [i_read] : count_kh     - 1;
  assign count_next_cin    = last_cin    ? ref_1_cin   [i_read] : count_cin    - 1;
  assign count_next_cols   = last_cols   ? ref_1_cols  [i_read] : count_cols   - 1;
  assign count_next_blocks = last_blocks ? ref_1_blocks[i_read] : count_blocks - 1;

  assign last_next_kh      = (count_kh     == 1);
  assign last_next_cin     = (count_cin    == 1);
  assign last_next_cols    = (count_cols   == 1);
  assign last_next_blocks  = (count_blocks == 1);

  assign en_count_cin      = en_count_kh     && last_kh ;
  assign en_count_cols     = en_count_cin    && last_cin ;
  assign en_count_blocks   = en_count_cols   && last_cols;

  assign m_axis_tlast = last_kh && last_cin && last_cols && last_blocks;
  
  assign m_axis_tuser [I_IS_CONFIG  ] = state_read  == R_PASS_CONFIG_S;
  assign m_axis_tuser [I_CONV_IS_1X1] = ref_1_kw == 0;
  assign m_axis_tuser [I_KERNEL_W_1+BITS_KERNEL_W_MAX-1: I_KERNEL_W_1] = ref_1_kw [i_read];
  assign m_axis_tuser [I_KERNEL_H_1+BITS_KERNEL_H_MAX-1: I_KERNEL_H_1] = ref_1_kh [i_read];

  assign m_axis_tuser [I_CONV_IS_COLS_1_K2] = count_cols   == ref_1_kw [i_read]/2; // i = cols-1-k/2 === [cols-1-i] = k/2
  assign m_axis_tuser [I_LRELU_IS_TOP     ] = count_blocks == ref_1_blocks;
  assign m_axis_tuser [I_LRELU_IS_BOTTOM  ] = last_blocks;

  register #(
    .WORD_WIDTH   (BITS_KERNEL_H_MAX), 
    .RESET_VALUE  (0)
  ) COUNT_KH (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (count_next_kh),
    .clock_enable (en_count_kh),
    .data_out     (count_kh)
  );
  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) LAST_KH (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (last_next_kh),
    .clock_enable (en_count_kh),
    .data_out     (last_kh)
  );
  register #(
    .WORD_WIDTH   (BITS_IM_CIN), 
    .RESET_VALUE  (0)
  ) COUNT_CIN (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (count_next_cin),
    .clock_enable (en_count_cin),
    .data_out     (count_cin)
  );
  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) LAST_CIN (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (last_next_cin),
    .clock_enable (en_count_cin),
    .data_out     (last_cin)
  );
  register #(
    .WORD_WIDTH   (BITS_IM_COLS), 
    .RESET_VALUE  (0)
  ) COUNT_COLS (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (count_next_cols),
    .clock_enable (en_count_cols),
    .data_out     (count_cols)
  );
  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) LAST_COLS (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (last_next_cols),
    .clock_enable (en_count_cols),
    .data_out     (last_cols)
  );
  register #(
    .WORD_WIDTH   (BITS_IM_BLOCKS), 
    .RESET_VALUE  (0)
  ) COUNT_BLOCKS (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (count_next_blocks),
    .clock_enable (en_count_blocks),
    .data_out     (count_blocks)
  );
  register #(
    .WORD_WIDTH   (1), 
    .RESET_VALUE  (0)
  ) LAST_BLOCKS (
    .clock        (aclk),
    .resetn       (aresetn),
    .data_in      (last_next_blocks),
    .clock_enable (en_count_blocks),
    .data_out     (last_blocks)
  );


endmodule
