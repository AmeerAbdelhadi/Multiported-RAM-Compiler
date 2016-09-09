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
  input  [           0-1:0] wrRd , // write/read(inverted) - packed from 0-1 ports (bit 0 is unused)
  input  [           0-1:0] wEn  , // write enables   - packed from 0   ports
  input  [`log2(MD)* 0-1:0] wAddr, // write addresses - packed from 0  writes
  input  [DW       * 0-1:0] wData, // write data      - packed from  0  writes
  input  [`log2(MD)* 0-1:0] rAddr, // read  addresses - packed from 0  reads
  output [DW       * 0-1:0] rData  // read  data      - packed from 0   reads
);

  // local parameters
  localparam nW = 0                    ; // total number of write ports
  localparam nR = 0                    ; // total number of read  ports
  localparam nP = 0                    ; // total number of read/write pairs (fixed+switched groups)
  localparam AW = `log2(MD)            ; // Address width
  localparam LW = `log2(nW)            ; // LVT     width
  localparam SW = (LVT=="LVT1HT")?nW:LW; // data bank selector width 
  localparam INIEXT = INI[23:0]; // extension of initializing file (if exists)
  localparam isINI  = (INI   =="CLR" ) || // RAM is initialized if cleared,
                      (INIEXT=="hex") || // or initialized from .hex file,
                      (INIEXT=="bin")  ; // or initialized from .bin file


  // write enables and write/read control

  // write addresses and data

  // read addresses

  // read data

  // read outputs from all writes

  // read outputs from all writes / used for one-hot LVT

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

  generate
  if (LVT=="LVT1HT") begin
    // infer tri-state buffers
    // pack read output from all read ports
    assign rData = {};
  end
  else begin
    // read outputs from all writes, ordered by write port indices
    // read ports mux array
    assign rData = {

    };
    end
  endgenerate

endmodule
