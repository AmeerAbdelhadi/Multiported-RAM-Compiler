////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2015, University of British Columbia (UBC); All rights reserved. //
//                                                                                //
// Redistribution  and  use  in  source   and  binary  forms,   with  or  without //
// modification,  are permitted  provided that  the following conditions are met: //
//   * Redistributions   of  source   code  must  retain   the   above  copyright //
//     notice,  this   list   of   conditions   and   the  following  disclaimer. //
//   * Redistributions  in  binary  form  must  reproduce  the  above   copyright //
//     notice, this  list  of  conditions  and the  following  disclaimer in  the //
//     documentation and/or  other  materials  provided  with  the  distribution. //
//   * Neither the name of the University of British Columbia (UBC) nor the names //
//     of   its   contributors  may  be  used  to  endorse  or   promote products //
//     derived from  this  software without  specific  prior  written permission. //
//                                                                                //
// THIS  SOFTWARE IS  PROVIDED  BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" //
// AND  ANY EXPRESS  OR IMPLIED WARRANTIES,  INCLUDING,  BUT NOT LIMITED TO,  THE //
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE //
// DISCLAIMED.  IN NO  EVENT SHALL University of British Columbia (UBC) BE LIABLE //
// FOR ANY DIRECT,  INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY, OR CONSEQUENTIAL //
// DAMAGES  (INCLUDING,  BUT NOT LIMITED TO,  PROCUREMENT OF  SUBSTITUTE GOODS OR //
// SERVICES;  LOSS OF USE,  DATA,  OR PROFITS;  OR BUSINESS INTERRUPTION) HOWEVER //
// CAUSED AND ON ANY THEORY OF LIABILITY,  WHETHER IN CONTRACT, STRICT LIABILITY, //
// OR TORT  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE //
// OF  THIS SOFTWARE,  EVEN  IF  ADVISED  OF  THE  POSSIBILITY  OF  SUCH  DAMAGE. //
////////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////////
// smpram.v: Flexible multiported-RAM: register-based, XOR-based, register-based  //
//           LVT, SRAM-based binary-coded and one-hot-coded I-LVT                 //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   SRAM-based Multi-ported RAM with Flexible Ports; The University of BC 2015   //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

// include config file for synthesis mode
`ifndef SIM
`include "fmpram.cfg.vh"
`endif

module fmpram #(
  parameter MD  = `MD , // memory depth
  parameter DW  = `DW , // data width
  parameter nW  = `nW , // total write ports
  parameter nR  = `nR , // total read pairs
  parameter nP  = `nP , // total write-read pairs (LVT only)
  parameter ARC = `ARC, // architecture: REG, XOR, LVTREG, LVTBIN, LVT1HT, AUTO
  parameter BYP = `BYP, // Bypassing type: NON, WAW, RAW, RDW
                        // WAW: Allow Write-After-Write (need to bypass feedback ram)
                        // RAW: new data for Read-after-Write (need to bypass output ram)
                        // RDW: new data for Read-During-Write
  parameter INI = "NON"    // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
) (
  input                     clk  ,  // global clock
  input  [          nP-1:0] wrRd , // write/read(inv) - packed for nP port pairs; (LVT only) (bit 0 is unused)
  input  [          nW-1:0] wEn  , // write enables   - packed for nW writes
  input  [`log2(MD)*nW-1:0] wAddr, // write addresses - packed for nW writes
  input  [      DW *nW-1:0] wData, // write data      - packed for nW writes
  input  [`log2(MD)*nR-1:0] rAddr, // read  addresses - packed for nR reads
  output [      DW *nR-1:0] rData  // read  data      - packed for nR reads
);

