////////////////////////////////////////////////////////////////////////////////////
// mpram_lvt.v: LVT-based Multiported-RAM for register-base and SRAM-based        //
//              one-hot/binary-coded I-LVT                                        //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module fmpram_lvt #(
  parameter MD  = 16   , // memory depth
  parameter DW  = 32   , // data width
  parameter LVT = ""   , // LVT architecture type: LVTREG, LVTBIN, LVT1HT
  parameter WAW = 1    , // allow Write-After-Write (need to bypass feedback ram)
  parameter RAW = 1    , // new data for Read-after-Write (need to bypass output ram)
  parameter RDW = 0    , // new data for Read-During-Write
  parameter INI = "NON"  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
) (
  input                     clk  ,  // global clock
  input  [           5-1:0] wrRd , // write/read(inverted) - packed from 5-1 ports (bit 0 is unused)
  input  [           8-1:0] wEn  , // write enables   - packed from 8   ports
  input  [`log2(MD)* 8-1:0] wAddr, // write addresses - packed from 8  writes
  input  [DW       * 8-1:0] wData, // write data      - packed from  8  writes
  input  [`log2(MD)*11-1:0] rAddr, // read  addresses - packed from 11  reads
  output [DW       *11-1:0] rData  // read  data      - packed from 11   reads
);

  // local parameters
  localparam nW = 8                    ; // total number of write ports
  localparam nR = 11                   ; // total number of read  ports
  localparam nP = 5                    ; // total number of read/write pairs (fixed+switched groups)
  localparam AW = `log2(MD)            ; // Address width
  localparam LW = `log2(nW)            ; // LVT     width
  localparam SW = (LVT=="LVT1HT")?nW:LW; // data bank selector width 
  localparam INIEXT = INI[23:0]; // extension of initializing file (if exists)
  localparam isINI  = (INI   =="CLR" ) || // RAM is initialized if cleared,
                      (INIEXT=="hex") || // or initialized from .hex file,
                      (INIEXT=="bin")  ; // or initialized from .bin file


  // write enables and write/read control
  wire wEn_0_0 =   wEn[0]           ;
  wire wEn_0_1 =   wEn[1]           ;
  wire wEn_1_0 =   wEn[2] && wrRd[1];
  wire wEn_2_0 =   wEn[3] && wrRd[2];
  wire wEn_2_1 =   wEn[4] && wrRd[2];
  wire wEn_3_0 =   wEn[5] && wrRd[3];
  wire wEn_3_1 =   wEn[6] && wrRd[3];
  wire wEn_4_0 =   wEn[7] && wrRd[4];

  // write addresses and data
  wire [AW-1:0] wAddr_0_0 = wAddr[0*AW +: AW];
  wire [DW-1:0] wData_0_0 = wData[0*DW +: DW];
  wire [AW-1:0] wAddr_0_1 = wAddr[1*AW +: AW];
  wire [DW-1:0] wData_0_1 = wData[1*DW +: DW];
  wire [AW-1:0] wAddr_1_0 = wAddr[2*AW +: AW];
  wire [DW-1:0] wData_1_0 = wData[2*DW +: DW];
  wire [AW-1:0] wAddr_2_0 = wAddr[3*AW +: AW];
  wire [DW-1:0] wData_2_0 = wData[3*DW +: DW];
  wire [AW-1:0] wAddr_2_1 = wAddr[4*AW +: AW];
  wire [DW-1:0] wData_2_1 = wData[4*DW +: DW];
  wire [AW-1:0] wAddr_3_0 = wAddr[5*AW +: AW];
  wire [DW-1:0] wData_3_0 = wData[5*DW +: DW];
  wire [AW-1:0] wAddr_3_1 = wAddr[6*AW +: AW];
  wire [DW-1:0] wData_3_1 = wData[6*DW +: DW];
  wire [AW-1:0] wAddr_4_0 = wAddr[7*AW +: AW];
  wire [DW-1:0] wData_4_0 = wData[7*DW +: DW];

  // read addresses
  wire [AW-1:0] rAddr_0_0 = rAddr[0*AW +: AW];
  wire [AW-1:0] rAddr_0_1 = rAddr[1*AW +: AW];
  wire [AW-1:0] rAddr_1_0 = rAddr[2*AW +: AW];
  wire [AW-1:0] rAddr_2_0 = rAddr[3*AW +: AW];
  wire [AW-1:0] rAddr_2_1 = rAddr[4*AW +: AW];
  wire [AW-1:0] rAddr_2_2 = rAddr[5*AW +: AW];
  wire [AW-1:0] rAddr_2_3 = rAddr[6*AW +: AW];
  wire [AW-1:0] rAddr_3_0 = rAddr[7*AW +: AW];
  wire [AW-1:0] rAddr_4_0 = rAddr[8*AW +: AW];
  wire [AW-1:0] rAddr_4_1 = rAddr[9*AW +: AW];
  wire [AW-1:0] rAddr_4_2 = rAddr[10*AW +: AW];

  // read data
  wire [DW-1:0] rData_r_0_0_w_0_0      ;
  wire [DW-1:0] rData_r_0_0_w_0_1      ;
  wire [DW-1:0] rData_r_0_0_w_1_0      ;
  wire [DW-1:0] rData_r_0_0_w_2_0      ;
  wire [DW-1:0] rData_r_0_0_w_2_1      ;
  wire [DW-1:0] rData_r_0_0_w_3_0      ;
  wire [DW-1:0] rData_r_0_0_w_3_1      ;
  wire [DW-1:0] rData_r_0_0_w_4_0      ;
  wire [DW-1:0] rData_r_0_1_w_0_0      ;
  wire [DW-1:0] rData_r_0_1_w_0_1      ;
  wire [DW-1:0] rData_r_0_1_w_1_0      ;
  wire [DW-1:0] rData_r_0_1_w_2_0      ;
  wire [DW-1:0] rData_r_0_1_w_2_1      ;
  wire [DW-1:0] rData_r_0_1_w_3_0      ;
  wire [DW-1:0] rData_r_0_1_w_3_1      ;
  wire [DW-1:0] rData_r_0_1_w_4_0      ;
  wire [DW-1:0] rData_r_1_0_w_0_0      ;
  wire [DW-1:0] rData_r_1_0_w_0_1      ;
  wire [DW-1:0] rData_r_1_0_w_1_0_w_2_0;
  wire [DW-1:0] rData_r_1_0_w_1_0_w_2_1;
  wire [DW-1:0] rData_r_1_0_w_1_0_w_3_0;
  wire [DW-1:0] rData_r_1_0_w_1_0_w_4_0;
  wire [DW-1:0] rData_r_1_0_w_3_1      ;
  wire [DW-1:0] rData_r_2_0_w_0_0      ;
  wire [DW-1:0] rData_r_2_0_w_0_1      ;
  wire [DW-1:0] rData_r_2_0_w_1_0      ;
  wire [DW-1:0] rData_r_2_0_w_2_0_w_3_0;
  wire [DW-1:0] rData_r_2_0_w_2_1_w_4_0;
  wire [DW-1:0] rData_r_2_0_w_3_1      ;
  wire [DW-1:0] rData_r_2_1_w_0_0      ;
  wire [DW-1:0] rData_r_2_1_w_0_1      ;
  wire [DW-1:0] rData_r_2_1_w_1_0      ;
  wire [DW-1:0] rData_r_2_1_w_2_0_w_4_0;
  wire [DW-1:0] rData_r_2_1_w_2_1_w_3_1;
  wire [DW-1:0] rData_r_2_1_w_3_0      ;
  wire [DW-1:0] rData_r_2_2_w_0_0      ;
  wire [DW-1:0] rData_r_2_2_w_0_1      ;
  wire [DW-1:0] rData_r_2_2_w_1_0_w_2_1;
  wire [DW-1:0] rData_r_2_2_w_2_0_w_4_0;
  wire [DW-1:0] rData_r_2_2_w_3_0      ;
  wire [DW-1:0] rData_r_2_2_w_3_1      ;
  wire [DW-1:0] rData_r_2_3_w_0_0      ;
  wire [DW-1:0] rData_r_2_3_w_0_1      ;
  wire [DW-1:0] rData_r_2_3_w_1_0_w_2_0;
  wire [DW-1:0] rData_r_2_3_w_2_1_w_4_0;
  wire [DW-1:0] rData_r_2_3_w_3_0      ;
  wire [DW-1:0] rData_r_2_3_w_3_1      ;
  wire [DW-1:0] rData_r_3_0_w_0_0      ;
  wire [DW-1:0] rData_r_3_0_w_0_1      ;
  wire [DW-1:0] rData_r_3_0_w_1_0_w_3_0;
  wire [DW-1:0] rData_r_3_0_w_2_0_w_3_0;
  wire [DW-1:0] rData_r_3_0_w_2_1_w_3_1;
  wire [DW-1:0] rData_r_3_0_w_3_0_w_4_0;
  wire [DW-1:0] rData_r_4_0_w_0_0      ;
  wire [DW-1:0] rData_r_4_0_w_0_1      ;
  wire [DW-1:0] rData_r_4_0_w_1_0      ;
  wire [DW-1:0] rData_r_4_0_w_2_0_w_4_0;
  wire [DW-1:0] rData_r_4_0_w_2_1_w_4_0;
  wire [DW-1:0] rData_r_4_0_w_3_0      ;
  wire [DW-1:0] rData_r_4_0_w_3_1      ;
  wire [DW-1:0] rData_r_4_1_w_0_0      ;
  wire [DW-1:0] rData_r_4_1_w_0_1      ;
  wire [DW-1:0] rData_r_4_1_w_1_0_w_4_0;
  wire [DW-1:0] rData_r_4_1_w_2_0      ;
  wire [DW-1:0] rData_r_4_1_w_2_1      ;
  wire [DW-1:0] rData_r_4_1_w_3_0      ;
  wire [DW-1:0] rData_r_4_1_w_3_1      ;
  wire [DW-1:0] rData_r_4_2_w_0_0      ;
  wire [DW-1:0] rData_r_4_2_w_0_1      ;
  wire [DW-1:0] rData_r_4_2_w_1_0      ;
  wire [DW-1:0] rData_r_4_2_w_2_0_w_4_0;
  wire [DW-1:0] rData_r_4_2_w_2_1_w_4_0;
  wire [DW-1:0] rData_r_4_2_w_3_0_w_4_0;
  wire [DW-1:0] rData_r_4_2_w_3_1      ;

  // read outputs from all writes
  wire [8*DW-1:0] rData_0_0;
  wire [8*DW-1:0] rData_0_1;
  wire [8*DW-1:0] rData_1_0;
  wire [8*DW-1:0] rData_2_0;
  wire [8*DW-1:0] rData_2_1;
  wire [8*DW-1:0] rData_2_2;
  wire [8*DW-1:0] rData_2_3;
  wire [8*DW-1:0] rData_3_0;
  wire [8*DW-1:0] rData_4_0;
  wire [8*DW-1:0] rData_4_1;
  wire [8*DW-1:0] rData_4_2;

  // read outputs from all writes / used for one-hot LVT
  wire [  DW-1:0] rData_0_0z;
  wire [  DW-1:0] rData_0_1z;
  wire [  DW-1:0] rData_1_0z;
  wire [  DW-1:0] rData_2_0z;
  wire [  DW-1:0] rData_2_1z;
  wire [  DW-1:0] rData_2_2z;
  wire [  DW-1:0] rData_2_3z;
  wire [  DW-1:0] rData_3_0z;
  wire [  DW-1:0] rData_4_0z;
  wire [  DW-1:0] rData_4_1z;
  wire [  DW-1:0] rData_4_2z;

  // read bank selectors
  wire [SW*nR-1:0] rBank           ; // read bank selector / 1D
  reg  [SW   -1:0] rBank2D [nR-1:0]; // read bank selector / 2D

  // unpack rBank into 2D array rBank2D
  `ARRINIT;
  always @* `ARR1D2D(nR,SW,rBank,rBank2D);

  // generate and instantiate LVT with specific implementation
  generate
    if (LVT=="LVTREG") begin
      // instantiate register-based LVT
      lvt_reg #(.MD(MD), .nR(nR), .nW(nW),                       .RDW(RDW), .INI(isINI?"CLR":"NON")) lvt_reg_i (.clk(clk), .wEn(wEn), .wAddr(wAddr), .rAddr(rAddr), .rBank(rBank));
    end
    else if (LVT=="LVTBIN") begin
      // instantiate binary BRAM-based LVT
      lvt_bin #(.MD(MD), .nR(nR), .nW(nW), .WAW(WAW), .RAW(RAW), .RDW(RDW), .INI(isINI?"CLR":"NON")) lvt_bin_i (.clk(clk), .wEn(wEn), .wAddr(wAddr), .rAddr(rAddr), .rBank(rBank));
    end
    else begin
      // instantiate one-hot BRAM-based LVT
      lvt_1ht #(.MD(MD), .nR(nR), .nW(nW), .WAW(WAW), .RAW(RAW), .RDW(RDW), .INI(isINI?"CLR":"NON")) lvt_1ht_i (.clk(clk), .wEn(wEn), .wAddr(wAddr), .rAddr(rAddr), .rBank(rBank));
    end
  endgenerate

  // dual-ported RAM instantiation
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI( INI )) dpram_000 (.clk(clk), .wEn0(wEn_0_0), .wEn1(1'b0   ), .addr0(                  wAddr_0_0), .addr1(                  rAddr_0_0), .wData0(wData_0_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_0_0_w_0_0      )); // 1W1Rf:W0,0-R0,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI( INI )) dpram_001 (.clk(clk), .wEn0(wEn_0_0), .wEn1(1'b0   ), .addr0(                  wAddr_0_0), .addr1(                  rAddr_0_1), .wData0(wData_0_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_0_1_w_0_0      )); // 1W1Rf:W0,0-R0,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI( INI )) dpram_002 (.clk(clk), .wEn0(wEn_0_0), .wEn1(1'b0   ), .addr0(                  wAddr_0_0), .addr1(                  rAddr_1_0), .wData0(wData_0_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_1_0_w_0_0      )); // 1W1Rf:W0,0-R1,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI( INI )) dpram_003 (.clk(clk), .wEn0(wEn_0_0), .wEn1(1'b0   ), .addr0(                  wAddr_0_0), .addr1(                  rAddr_2_0), .wData0(wData_0_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_2_0_w_0_0      )); // 1W1Rf:W0,0-R2,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI( INI )) dpram_004 (.clk(clk), .wEn0(wEn_0_0), .wEn1(1'b0   ), .addr0(                  wAddr_0_0), .addr1(                  rAddr_2_1), .wData0(wData_0_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_2_1_w_0_0      )); // 1W1Rf:W0,0-R2,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI( INI )) dpram_005 (.clk(clk), .wEn0(wEn_0_0), .wEn1(1'b0   ), .addr0(                  wAddr_0_0), .addr1(                  rAddr_2_2), .wData0(wData_0_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_2_2_w_0_0      )); // 1W1Rf:W0,0-R2,2
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI( INI )) dpram_006 (.clk(clk), .wEn0(wEn_0_0), .wEn1(1'b0   ), .addr0(                  wAddr_0_0), .addr1(                  rAddr_2_3), .wData0(wData_0_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_2_3_w_0_0      )); // 1W1Rf:W0,0-R2,3
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI( INI )) dpram_007 (.clk(clk), .wEn0(wEn_0_0), .wEn1(1'b0   ), .addr0(                  wAddr_0_0), .addr1(                  rAddr_3_0), .wData0(wData_0_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_3_0_w_0_0      )); // 1W1Rf:W0,0-R3,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI( INI )) dpram_008 (.clk(clk), .wEn0(wEn_0_0), .wEn1(1'b0   ), .addr0(                  wAddr_0_0), .addr1(                  rAddr_4_0), .wData0(wData_0_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_4_0_w_0_0      )); // 1W1Rf:W0,0-R4,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI( INI )) dpram_009 (.clk(clk), .wEn0(wEn_0_0), .wEn1(1'b0   ), .addr0(                  wAddr_0_0), .addr1(                  rAddr_4_1), .wData0(wData_0_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_4_1_w_0_0      )); // 1W1Rf:W0,0-R4,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI( INI )) dpram_010 (.clk(clk), .wEn0(wEn_0_0), .wEn1(1'b0   ), .addr0(                  wAddr_0_0), .addr1(                  rAddr_4_2), .wData0(wData_0_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_4_2_w_0_0      )); // 1W1Rf:W0,0-R4,2
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_011 (.clk(clk), .wEn0(wEn_0_1), .wEn1(1'b0   ), .addr0(                  wAddr_0_1), .addr1(                  rAddr_0_0), .wData0(wData_0_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_0_0_w_0_1      )); // 1W1Rf:W0,1-R0,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_012 (.clk(clk), .wEn0(wEn_0_1), .wEn1(1'b0   ), .addr0(                  wAddr_0_1), .addr1(                  rAddr_0_1), .wData0(wData_0_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_0_1_w_0_1      )); // 1W1Rf:W0,1-R0,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_013 (.clk(clk), .wEn0(wEn_0_1), .wEn1(1'b0   ), .addr0(                  wAddr_0_1), .addr1(                  rAddr_1_0), .wData0(wData_0_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_1_0_w_0_1      )); // 1W1Rf:W0,1-R1,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_014 (.clk(clk), .wEn0(wEn_0_1), .wEn1(1'b0   ), .addr0(                  wAddr_0_1), .addr1(                  rAddr_2_0), .wData0(wData_0_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_2_0_w_0_1      )); // 1W1Rf:W0,1-R2,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_015 (.clk(clk), .wEn0(wEn_0_1), .wEn1(1'b0   ), .addr0(                  wAddr_0_1), .addr1(                  rAddr_2_1), .wData0(wData_0_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_2_1_w_0_1      )); // 1W1Rf:W0,1-R2,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_016 (.clk(clk), .wEn0(wEn_0_1), .wEn1(1'b0   ), .addr0(                  wAddr_0_1), .addr1(                  rAddr_2_2), .wData0(wData_0_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_2_2_w_0_1      )); // 1W1Rf:W0,1-R2,2
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_017 (.clk(clk), .wEn0(wEn_0_1), .wEn1(1'b0   ), .addr0(                  wAddr_0_1), .addr1(                  rAddr_2_3), .wData0(wData_0_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_2_3_w_0_1      )); // 1W1Rf:W0,1-R2,3
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_018 (.clk(clk), .wEn0(wEn_0_1), .wEn1(1'b0   ), .addr0(                  wAddr_0_1), .addr1(                  rAddr_3_0), .wData0(wData_0_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_3_0_w_0_1      )); // 1W1Rf:W0,1-R3,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_019 (.clk(clk), .wEn0(wEn_0_1), .wEn1(1'b0   ), .addr0(                  wAddr_0_1), .addr1(                  rAddr_4_0), .wData0(wData_0_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_4_0_w_0_1      )); // 1W1Rf:W0,1-R4,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_020 (.clk(clk), .wEn0(wEn_0_1), .wEn1(1'b0   ), .addr0(                  wAddr_0_1), .addr1(                  rAddr_4_1), .wData0(wData_0_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_4_1_w_0_1      )); // 1W1Rf:W0,1-R4,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_021 (.clk(clk), .wEn0(wEn_0_1), .wEn1(1'b0   ), .addr0(                  wAddr_0_1), .addr1(                  rAddr_4_2), .wData0(wData_0_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_4_2_w_0_1      )); // 1W1Rf:W0,1-R4,2
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_022 (.clk(clk), .wEn0(wEn_1_0), .wEn1(1'b0   ), .addr0(                  wAddr_1_0), .addr1(                  rAddr_0_0), .wData0(wData_1_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_0_0_w_1_0      )); // 1W1Rf:W1,0-R0,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_023 (.clk(clk), .wEn0(wEn_1_0), .wEn1(1'b0   ), .addr0(                  wAddr_1_0), .addr1(                  rAddr_0_1), .wData0(wData_1_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_0_1_w_1_0      )); // 1W1Rf:W1,0-R0,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_024 (.clk(clk), .wEn0(wEn_1_0), .wEn1(1'b0   ), .addr0(                  wAddr_1_0), .addr1(                  rAddr_2_0), .wData0(wData_1_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_2_0_w_1_0      )); // 1W1Rf:W1,0-R2,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_025 (.clk(clk), .wEn0(wEn_1_0), .wEn1(1'b0   ), .addr0(                  wAddr_1_0), .addr1(                  rAddr_2_1), .wData0(wData_1_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_2_1_w_1_0      )); // 1W1Rf:W1,0-R2,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_026 (.clk(clk), .wEn0(wEn_1_0), .wEn1(1'b0   ), .addr0(                  wAddr_1_0), .addr1(                  rAddr_4_0), .wData0(wData_1_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_4_0_w_1_0      )); // 1W1Rf:W1,0-R4,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_027 (.clk(clk), .wEn0(wEn_1_0), .wEn1(1'b0   ), .addr0(                  wAddr_1_0), .addr1(                  rAddr_4_2), .wData0(wData_1_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_4_2_w_1_0      )); // 1W1Rf:W1,0-R4,2
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_028 (.clk(clk), .wEn0(wEn_2_0), .wEn1(1'b0   ), .addr0(                  wAddr_2_0), .addr1(                  rAddr_0_0), .wData0(wData_2_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_0_0_w_2_0      )); // 1W1Rf:W2,0-R0,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_029 (.clk(clk), .wEn0(wEn_2_0), .wEn1(1'b0   ), .addr0(                  wAddr_2_0), .addr1(                  rAddr_0_1), .wData0(wData_2_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_0_1_w_2_0      )); // 1W1Rf:W2,0-R0,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_030 (.clk(clk), .wEn0(wEn_2_0), .wEn1(1'b0   ), .addr0(                  wAddr_2_0), .addr1(                  rAddr_4_1), .wData0(wData_2_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_4_1_w_2_0      )); // 1W1Rf:W2,0-R4,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_031 (.clk(clk), .wEn0(wEn_2_1), .wEn1(1'b0   ), .addr0(                  wAddr_2_1), .addr1(                  rAddr_0_0), .wData0(wData_2_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_0_0_w_2_1      )); // 1W1Rf:W2,1-R0,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_032 (.clk(clk), .wEn0(wEn_2_1), .wEn1(1'b0   ), .addr0(                  wAddr_2_1), .addr1(                  rAddr_0_1), .wData0(wData_2_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_0_1_w_2_1      )); // 1W1Rf:W2,1-R0,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_033 (.clk(clk), .wEn0(wEn_2_1), .wEn1(1'b0   ), .addr0(                  wAddr_2_1), .addr1(                  rAddr_4_1), .wData0(wData_2_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_4_1_w_2_1      )); // 1W1Rf:W2,1-R4,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_034 (.clk(clk), .wEn0(wEn_3_0), .wEn1(1'b0   ), .addr0(                  wAddr_3_0), .addr1(                  rAddr_0_0), .wData0(wData_3_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_0_0_w_3_0      )); // 1W1Rf:W3,0-R0,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_035 (.clk(clk), .wEn0(wEn_3_0), .wEn1(1'b0   ), .addr0(                  wAddr_3_0), .addr1(                  rAddr_0_1), .wData0(wData_3_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_0_1_w_3_0      )); // 1W1Rf:W3,0-R0,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_036 (.clk(clk), .wEn0(wEn_3_0), .wEn1(1'b0   ), .addr0(                  wAddr_3_0), .addr1(                  rAddr_2_1), .wData0(wData_3_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_2_1_w_3_0      )); // 1W1Rf:W3,0-R2,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_037 (.clk(clk), .wEn0(wEn_3_0), .wEn1(1'b0   ), .addr0(                  wAddr_3_0), .addr1(                  rAddr_2_2), .wData0(wData_3_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_2_2_w_3_0      )); // 1W1Rf:W3,0-R2,2
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_038 (.clk(clk), .wEn0(wEn_3_0), .wEn1(1'b0   ), .addr0(                  wAddr_3_0), .addr1(                  rAddr_2_3), .wData0(wData_3_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_2_3_w_3_0      )); // 1W1Rf:W3,0-R2,3
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_039 (.clk(clk), .wEn0(wEn_3_0), .wEn1(1'b0   ), .addr0(                  wAddr_3_0), .addr1(                  rAddr_4_0), .wData0(wData_3_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_4_0_w_3_0      )); // 1W1Rf:W3,0-R4,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_040 (.clk(clk), .wEn0(wEn_3_0), .wEn1(1'b0   ), .addr0(                  wAddr_3_0), .addr1(                  rAddr_4_1), .wData0(wData_3_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_4_1_w_3_0      )); // 1W1Rf:W3,0-R4,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_041 (.clk(clk), .wEn0(wEn_3_1), .wEn1(1'b0   ), .addr0(                  wAddr_3_1), .addr1(                  rAddr_0_0), .wData0(wData_3_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_0_0_w_3_1      )); // 1W1Rf:W3,1-R0,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_042 (.clk(clk), .wEn0(wEn_3_1), .wEn1(1'b0   ), .addr0(                  wAddr_3_1), .addr1(                  rAddr_0_1), .wData0(wData_3_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_0_1_w_3_1      )); // 1W1Rf:W3,1-R0,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_043 (.clk(clk), .wEn0(wEn_3_1), .wEn1(1'b0   ), .addr0(                  wAddr_3_1), .addr1(                  rAddr_1_0), .wData0(wData_3_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_1_0_w_3_1      )); // 1W1Rf:W3,1-R1,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_044 (.clk(clk), .wEn0(wEn_3_1), .wEn1(1'b0   ), .addr0(                  wAddr_3_1), .addr1(                  rAddr_2_0), .wData0(wData_3_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_2_0_w_3_1      )); // 1W1Rf:W3,1-R2,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_045 (.clk(clk), .wEn0(wEn_3_1), .wEn1(1'b0   ), .addr0(                  wAddr_3_1), .addr1(                  rAddr_2_2), .wData0(wData_3_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_2_2_w_3_1      )); // 1W1Rf:W3,1-R2,2
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_046 (.clk(clk), .wEn0(wEn_3_1), .wEn1(1'b0   ), .addr0(                  wAddr_3_1), .addr1(                  rAddr_2_3), .wData0(wData_3_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_2_3_w_3_1      )); // 1W1Rf:W3,1-R2,3
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_047 (.clk(clk), .wEn0(wEn_3_1), .wEn1(1'b0   ), .addr0(                  wAddr_3_1), .addr1(                  rAddr_4_0), .wData0(wData_3_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_4_0_w_3_1      )); // 1W1Rf:W3,1-R4,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_048 (.clk(clk), .wEn0(wEn_3_1), .wEn1(1'b0   ), .addr0(                  wAddr_3_1), .addr1(                  rAddr_4_1), .wData0(wData_3_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_4_1_w_3_1      )); // 1W1Rf:W3,1-R4,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_049 (.clk(clk), .wEn0(wEn_3_1), .wEn1(1'b0   ), .addr0(                  wAddr_3_1), .addr1(                  rAddr_4_2), .wData0(wData_3_1), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_4_2_w_3_1      )); // 1W1Rf:W3,1-R4,2
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_050 (.clk(clk), .wEn0(wEn_4_0), .wEn1(1'b0   ), .addr0(                  wAddr_4_0), .addr1(                  rAddr_0_0), .wData0(wData_4_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_0_0_w_4_0      )); // 1W1Rf:W4,0-R0,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_051 (.clk(clk), .wEn0(wEn_4_0), .wEn1(1'b0   ), .addr0(                  wAddr_4_0), .addr1(                  rAddr_0_1), .wData0(wData_4_0), .wData1({DW{1'b0}}), .rData0(                       ), .rData1(rData_r_0_1_w_4_0      )); // 1W1Rf:W4,0-R0,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_052 (.clk(clk), .wEn0(wEn_1_0), .wEn1(wEn_2_0), .addr0(wEn_1_0?wAddr_1_0:rAddr_1_0), .addr1(wEn_2_0?wAddr_2_0:rAddr_2_3), .wData0(wData_1_0), .wData1(wData_2_0 ), .rData0(rData_r_1_0_w_1_0_w_2_0), .rData1(rData_r_2_3_w_1_0_w_2_0)); // 2W2Rf:W1,0-R1,0;W1,0-R2,3;W2,0-R1,0;W2,0-R2,3
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_053 (.clk(clk), .wEn0(wEn_1_0), .wEn1(wEn_2_1), .addr0(wEn_1_0?wAddr_1_0:rAddr_1_0), .addr1(wEn_2_1?wAddr_2_1:rAddr_2_2), .wData0(wData_1_0), .wData1(wData_2_1 ), .rData0(rData_r_1_0_w_1_0_w_2_1), .rData1(rData_r_2_2_w_1_0_w_2_1)); // 2W2Rf:W1,0-R1,0;W1,0-R2,2;W2,1-R1,0;W2,1-R2,2
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_054 (.clk(clk), .wEn0(wEn_1_0), .wEn1(wEn_3_0), .addr0(wEn_1_0?wAddr_1_0:rAddr_1_0), .addr1(wEn_3_0?wAddr_3_0:rAddr_3_0), .wData0(wData_1_0), .wData1(wData_3_0 ), .rData0(rData_r_1_0_w_1_0_w_3_0), .rData1(rData_r_3_0_w_1_0_w_3_0)); // 2W2Rf:W1,0-R1,0;W1,0-R3,0;W3,0-R1,0;W3,0-R3,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_055 (.clk(clk), .wEn0(wEn_1_0), .wEn1(wEn_4_0), .addr0(wEn_1_0?wAddr_1_0:rAddr_1_0), .addr1(wEn_4_0?wAddr_4_0:rAddr_4_1), .wData0(wData_1_0), .wData1(wData_4_0 ), .rData0(rData_r_1_0_w_1_0_w_4_0), .rData1(rData_r_4_1_w_1_0_w_4_0)); // 2W2Rf:W1,0-R1,0;W1,0-R4,1;W4,0-R1,0;W4,0-R4,1
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_056 (.clk(clk), .wEn0(wEn_2_0), .wEn1(wEn_3_0), .addr0(wEn_2_0?wAddr_2_0:rAddr_2_0), .addr1(wEn_3_0?wAddr_3_0:rAddr_3_0), .wData0(wData_2_0), .wData1(wData_3_0 ), .rData0(rData_r_2_0_w_2_0_w_3_0), .rData1(rData_r_3_0_w_2_0_w_3_0)); // 2W2Rf:W2,0-R2,0;W2,0-R3,0;W3,0-R2,0;W3,0-R3,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_057 (.clk(clk), .wEn0(wEn_2_0), .wEn1(wEn_4_0), .addr0(wEn_2_0?wAddr_2_0:rAddr_2_1), .addr1(wEn_4_0?wAddr_4_0:rAddr_4_2), .wData0(wData_2_0), .wData1(wData_4_0 ), .rData0(rData_r_2_1_w_2_0_w_4_0), .rData1(rData_r_4_2_w_2_0_w_4_0)); // 2W2Rf:W2,0-R2,1;W2,0-R4,2;W4,0-R2,1;W4,0-R4,2
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_058 (.clk(clk), .wEn0(wEn_2_0), .wEn1(wEn_4_0), .addr0(wEn_2_0?wAddr_2_0:rAddr_2_2), .addr1(wEn_4_0?wAddr_4_0:rAddr_4_0), .wData0(wData_2_0), .wData1(wData_4_0 ), .rData0(rData_r_2_2_w_2_0_w_4_0), .rData1(rData_r_4_0_w_2_0_w_4_0)); // 2W2Rf:W2,0-R2,2;W2,0-R4,0;W4,0-R2,2;W4,0-R4,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_059 (.clk(clk), .wEn0(wEn_2_1), .wEn1(wEn_4_0), .addr0(wEn_2_1?wAddr_2_1:rAddr_2_0), .addr1(wEn_4_0?wAddr_4_0:rAddr_4_2), .wData0(wData_2_1), .wData1(wData_4_0 ), .rData0(rData_r_2_0_w_2_1_w_4_0), .rData1(rData_r_4_2_w_2_1_w_4_0)); // 2W2Rf:W2,1-R2,0;W2,1-R4,2;W4,0-R2,0;W4,0-R4,2
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_060 (.clk(clk), .wEn0(wEn_2_1), .wEn1(wEn_3_1), .addr0(wEn_2_1?wAddr_2_1:rAddr_2_1), .addr1(wEn_3_1?wAddr_3_1:rAddr_3_0), .wData0(wData_2_1), .wData1(wData_3_1 ), .rData0(rData_r_2_1_w_2_1_w_3_1), .rData1(rData_r_3_0_w_2_1_w_3_1)); // 2W2Rf:W2,1-R2,1;W2,1-R3,0;W3,1-R2,1;W3,1-R3,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_061 (.clk(clk), .wEn0(wEn_2_1), .wEn1(wEn_4_0), .addr0(wEn_2_1?wAddr_2_1:rAddr_2_3), .addr1(wEn_4_0?wAddr_4_0:rAddr_4_0), .wData0(wData_2_1), .wData1(wData_4_0 ), .rData0(rData_r_2_3_w_2_1_w_4_0), .rData1(rData_r_4_0_w_2_1_w_4_0)); // 2W2Rf:W2,1-R2,3;W2,1-R4,0;W4,0-R2,3;W4,0-R4,0
  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI("NON")) dpram_062 (.clk(clk), .wEn0(wEn_3_0), .wEn1(wEn_4_0), .addr0(wEn_3_0?wAddr_3_0:rAddr_3_0), .addr1(wEn_4_0?wAddr_4_0:rAddr_4_2), .wData0(wData_3_0), .wData1(wData_4_0 ), .rData0(rData_r_3_0_w_3_0_w_4_0), .rData1(rData_r_4_2_w_3_0_w_4_0)); // 2W2Rf:W3,0-R3,0;W3,0-R4,2;W4,0-R3,0;W4,0-R4,2

  generate
  if (LVT=="LVT1HT") begin
    // infer tri-state buffers
    assign rData_0_0z = rBank2D[0][0] ? rData_r_0_0_w_0_0       : {DW{1'bz}};
    assign rData_0_0z = rBank2D[0][1] ? rData_r_0_0_w_0_1       : {DW{1'bz}};
    assign rData_0_0z = rBank2D[0][2] ? rData_r_0_0_w_1_0       : {DW{1'bz}};
    assign rData_0_0z = rBank2D[0][3] ? rData_r_0_0_w_2_0       : {DW{1'bz}};
    assign rData_0_0z = rBank2D[0][4] ? rData_r_0_0_w_2_1       : {DW{1'bz}};
    assign rData_0_0z = rBank2D[0][5] ? rData_r_0_0_w_3_0       : {DW{1'bz}};
    assign rData_0_0z = rBank2D[0][6] ? rData_r_0_0_w_3_1       : {DW{1'bz}};
    assign rData_0_0z = rBank2D[0][7] ? rData_r_0_0_w_4_0       : {DW{1'bz}};
    assign rData_0_1z = rBank2D[1][0] ? rData_r_0_1_w_0_0       : {DW{1'bz}};
    assign rData_0_1z = rBank2D[1][1] ? rData_r_0_1_w_0_1       : {DW{1'bz}};
    assign rData_0_1z = rBank2D[1][2] ? rData_r_0_1_w_1_0       : {DW{1'bz}};
    assign rData_0_1z = rBank2D[1][3] ? rData_r_0_1_w_2_0       : {DW{1'bz}};
    assign rData_0_1z = rBank2D[1][4] ? rData_r_0_1_w_2_1       : {DW{1'bz}};
    assign rData_0_1z = rBank2D[1][5] ? rData_r_0_1_w_3_0       : {DW{1'bz}};
    assign rData_0_1z = rBank2D[1][6] ? rData_r_0_1_w_3_1       : {DW{1'bz}};
    assign rData_0_1z = rBank2D[1][7] ? rData_r_0_1_w_4_0       : {DW{1'bz}};
    assign rData_1_0z = rBank2D[2][0] ? rData_r_1_0_w_0_0       : {DW{1'bz}};
    assign rData_1_0z = rBank2D[2][1] ? rData_r_1_0_w_0_1       : {DW{1'bz}};
    assign rData_1_0z = rBank2D[2][2] ? rData_r_1_0_w_1_0_w_2_0 : {DW{1'bz}};
    assign rData_1_0z = rBank2D[2][3] ? rData_r_1_0_w_1_0_w_2_0 : {DW{1'bz}};
    assign rData_1_0z = rBank2D[2][4] ? rData_r_1_0_w_1_0_w_2_1 : {DW{1'bz}};
    assign rData_1_0z = rBank2D[2][5] ? rData_r_1_0_w_1_0_w_3_0 : {DW{1'bz}};
    assign rData_1_0z = rBank2D[2][6] ? rData_r_1_0_w_3_1       : {DW{1'bz}};
    assign rData_1_0z = rBank2D[2][7] ? rData_r_1_0_w_1_0_w_4_0 : {DW{1'bz}};
    assign rData_2_0z = rBank2D[3][0] ? rData_r_2_0_w_0_0       : {DW{1'bz}};
    assign rData_2_0z = rBank2D[3][1] ? rData_r_2_0_w_0_1       : {DW{1'bz}};
    assign rData_2_0z = rBank2D[3][2] ? rData_r_2_0_w_1_0       : {DW{1'bz}};
    assign rData_2_0z = rBank2D[3][3] ? rData_r_2_0_w_2_0_w_3_0 : {DW{1'bz}};
    assign rData_2_0z = rBank2D[3][4] ? rData_r_2_0_w_2_1_w_4_0 : {DW{1'bz}};
    assign rData_2_0z = rBank2D[3][5] ? rData_r_2_0_w_2_0_w_3_0 : {DW{1'bz}};
    assign rData_2_0z = rBank2D[3][6] ? rData_r_2_0_w_3_1       : {DW{1'bz}};
    assign rData_2_0z = rBank2D[3][7] ? rData_r_2_0_w_2_1_w_4_0 : {DW{1'bz}};
    assign rData_2_1z = rBank2D[4][0] ? rData_r_2_1_w_0_0       : {DW{1'bz}};
    assign rData_2_1z = rBank2D[4][1] ? rData_r_2_1_w_0_1       : {DW{1'bz}};
    assign rData_2_1z = rBank2D[4][2] ? rData_r_2_1_w_1_0       : {DW{1'bz}};
    assign rData_2_1z = rBank2D[4][3] ? rData_r_2_1_w_2_0_w_4_0 : {DW{1'bz}};
    assign rData_2_1z = rBank2D[4][4] ? rData_r_2_1_w_2_1_w_3_1 : {DW{1'bz}};
    assign rData_2_1z = rBank2D[4][5] ? rData_r_2_1_w_3_0       : {DW{1'bz}};
    assign rData_2_1z = rBank2D[4][6] ? rData_r_2_1_w_2_1_w_3_1 : {DW{1'bz}};
    assign rData_2_1z = rBank2D[4][7] ? rData_r_2_1_w_2_0_w_4_0 : {DW{1'bz}};
    assign rData_2_2z = rBank2D[5][0] ? rData_r_2_2_w_0_0       : {DW{1'bz}};
    assign rData_2_2z = rBank2D[5][1] ? rData_r_2_2_w_0_1       : {DW{1'bz}};
    assign rData_2_2z = rBank2D[5][2] ? rData_r_2_2_w_1_0_w_2_1 : {DW{1'bz}};
    assign rData_2_2z = rBank2D[5][3] ? rData_r_2_2_w_2_0_w_4_0 : {DW{1'bz}};
    assign rData_2_2z = rBank2D[5][4] ? rData_r_2_2_w_1_0_w_2_1 : {DW{1'bz}};
    assign rData_2_2z = rBank2D[5][5] ? rData_r_2_2_w_3_0       : {DW{1'bz}};
    assign rData_2_2z = rBank2D[5][6] ? rData_r_2_2_w_3_1       : {DW{1'bz}};
    assign rData_2_2z = rBank2D[5][7] ? rData_r_2_2_w_2_0_w_4_0 : {DW{1'bz}};
    assign rData_2_3z = rBank2D[6][0] ? rData_r_2_3_w_0_0       : {DW{1'bz}};
    assign rData_2_3z = rBank2D[6][1] ? rData_r_2_3_w_0_1       : {DW{1'bz}};
    assign rData_2_3z = rBank2D[6][2] ? rData_r_2_3_w_1_0_w_2_0 : {DW{1'bz}};
    assign rData_2_3z = rBank2D[6][3] ? rData_r_2_3_w_1_0_w_2_0 : {DW{1'bz}};
    assign rData_2_3z = rBank2D[6][4] ? rData_r_2_3_w_2_1_w_4_0 : {DW{1'bz}};
    assign rData_2_3z = rBank2D[6][5] ? rData_r_2_3_w_3_0       : {DW{1'bz}};
    assign rData_2_3z = rBank2D[6][6] ? rData_r_2_3_w_3_1       : {DW{1'bz}};
    assign rData_2_3z = rBank2D[6][7] ? rData_r_2_3_w_2_1_w_4_0 : {DW{1'bz}};
    assign rData_3_0z = rBank2D[7][0] ? rData_r_3_0_w_0_0       : {DW{1'bz}};
    assign rData_3_0z = rBank2D[7][1] ? rData_r_3_0_w_0_1       : {DW{1'bz}};
    assign rData_3_0z = rBank2D[7][2] ? rData_r_3_0_w_1_0_w_3_0 : {DW{1'bz}};
    assign rData_3_0z = rBank2D[7][3] ? rData_r_3_0_w_2_0_w_3_0 : {DW{1'bz}};
    assign rData_3_0z = rBank2D[7][4] ? rData_r_3_0_w_2_1_w_3_1 : {DW{1'bz}};
    assign rData_3_0z = rBank2D[7][5] ? rData_r_3_0_w_1_0_w_3_0 : {DW{1'bz}};
    assign rData_3_0z = rBank2D[7][6] ? rData_r_3_0_w_2_1_w_3_1 : {DW{1'bz}};
    assign rData_3_0z = rBank2D[7][7] ? rData_r_3_0_w_3_0_w_4_0 : {DW{1'bz}};
    assign rData_4_0z = rBank2D[8][0] ? rData_r_4_0_w_0_0       : {DW{1'bz}};
    assign rData_4_0z = rBank2D[8][1] ? rData_r_4_0_w_0_1       : {DW{1'bz}};
    assign rData_4_0z = rBank2D[8][2] ? rData_r_4_0_w_1_0       : {DW{1'bz}};
    assign rData_4_0z = rBank2D[8][3] ? rData_r_4_0_w_2_0_w_4_0 : {DW{1'bz}};
    assign rData_4_0z = rBank2D[8][4] ? rData_r_4_0_w_2_1_w_4_0 : {DW{1'bz}};
    assign rData_4_0z = rBank2D[8][5] ? rData_r_4_0_w_3_0       : {DW{1'bz}};
    assign rData_4_0z = rBank2D[8][6] ? rData_r_4_0_w_3_1       : {DW{1'bz}};
    assign rData_4_0z = rBank2D[8][7] ? rData_r_4_0_w_2_0_w_4_0 : {DW{1'bz}};
    assign rData_4_1z = rBank2D[9][0] ? rData_r_4_1_w_0_0       : {DW{1'bz}};
    assign rData_4_1z = rBank2D[9][1] ? rData_r_4_1_w_0_1       : {DW{1'bz}};
    assign rData_4_1z = rBank2D[9][2] ? rData_r_4_1_w_1_0_w_4_0 : {DW{1'bz}};
    assign rData_4_1z = rBank2D[9][3] ? rData_r_4_1_w_2_0       : {DW{1'bz}};
    assign rData_4_1z = rBank2D[9][4] ? rData_r_4_1_w_2_1       : {DW{1'bz}};
    assign rData_4_1z = rBank2D[9][5] ? rData_r_4_1_w_3_0       : {DW{1'bz}};
    assign rData_4_1z = rBank2D[9][6] ? rData_r_4_1_w_3_1       : {DW{1'bz}};
    assign rData_4_1z = rBank2D[9][7] ? rData_r_4_1_w_1_0_w_4_0 : {DW{1'bz}};
    assign rData_4_2z = rBank2D[10][0] ? rData_r_4_2_w_0_0       : {DW{1'bz}};
    assign rData_4_2z = rBank2D[10][1] ? rData_r_4_2_w_0_1       : {DW{1'bz}};
    assign rData_4_2z = rBank2D[10][2] ? rData_r_4_2_w_1_0       : {DW{1'bz}};
    assign rData_4_2z = rBank2D[10][3] ? rData_r_4_2_w_2_0_w_4_0 : {DW{1'bz}};
    assign rData_4_2z = rBank2D[10][4] ? rData_r_4_2_w_2_1_w_4_0 : {DW{1'bz}};
    assign rData_4_2z = rBank2D[10][5] ? rData_r_4_2_w_3_0_w_4_0 : {DW{1'bz}};
    assign rData_4_2z = rBank2D[10][6] ? rData_r_4_2_w_3_1       : {DW{1'bz}};
    assign rData_4_2z = rBank2D[10][7] ? rData_r_4_2_w_2_0_w_4_0 : {DW{1'bz}};
    // pack read output from all read ports
    assign rData = {rData_4_2z,rData_4_1z,rData_4_0z,rData_3_0z,rData_2_3z,rData_2_2z,rData_2_1z,rData_2_0z,rData_1_0z,rData_0_1z,rData_0_0z};
  end
  else begin
    // read outputs from all writes, ordered by write port indices
    assign rData_0_0 = {rData_r_0_0_w_4_0       ,rData_r_0_0_w_3_1       ,rData_r_0_0_w_3_0       ,rData_r_0_0_w_2_1       ,rData_r_0_0_w_2_0       ,rData_r_0_0_w_1_0       ,rData_r_0_0_w_0_1       ,rData_r_0_0_w_0_0      };
    assign rData_0_1 = {rData_r_0_1_w_4_0       ,rData_r_0_1_w_3_1       ,rData_r_0_1_w_3_0       ,rData_r_0_1_w_2_1       ,rData_r_0_1_w_2_0       ,rData_r_0_1_w_1_0       ,rData_r_0_1_w_0_1       ,rData_r_0_1_w_0_0      };
    assign rData_1_0 = {rData_r_1_0_w_1_0_w_4_0 ,rData_r_1_0_w_3_1       ,rData_r_1_0_w_1_0_w_3_0 ,rData_r_1_0_w_1_0_w_2_1 ,rData_r_1_0_w_1_0_w_2_0 ,rData_r_1_0_w_1_0_w_2_0 ,rData_r_1_0_w_0_1       ,rData_r_1_0_w_0_0      };
    assign rData_2_0 = {rData_r_2_0_w_2_1_w_4_0 ,rData_r_2_0_w_3_1       ,rData_r_2_0_w_2_0_w_3_0 ,rData_r_2_0_w_2_1_w_4_0 ,rData_r_2_0_w_2_0_w_3_0 ,rData_r_2_0_w_1_0       ,rData_r_2_0_w_0_1       ,rData_r_2_0_w_0_0      };
    assign rData_2_1 = {rData_r_2_1_w_2_0_w_4_0 ,rData_r_2_1_w_2_1_w_3_1 ,rData_r_2_1_w_3_0       ,rData_r_2_1_w_2_1_w_3_1 ,rData_r_2_1_w_2_0_w_4_0 ,rData_r_2_1_w_1_0       ,rData_r_2_1_w_0_1       ,rData_r_2_1_w_0_0      };
    assign rData_2_2 = {rData_r_2_2_w_2_0_w_4_0 ,rData_r_2_2_w_3_1       ,rData_r_2_2_w_3_0       ,rData_r_2_2_w_1_0_w_2_1 ,rData_r_2_2_w_2_0_w_4_0 ,rData_r_2_2_w_1_0_w_2_1 ,rData_r_2_2_w_0_1       ,rData_r_2_2_w_0_0      };
    assign rData_2_3 = {rData_r_2_3_w_2_1_w_4_0 ,rData_r_2_3_w_3_1       ,rData_r_2_3_w_3_0       ,rData_r_2_3_w_2_1_w_4_0 ,rData_r_2_3_w_1_0_w_2_0 ,rData_r_2_3_w_1_0_w_2_0 ,rData_r_2_3_w_0_1       ,rData_r_2_3_w_0_0      };
    assign rData_3_0 = {rData_r_3_0_w_3_0_w_4_0 ,rData_r_3_0_w_2_1_w_3_1 ,rData_r_3_0_w_1_0_w_3_0 ,rData_r_3_0_w_2_1_w_3_1 ,rData_r_3_0_w_2_0_w_3_0 ,rData_r_3_0_w_1_0_w_3_0 ,rData_r_3_0_w_0_1       ,rData_r_3_0_w_0_0      };
    assign rData_4_0 = {rData_r_4_0_w_2_0_w_4_0 ,rData_r_4_0_w_3_1       ,rData_r_4_0_w_3_0       ,rData_r_4_0_w_2_1_w_4_0 ,rData_r_4_0_w_2_0_w_4_0 ,rData_r_4_0_w_1_0       ,rData_r_4_0_w_0_1       ,rData_r_4_0_w_0_0      };
    assign rData_4_1 = {rData_r_4_1_w_1_0_w_4_0 ,rData_r_4_1_w_3_1       ,rData_r_4_1_w_3_0       ,rData_r_4_1_w_2_1       ,rData_r_4_1_w_2_0       ,rData_r_4_1_w_1_0_w_4_0 ,rData_r_4_1_w_0_1       ,rData_r_4_1_w_0_0      };
    assign rData_4_2 = {rData_r_4_2_w_2_0_w_4_0 ,rData_r_4_2_w_3_1       ,rData_r_4_2_w_3_0_w_4_0 ,rData_r_4_2_w_2_1_w_4_0 ,rData_r_4_2_w_2_0_w_4_0 ,rData_r_4_2_w_1_0       ,rData_r_4_2_w_0_1       ,rData_r_4_2_w_0_0      };
    // read ports mux array
    assign rData = {
      rData_4_2[rBank[10*SW +: SW]*DW +: DW],
      rData_4_1[rBank[9*SW +: SW]*DW +: DW],
      rData_4_0[rBank[8*SW +: SW]*DW +: DW],
      rData_3_0[rBank[7*SW +: SW]*DW +: DW],
      rData_2_3[rBank[6*SW +: SW]*DW +: DW],
      rData_2_2[rBank[5*SW +: SW]*DW +: DW],
      rData_2_1[rBank[4*SW +: SW]*DW +: DW],
      rData_2_0[rBank[3*SW +: SW]*DW +: DW],
      rData_1_0[rBank[2*SW +: SW]*DW +: DW],
      rData_0_1[rBank[1*SW +: SW]*DW +: DW],
      rData_0_0[rBank[0*SW +: SW]*DW +: DW]
    };
    end
  endgenerate

endmodule
