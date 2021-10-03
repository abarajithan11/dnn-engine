`timescale 1ns/1ps
`include "params.v"

module axis_accelerator #(ZERO=0) (
    aclk                  ,
    aresetn               ,
    hf_aclk               ,
    hf_aresetn            ,
    debug_config          ,
    s_axis_pixels_tready  , 
    s_axis_pixels_tvalid  , 
    s_axis_pixels_tlast   , 
    s_axis_pixels_tdata   , 
    s_axis_pixels_tkeep   ,   
    s_axis_weights_tready ,
    s_axis_weights_tvalid ,
    s_axis_weights_tlast  ,
    s_axis_weights_tdata  ,
    s_axis_weights_tkeep  ,

    conv_dw_lf_m_axis_tready ,
    conv_dw_lf_m_axis_tvalid ,
    conv_dw_lf_m_axis_tlast  ,
    conv_dw_lf_m_axis_tdata  ,
    conv_dw_lf_m_axis_tuser  ,

    lrelu_m_axis_tready,
    lrelu_m_axis_tvalid,
    lrelu_m_axis_tlast,
    lrelu_m_axis_tuser,
    lrelu_m_axis_tdata,

    lrelu_dw_lf_m_axis_tvalid,
    lrelu_dw_lf_m_axis_tlast ,
    lrelu_dw_lf_m_axis_tready,
    lrelu_dw_lf_m_axis_tdata ,
    lrelu_dw_lf_m_axis_tkeep ,

    max_m_axis_tvalid,
    max_m_axis_tready,
    max_m_axis_tlast,
    max_m_axis_tkeep,
    max_m_axis_tdata,

    max_dw2_lf_m_axis_tvalid ,
    max_dw2_lf_m_axis_tready ,
    max_dw2_lf_m_axis_tdata  ,
    max_dw2_lf_m_axis_tkeep  ,
    max_dw2_lf_m_axis_tlast  
  ); 

  localparam S_PIXELS_WIDTH_LF = `S_PIXELS_WIDTH_LF   ;
  localparam BITS_KH2          = `BITS_KH2            ;
  localparam OUTPUT_MODE       = `OUTPUT_MODE         ;
  localparam FREQ_RATIO        = `FREQ_RATIO          ;

  localparam S_WEIGHTS_WIDTH_LF= `S_WEIGHTS_WIDTH_LF  ;
  localparam M_DATA_WIDTH_LF   = `M_DATA_WIDTH_LF     ;
  localparam M_DATA_WIDTH_HF_CONV    = `M_DATA_WIDTH_HF_CONV   ;
  localparam M_DATA_WIDTH_HF_CONV_DW = `M_DATA_WIDTH_HF_CONV_DW;
  localparam M_DATA_WIDTH_LF_CONV_DW = `M_DATA_WIDTH_LF_CONV_DW;
  localparam M_DATA_WIDTH_HF_LRELU   = `M_DATA_WIDTH_HF_LRELU  ;
  localparam M_DATA_WIDTH_LF_LRELU   = `M_DATA_WIDTH_LF_LRELU  ;
  localparam M_DATA_WIDTH_HF_MAXPOOL = `M_DATA_WIDTH_HF_MAXPOOL;
  localparam M_DATA_WIDTH_HF_MAX_DW1 = `M_DATA_WIDTH_HF_MAX_DW1;
  localparam M_DATA_WIDTH_LF_MAXPOOL = `M_DATA_WIDTH_LF_MAXPOOL;

  localparam UNITS                      = `UNITS                ;
  localparam GROUPS                     = `GROUPS               ;
  localparam COPIES                     = `COPIES               ;
  localparam MEMBERS                    = `MEMBERS              ;
  localparam WORD_WIDTH                 = `WORD_WIDTH           ; 
  localparam WORD_WIDTH_ACC             = `WORD_WIDTH_ACC       ;
  // DEBUG WIDTHS
  localparam DEBUG_CONFIG_WIDTH_W_ROT   = `DEBUG_CONFIG_WIDTH_W_ROT  ;
  localparam DEBUG_CONFIG_WIDTH_IM_PIPE = `DEBUG_CONFIG_WIDTH_IM_PIPE;
  localparam DEBUG_CONFIG_WIDTH_LRELU   = `DEBUG_CONFIG_WIDTH_LRELU  ;
  localparam DEBUG_CONFIG_WIDTH_MAXPOOL = `DEBUG_CONFIG_WIDTH_MAXPOOL;
  localparam DEBUG_CONFIG_WIDTH         = `DEBUG_CONFIG_WIDTH        ;
  // LATENCIES & float widths 
  localparam TUSER_WIDTH_CONV_IN        = `TUSER_WIDTH_CONV_IN       ;
  localparam TUSER_CONV_DW_IN           = `TUSER_CONV_DW_IN          ;
  localparam TUSER_WIDTH_MAXPOOL_IN     = `TUSER_WIDTH_MAXPOOL_IN    ;
  localparam TUSER_WIDTH_LRELU_FMA_1_IN = `TUSER_WIDTH_LRELU_FMA_1_IN;
  localparam TUSER_WIDTH_LRELU_IN       = `TUSER_WIDTH_LRELU_IN      ;

  localparam I_IS_CONFIG = `I_IS_CONFIG;

  /* WIRES */

  input  wire aclk;
  input  wire aresetn;
  input  wire hf_aclk;
  input  wire hf_aresetn;

  output wire [DEBUG_CONFIG_WIDTH-1:0] debug_config;

  output wire s_axis_pixels_tready;
  input  wire s_axis_pixels_tvalid;
  input  wire s_axis_pixels_tlast ;
  input  wire [S_PIXELS_WIDTH_LF  -1:0] s_axis_pixels_tdata;
  input  wire [S_PIXELS_WIDTH_LF/8-1:0] s_axis_pixels_tkeep;

  output wire s_axis_weights_tready;
  input  wire s_axis_weights_tvalid;
  input  wire s_axis_weights_tlast ;
  input  wire [S_WEIGHTS_WIDTH_LF    -1:0] s_axis_weights_tdata;
  input  wire [S_WEIGHTS_WIDTH_LF /8 -1:0] s_axis_weights_tkeep;

  wire m_axis_weights_clk_tready;
  wire m_axis_weights_clk_tvalid;
  wire m_axis_weights_clk_tlast ;
  wire [S_WEIGHTS_WIDTH_LF    -1:0] m_axis_weights_clk_tdata;
  wire [S_WEIGHTS_WIDTH_LF /8 -1:0] m_axis_weights_clk_tkeep;

  wire input_m_axis_tready;
  wire input_m_axis_tvalid;
  wire input_m_axis_tlast ;
  wire [COPIES*WORD_WIDTH*UNITS          -1:0] input_m_axis_pixels_tdata;
  wire [WORD_WIDTH*COPIES*GROUPS*MEMBERS -1:0] input_m_axis_weights_tdata;
  wire [TUSER_WIDTH_CONV_IN              -1:0] input_m_axis_tuser        ;

  wire conv_m_axis_tready;
  wire conv_m_axis_tvalid;
  wire conv_m_axis_tlast ;
  wire [TUSER_CONV_DW_IN             -1:0] conv_m_axis_tuser;
  wire [M_DATA_WIDTH_HF_CONV         -1:0] conv_m_axis_tdata; // cgmu

  input  wire conv_dw_lf_m_axis_tready;
  output wire conv_dw_lf_m_axis_tvalid;
  output wire conv_dw_lf_m_axis_tlast ;
  output wire [TUSER_WIDTH_LRELU_IN    -1:0] conv_dw_lf_m_axis_tuser;
  output wire [M_DATA_WIDTH_HF_CONV_DW -1:0] conv_dw_lf_m_axis_tdata;

  output wire lrelu_m_axis_tvalid;
  output wire lrelu_m_axis_tlast;
  output wire lrelu_m_axis_tready;
  output wire [M_DATA_WIDTH_HF_LRELU -1:0] lrelu_m_axis_tdata;
  output wire [TUSER_WIDTH_MAXPOOL_IN-1:0] lrelu_m_axis_tuser;

  wire lrelu_dw_m_axis_tvalid;
  wire lrelu_dw_m_axis_tlast;
  wire lrelu_dw_m_axis_tready;
  wire [M_DATA_WIDTH_LF_LRELU   -1:0] lrelu_dw_m_axis_tdata;
  wire [M_DATA_WIDTH_LF_LRELU/8 -1:0] lrelu_dw_m_axis_tkeep;

  input  wire lrelu_dw_lf_m_axis_tready;
  output wire lrelu_dw_lf_m_axis_tvalid;
  output wire lrelu_dw_lf_m_axis_tlast;
  output wire [M_DATA_WIDTH_LF_LRELU   -1:0] lrelu_dw_lf_m_axis_tdata;
  output wire [M_DATA_WIDTH_LF_LRELU/8 -1:0] lrelu_dw_lf_m_axis_tkeep;

  output wire max_m_axis_tvalid;
  output wire max_m_axis_tready;
  output wire max_m_axis_tlast;
  output wire [M_DATA_WIDTH_HF_MAXPOOL/8 -1:0] max_m_axis_tkeep;
  output wire [M_DATA_WIDTH_HF_MAXPOOL   -1:0] max_m_axis_tdata;

  wire max_dw1_m_axis_tvalid;
  wire max_dw1_m_axis_tready;
  wire max_dw1_m_axis_tlast;
  wire [M_DATA_WIDTH_HF_MAX_DW1   -1:0] max_dw1_m_axis_tdata;
  wire [M_DATA_WIDTH_HF_MAX_DW1/8 -1:0] max_dw1_m_axis_tkeep;

  wire                         max_dw2_m_axis_tready;
  wire                         max_dw2_m_axis_tvalid;
  wire                         max_dw2_m_axis_tlast;
  wire [M_DATA_WIDTH_LF_MAXPOOL  -1:0] max_dw2_m_axis_tdata;
  wire [M_DATA_WIDTH_LF_MAXPOOL/8-1:0] max_dw2_m_axis_tkeep;

  input  wire max_dw2_lf_m_axis_tready;
  output wire max_dw2_lf_m_axis_tvalid;
  output wire max_dw2_lf_m_axis_tlast;
  output wire [M_DATA_WIDTH_LF_MAXPOOL  -1:0] max_dw2_lf_m_axis_tdata;
  output wire [M_DATA_WIDTH_LF_MAXPOOL/8-1:0] max_dw2_lf_m_axis_tkeep;

  wire                           m_axis_pixels_clk_tready;
  wire                           m_axis_pixels_clk_tvalid;
  wire                           m_axis_pixels_clk_tlast ;
  wire [S_PIXELS_WIDTH_LF  -1:0] m_axis_pixels_clk_tdata;
  wire [S_PIXELS_WIDTH_LF/8-1:0] m_axis_pixels_clk_tkeep;

  wire [2*BITS_KH2     +DEBUG_CONFIG_WIDTH_IM_PIPE+DEBUG_CONFIG_WIDTH_W_ROT-1:0] debug_config_input_pipe;
  wire [DEBUG_CONFIG_WIDTH_LRELU  -1:0] debug_config_lrelu;
  wire [DEBUG_CONFIG_WIDTH_MAXPOOL-1:0] debug_config_maxpool;
  assign debug_config = {debug_config_maxpool, debug_config_lrelu, debug_config_input_pipe};

  `ifdef `XILINX
    localparam XILINX = 1;
  `else
    localparam XILINX = 0;
  `endif

  if (FREQ_RATIO == 1 | XILINX == 0) begin
    assign s_axis_weights_tready     = m_axis_weights_clk_tready;
    assign m_axis_weights_clk_tvalid = s_axis_weights_tvalid;
    assign m_axis_weights_clk_tlast  = s_axis_weights_tlast ;
    assign m_axis_weights_clk_tdata  = s_axis_weights_tdata ;
    assign m_axis_weights_clk_tkeep  = s_axis_weights_tkeep ;

    assign s_axis_pixels_tready      = m_axis_pixels_clk_tready;
    assign m_axis_pixels_clk_tvalid  = s_axis_pixels_tvalid;
    assign m_axis_pixels_clk_tlast   = s_axis_pixels_tlast ;
    assign m_axis_pixels_clk_tdata   = s_axis_pixels_tdata ;
    assign m_axis_pixels_clk_tkeep   = s_axis_pixels_tkeep ;
  end else begin
    axis_clk_weights CLK_WEIGHTS (
      .s_axis_aresetn (aresetn ),  
      .s_axis_aclk    (aclk    ),    
      .s_axis_tready  (s_axis_weights_tready),
      .s_axis_tvalid  (s_axis_weights_tvalid),
      .s_axis_tlast   (s_axis_weights_tlast ),  
      .s_axis_tdata   (s_axis_weights_tdata ),  
      .s_axis_tkeep   (s_axis_weights_tkeep ),  

      .m_axis_aclk    (hf_aclk    ),    
      .m_axis_aresetn (hf_aresetn ),  
      .m_axis_tready  (m_axis_weights_clk_tready),
      .m_axis_tvalid  (m_axis_weights_clk_tvalid),
      .m_axis_tlast   (m_axis_weights_clk_tlast ),
      .m_axis_tdata   (m_axis_weights_clk_tdata ),
      .m_axis_tkeep   (m_axis_weights_clk_tkeep )   
    );
    axis_clk_image CLK_IMAGE_1 (
      .s_axis_aresetn (aresetn ),  
      .s_axis_aclk    (aclk    ),    
      .s_axis_tready  (s_axis_pixels_tready),
      .s_axis_tvalid  (s_axis_pixels_tvalid),
      .s_axis_tlast   (s_axis_pixels_tlast ),  
      .s_axis_tdata   (s_axis_pixels_tdata ),  
      .s_axis_tkeep   (s_axis_pixels_tkeep ),  

      .m_axis_aclk    (hf_aclk    ),    
      .m_axis_aresetn (hf_aresetn ),  
      .m_axis_tready  (m_axis_pixels_clk_tready),
      .m_axis_tvalid  (m_axis_pixels_clk_tvalid),
      .m_axis_tlast   (m_axis_pixels_clk_tlast ),
      .m_axis_tdata   (m_axis_pixels_clk_tdata ),
      .m_axis_tkeep   (m_axis_pixels_clk_tkeep )   
    );
  end

  axis_input_pipe #(.ZERO(ZERO)) input_pipe (
    .aclk                      (hf_aclk                    ),
    .aresetn                   (hf_aresetn                 ),
    .debug_config              (debug_config_input_pipe    ),
    .s_axis_pixels_tready      (m_axis_pixels_clk_tready   ), 
    .s_axis_pixels_tvalid      (m_axis_pixels_clk_tvalid   ), 
    .s_axis_pixels_tlast       (m_axis_pixels_clk_tlast    ), 
    .s_axis_pixels_tdata       (m_axis_pixels_clk_tdata    ), 
    .s_axis_pixels_tkeep       (m_axis_pixels_clk_tkeep    ), 
    .s_axis_weights_tready     (m_axis_weights_clk_tready  ),
    .s_axis_weights_tvalid     (m_axis_weights_clk_tvalid  ),
    .s_axis_weights_tlast      (m_axis_weights_clk_tlast   ),
    .s_axis_weights_tdata      (m_axis_weights_clk_tdata   ),
    .s_axis_weights_tkeep      (m_axis_weights_clk_tkeep   ),
    .m_axis_tready             (input_m_axis_tready        ),      
    .m_axis_tvalid             (input_m_axis_tvalid        ),     
    .m_axis_tlast              (input_m_axis_tlast         ),     
    .m_axis_pixels_tdata       (input_m_axis_pixels_tdata  ),
    .m_axis_weights_tdata      (input_m_axis_weights_tdata ), // CMG_flat
    .m_axis_tuser              (input_m_axis_tuser         )
  );

  axis_conv_engine #(.ZERO(ZERO)) CONV_ENGINE (
    .aclk                 (hf_aclk                    ),
    .aresetn              (hf_aresetn                 ),
    .s_axis_tvalid        (input_m_axis_tvalid        ),
    .s_axis_tready        (input_m_axis_tready        ),
    .s_axis_tlast         (input_m_axis_tlast         ),
    .s_axis_tuser         (input_m_axis_tuser         ),
    .s_axis_tdata_pixels  (input_m_axis_pixels_tdata  ), // cu
    .s_axis_tdata_weights (input_m_axis_weights_tdata ), // cr = cmg
    .m_axis_tvalid        (conv_m_axis_tvalid         ),
    .m_axis_tready        (conv_m_axis_tready         ),
    .m_axis_tdata         (conv_m_axis_tdata          ), // cmgu
    .m_axis_tlast         (conv_m_axis_tlast          ),
    .m_axis_tuser         (conv_m_axis_tuser          )
    );
  generate
    if (OUTPUT_MODE == "CONV") begin
      axis_conv_dw_bank #(.ZERO(ZERO)) CONV_DW (
        .aclk    (hf_aclk               ),
        .aresetn (hf_aresetn            ),
        .s_ready (conv_m_axis_tready    ),
        .s_valid (conv_m_axis_tvalid & ~conv_m_axis_tuser[I_IS_CONFIG]),
        .s_data  (conv_m_axis_tdata     ),
        .s_user  (conv_m_axis_tuser     ),
        .s_last  (conv_m_axis_tlast     ),
        .m_ready (conv_dw_lf_m_axis_tready),
        .m_valid (conv_dw_lf_m_axis_tvalid),
        .m_data  (conv_dw_lf_m_axis_tdata ),
        .m_user  (conv_dw_lf_m_axis_tuser ),
        .m_last  (conv_dw_lf_m_axis_tlast )
      );
      // axis_clk_conv_dw CLK_CONV_DW (
      //   .s_axis_aresetn (hf_aresetn ),  
      //   .s_axis_aclk    (hf_aclk    ),    
      //   .s_axis_tvalid  (conv_dw2_m_axis_tvalid),
      //   .s_axis_tready  (conv_dw2_m_axis_tready),
      //   .s_axis_tdata   (conv_dw2_m_axis_tdata ),  
      //   .s_axis_tlast   (conv_dw2_m_axis_tlast ) 

      //   .m_axis_aclk    (aclk      ),    
      //   .m_axis_aresetn (aresetn   ),  
      //   .m_axis_tready  (conv_dw2_lf_m_axis_tready),
      //   .m_axis_tvalid  (conv_dw2_lf_m_axis_tvalid),
      //   .m_axis_tlast   (conv_dw2_lf_m_axis_tlast ),
      //   .m_axis_tdata   (conv_dw2_lf_m_axis_tdata )  
      // );
    end
  //   else begin
  //     axis_lrelu_engine #(.ZERO(ZERO)) LRELU_ENGINE (
  //       .aclk          (hf_aclk              ),
  //       .aresetn       (hf_aresetn           ),
  //       .debug_config  (debug_config_lrelu   ),
  //       .s_axis_tvalid (conv_m_axis_tvalid   ),
  //       .s_axis_tready (conv_m_axis_tready   ),
  //       .s_axis_tdata  (conv_m_axis_tdata    ), // cgmu
  //       .s_axis_tkeep  (conv_m_axis_tkeep    ), // cgmu
  //       .s_axis_tlast  (conv_m_axis_tlast    ),
  //       .s_axis_tuser  (conv_m_axis_tuser    ),
  //       .m_axis_tvalid (lrelu_m_axis_tvalid  ),
  //       .m_axis_tready (lrelu_m_axis_tready  ),
  //       .m_axis_tlast  (lrelu_m_axis_tlast   ),
  //       .m_axis_tdata  (lrelu_m_axis_tdata   ), // cgu
  //       .m_axis_tuser  (lrelu_m_axis_tuser   )
  //     );

  //     if (OUTPUT_MODE == "LRELU") begin
  //       axis_dw_lrelu DW_LRELU (
  //       .aclk           (hf_aclk                ),           
  //       .aresetn        (hf_aresetn             ),        
  //       .s_axis_tvalid  (lrelu_m_axis_tvalid    ),  
  //       .s_axis_tready  (lrelu_m_axis_tready    ),  
  //       .s_axis_tlast   (lrelu_m_axis_tlast     ),   
  //       .s_axis_tdata   (lrelu_m_axis_tdata     ),  
  //       .s_axis_tkeep   ({(M_DATA_WIDTH_HF_LRELU/8){1'b1}}),   

  //       .m_axis_tready  (lrelu_dw_m_axis_tready  ),  
  //       .m_axis_tvalid  (lrelu_dw_m_axis_tvalid  ),  
  //       .m_axis_tlast   (lrelu_dw_m_axis_tlast   ),    
  //       .m_axis_tdata   (lrelu_dw_m_axis_tdata   ),   
  //       .m_axis_tkeep   (lrelu_dw_m_axis_tkeep   )   
  //     );

  //     axis_clk_lrelu CLK_LRELU (
  //       .s_axis_aresetn (hf_aresetn ),  
  //       .s_axis_aclk    (hf_aclk    ),    
  //       .s_axis_tready  (lrelu_dw_m_axis_tready),
  //       .s_axis_tvalid  (lrelu_dw_m_axis_tvalid),
  //       .s_axis_tlast   (lrelu_dw_m_axis_tlast ),  
  //       .s_axis_tdata   (lrelu_dw_m_axis_tdata ),  
  //       .s_axis_tkeep   (lrelu_dw_m_axis_tkeep ),  

  //       .m_axis_aclk    (aclk      ),    
  //       .m_axis_aresetn (aresetn   ),  
  //       .m_axis_tready  (lrelu_dw_lf_m_axis_tready),
  //       .m_axis_tvalid  (lrelu_dw_lf_m_axis_tvalid),
  //       .m_axis_tlast   (lrelu_dw_lf_m_axis_tlast ),
  //       .m_axis_tdata   (lrelu_dw_lf_m_axis_tdata ),
  //       .m_axis_tkeep   (lrelu_dw_lf_m_axis_tkeep )   
  //     );
  //   end
  //   else if (COPIES == 2 && OUTPUT_MODE == "MAXPOOL") begin
  //     axis_maxpool_engine #(.ZERO(ZERO)) MAXPOOL_ENGINE (
  //       .aclk          (hf_aclk               ),
  //       .aresetn       (hf_aresetn            ),
  //       .debug_config  (debug_config_maxpool  ),
  //       .s_axis_tvalid (lrelu_m_axis_tvalid   ),
  //       .s_axis_tready (lrelu_m_axis_tready   ),
  //       .s_axis_tdata  (lrelu_m_axis_tdata    ), // cgu
  //       .s_axis_tuser  (lrelu_m_axis_tuser    ),
  //       .m_axis_tvalid (max_m_axis_tvalid ),
  //       .m_axis_tready (max_m_axis_tready ),
  //       .m_axis_tdata  (max_m_axis_tdata  ), //cgu
  //       .m_axis_tkeep  (max_m_axis_tkeep  ),
  //       .m_axis_tlast  (max_m_axis_tlast  )
  //     );
  //     axis_dw_max_1 DW_MAX_1 (
  //       .aclk           (hf_aclk            ),           
  //       .aresetn        (hf_aresetn         ),        
  //       .s_axis_tvalid  (max_m_axis_tvalid  ),  
  //       .s_axis_tready  (max_m_axis_tready  ),  
  //       .s_axis_tdata   (max_m_axis_tdata   ),   
  //       .s_axis_tkeep   (max_m_axis_tkeep   ),   
  //       .s_axis_tlast   (max_m_axis_tlast   ),   
  //       .m_axis_tvalid  (max_dw1_m_axis_tvalid ),  
  //       .m_axis_tready  (max_dw1_m_axis_tready ),  
  //       .m_axis_tdata   (max_dw1_m_axis_tdata  ),   
  //       .m_axis_tkeep   (max_dw1_m_axis_tkeep  ),   
  //       .m_axis_tlast   (max_dw1_m_axis_tlast  )    
  //     );
  //     axis_dw_max_2 DW_MAX_2 (
  //       .aclk           (hf_aclk               ),           
  //       .aresetn        (hf_aresetn            ),        
  //       .s_axis_tvalid  (max_dw1_m_axis_tvalid ),  
  //       .s_axis_tready  (max_dw1_m_axis_tready ),  
  //       .s_axis_tdata   (max_dw1_m_axis_tdata  ),   
  //       .s_axis_tkeep   (max_dw1_m_axis_tkeep  ),   
  //       .s_axis_tlast   (max_dw1_m_axis_tlast  ),   
  //       .m_axis_tready  (max_dw2_m_axis_tready ),  
  //       .m_axis_tvalid  (max_dw2_m_axis_tvalid ),  
  //       .m_axis_tlast   (max_dw2_m_axis_tlast  ),    
  //       .m_axis_tdata   (max_dw2_m_axis_tdata  ),   
  //       .m_axis_tkeep   (max_dw2_m_axis_tkeep  )   
  //     );
  //     axis_clk_maxpool CLK_MAXPOOL (
  //       .s_axis_aresetn (hf_aresetn ),  
  //       .s_axis_aclk    (hf_aclk    ),    
  //       .s_axis_tready  (max_dw2_m_axis_tready),
  //       .s_axis_tvalid  (max_dw2_m_axis_tvalid),
  //       .s_axis_tlast   (max_dw2_m_axis_tlast ),  
  //       .s_axis_tdata   (max_dw2_m_axis_tdata ),  
  //       .s_axis_tkeep   (max_dw2_m_axis_tkeep ),  

  //       .m_axis_aclk    (aclk      ),    
  //       .m_axis_aresetn (aresetn   ),  
  //       .m_axis_tready  (max_dw2_lf_m_axis_tready),
  //       .m_axis_tvalid  (max_dw2_lf_m_axis_tvalid),
  //       .m_axis_tlast   (max_dw2_lf_m_axis_tlast ),
  //       .m_axis_tdata   (max_dw2_lf_m_axis_tdata ),
  //       .m_axis_tkeep   (max_dw2_lf_m_axis_tkeep )   
  //     );
  //   end
  // end
  endgenerate
endmodule