// Auto calculation of best method when ARCH="AUTO" is selected.
localparam l2nW     = `log2(nW)     ; // log2 the number of total write ports
localparam nBitsXOR = DW*(nW-1)     ; // number of required RAM bits / XOR-based
localparam nBitsBIN = l2nW*(nW+nR-1); // number of required RAM bits / Binart ILVT
localparam nBits1HT = (nW-1)*(nR+1) ; // number of required RAM bits / Onehot ILVT

// choosing auto (best) Architecture
localparam AUTARC = (MD<=1024                                       ) ? "REG"    : // use registers for very shallow memories
                  ( (MD<=2048                                       ) ? "LVTREG" : // use reg-based LVT for deeper memories
                  ( ((nP==1)&(nBitsXOR<nBits1HT)&(nBitsXOR<nBitsBIN)) ? "XOR"    : // use XOR-based RAM if it consumes less bits and all ports are fixed
                  ( (nBits1HT<=nBitsBIN                             ) ? "LVT1HT" : "LVTBIN" ))); // otherwise choose I-LVT, either binary or one-hot

// if ARC is not one of known types (REG, XOR, LVTREG, LVTBIN, LVT1HT) choose auto (best) ARC
localparam iARC = ((ARC!="REG")&&(ARC!="XOR")&&(ARC!="LVTREG")&&(ARC!="LVTBIN")&&(ARC!="LVT1HT")) ? AUTARC : ARC;

// Bypassing indicators
localparam WAW  =  BYP!="NON"               ; // allow Write-After-Write (WAW)
localparam RAW  = (BYP=="RAW")||(BYP=="RDW"); // provide recently written data when Read-After-Write (RAW)
localparam RDW  =  BYP=="RDW"               ; // provide recently written data when Read-During-Write (RDW)


// generate and instantiate RAM with specific implementation
generate
  if (iARC=="REG"   ) begin
    // instantiate multiported register-based RAM
    mpram_reg   #( .MD   (MD   ),  // memory depth
                   .DW   (DW   ),  // data width
                   .nR   (nR   ),  // number of fixed (simple) read  ports
                   .nW   (nW   ),  // number of fixed (simple) write ports
                   .RDW  (RDW  ),  // Bypassing type: NON, WAW, RAW, RDW
                   .INI  (INI  ))  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
    mpram_reg_i  ( .clk  (clk  ),  // clock
                   .wEn  (wEn  ),  // write enable    - packed from nW write ports - in : [          nW-1:0]
                   .wAddr(wAddr),  // write addresses - packed from nW write ports - in : [`log2(MD)*nW-1:0]
                   .wData(wData),  // write data      - packed from nW write ports - in : [DW       *nW-1:0]
                   .rAddr(rAddr),  // read  addresses - packed from nR read  ports - in : [`log2(MD)*nR-1:0]
                   .rData(rData)); // read  data      - packed from nR read  ports - out: [DW       *nR-1:0]
  end
  else if (iARC=="XOR"   ) begin
    // instantiate XOR-based multiported RAM
    mpram_xor   #( .MD   (MD   ),  // memory depth
                   .DW   (DW   ),  // data width
                   .nR   (nR   ),  // number of fixed (simple) read  ports
                   .nW   (nW   ),  // number of fixed (simple) write ports
                   .WAW  (WAW  ),  // allow Write-After-Write (need to bypass feedback ram)
                   .RAW  (RAW  ),  // new data for Read-after-Write (need to bypass output ram)
                   .RDW  (RDW  ),  // new data for Read-During-Write
                   .INI  (INI  ))  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
    mpram_xor_i  ( .clk  (clk  ),  // clock
                   .wEn  (wEn  ),  // write enable    - packed from nW write ports - in : [         nWP-1:0]
                   .wAddr(wAddr),  // write addresses - packed from nW write ports - in : [`log2(MD)*nW-1:0]
                   .wData(wData),  // write data      - packed from nW write ports - in : [DW       *nW-1:0]
                   .rAddr(rAddr),  // read  addresses - packed from nR read  ports - in : [`log2(MD)*nR-1:0]
                   .rData(rData)); // read  data      - packed from nR read  ports - out: [DW       *nR-1:0]
  end
  else begin
    // instantiate an LVT-based multiported RAM
    fmpram_lvt  #( .MD   (MD   ),  // memory depth
                   .DW   (DW   ),  // data width
                   .LVT  (iARC ),  // multi-port RAM implementation type
                   .WAW  (WAW  ),  // allow Write-After-Write (need to bypass feedback ram)
                   .RAW  (RAW  ),  // new data for Read-after-Write (need to bypass output ram)
                   .RDW  (RDW  ),  // new data for Read-During-Write
                   .INI  (INI  ))  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
    fmpram_lvt_i ( .clk  (clk  ),  // clock
                   .wrRd (wrRd ),  // switch read/write (write is active low)
                   .wEn  (wEn  ),  // write enable    - packed from nW write ports - in : [          nW-1:0]
                   .wAddr(wAddr),  // write addresses - packed from nW write ports - in : [`log2(MD)*nW-1:0]
                   .wData(wData),  // write data      - packed from nW write ports - in : [DW       *nW-1:0]
                   .rAddr(rAddr),  // read  addresses - packed from nR read  ports - in : [`log2(MD)*nR-1:0]
                   .rData(rData)); // read  data      - packed from nR read  ports - out: [DW       *nR-1:0]
  end
endgenerate

endmodule

