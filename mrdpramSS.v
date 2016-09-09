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
// mrram.v: Multiread-RAM based on bank replication using generic dual-ported RAM //
//          with optional single-stage or two-stage bypass/ for normal mode ports //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module mrdpramSS
#( parameter MD  = 16, // memory depth
   parameter DW  = 32, // data width
   parameter nR  = 3 , // number of reading ports
   parameter BYP = 1 , // bypass? 0:none; 1: single-stage; 2:two-stages
   parameter INI = ""  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
)( input                         clk  , // clock
   input                         wEn  , // write enable  (1 port)
   input      [`log2(MD)   -1:0] wAddr, // write address (1 port)
   input      [DW          -1:0] wData, // write data    (1 port)
   input      [`log2(MD)*nR-1:0] rAddr, // read  addresses - packed from nR read  ports
   output reg [DW       *nR-1:0] rData  // read  data      - packed from nR read ports
);

  // local parameters
  localparam AW = `log2(MD); // address width

  // unpacked read addresses/data
  reg  [AW-1:0] rAddr_upk [nR-1:0]; // read addresses - unpacked 2D array 
  wire [DW-1:0] rData_upk [nR-1:0]; // read data      - unpacked 2D array 

  // unpack read addresses; pack read data
  `ARRINIT;
  always @* begin
    `ARR1D2D(nR,AW,rAddr    ,rAddr_upk);
    `ARR2D1D(nR,DW,rData_upk,rData    );
  end

  // generate and instantiate generic RAM blocks
  genvar rpi;
  generate
    for (rpi=0 ; rpi<nR ; rpi=rpi+1) begin: RPORTrpi
      // generic dual-ported ram instantiation
      dpram_bbs   #( .MD    (MD            ), // memory depth
                     .DW    (DW            ), // data width
                     .BYP   (BYP           ), // bypass? 0: none; 1: single-stage; 2:two-stages
                     .INI   (INI           )  // initialization file, optional
      ) dpram_bbsi ( .clk   (clk           ), // global clock  - in
                     .wEn0  (1'b0          ), // write enable  - in
                     .wEn1  (wEn           ), // write enable  - in
                     .addr0 (rAddr_upk[rpi]), // write address - in : [`log2(MD)-1:0]
                     .addr1 (wAddr         ), // write address - in : [`log2(MD)-1:0]
                     .wData0({DW{1'b0}}    ), // write data    - in : [DW       -1:0] / constant
                     .wData1(wData         ), // write data    - in : [DW       -1:0]
                     .rData0(rData_upk[rpi]), // read  data    - out: [DW       -1:0]
                     .rData1(              )  // read  data    - out: [DW       -1:0]
      );
    end
  endgenerate

endmodule
