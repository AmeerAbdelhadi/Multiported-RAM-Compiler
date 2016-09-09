////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2014, University of British Columbia (UBC); All rights reserved. //
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
//         lvt_reg.v:  Register-based binary-coded LVT (Live-Value-Table)         //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module lvt_reg
#( parameter MD  = 16, // memory depth
   parameter nR  = 2 , // number of reading ports
   parameter nW  = 2 , // number of writing ports
   parameter RDW = 0 , // new data for Read-During-Write
   parameter INI = ""  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
)( input                     clk  , // clock
   input  [          nW-1:0] wEn  , // write enable for each writing port
   input  [`log2(MD)*nW-1:0] wAddr, // write addresses    - packed from nW write ports
   input  [`log2(MD)*nR-1:0] rAddr, // read  addresses    - packed from nR read  ports
   output [`log2(nW)*nR-1:0] rBank  // read bank selector - packed from nR read  ports
);

  localparam AW = `log2(MD); // address width
  localparam LW = `log2(nW); // required memory width

  // Generate Bank ID's to write into LVT
  reg  [LW*nW-1:0] wData1D         ; 
  wire [LW   -1:0] wData2D [nW-1:0];
  genvar gi;
  generate
    for (gi=0;gi<nW;gi=gi+1) begin: GenerateID
      assign wData2D[gi]=gi;
    end
  endgenerate

  // pack ID's into 1D array
  `ARRINIT;
  always @* `ARR2D1D(nW,LW,wData2D,wData1D);

  mpram_reg  #( .MD   (MD     ),  // memory depth
                .DW   (LW     ),  // data width
                .nR   (nR     ),  // number of reading ports
                .nW   (nW     ),  // number of writing ports
                .RDW  (RDW    ),  // provide new data when Read-During-Write?
                .INI  (INI    ))  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
  mpram_reg_i ( .clk  (clk    ),  // clock                                        - in
                .wEn  (wEn    ),  // write enable for each writing port           - in : [   nW-1:0]
                .wAddr(wAddr  ),  // write addresses - packed from nW write ports - in : [AW*nW-1:0]
                .wData(wData1D),  // write data      - packed from nR read  ports - in : [LW*nW-1:0]
                .rAddr(rAddr  ),  // read  addresses - packed from nR read  ports - in : [AW*nR-1:0]
                .rData(rBank  )); // read  data      - packed from nR read  ports - out: [LW*nR-1:0]

endmodule
