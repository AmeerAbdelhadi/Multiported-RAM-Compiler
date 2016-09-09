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
//  dpram_bbs.v: Generic dual-ported RAM with optional 1-stage or 2-stage bypass  //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module dpram_bbs
#( parameter MD  = 16, // memory depth
   parameter DW  = 32, // data width
   parameter BYP = 1 , // bypass? 0:none; 1: single-stage; 2: two-stage
   parameter INI = ""  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
)( input                  clk   , // global clock
   input                  wEn0  , // write enable for port 0
   input                  wEn1  , // write enable for port 1
   input  [`log2(MD)-1:0] addr0 , // write addresses - packed from nWP write ports
   input  [`log2(MD)-1:0] addr1 , // write addresses - packed from nWP write ports
   input  [DW       -1:0] wData0, // write data      - packed from nRP read ports
   input  [DW       -1:0] wData1, // write data      - packed from nRP read ports
   output reg [DW   -1:0] rData0, // read  data      - packed from nRP read ports
   output reg [DW   -1:0] rData1  // read  data      - packed from nRP read ports
);

  wire [DW-1:0] rData0i; // read ram data (internal) / port A
  wire [DW-1:0] rData1i; // read ram data (internal) - port B
  dpram   #( .MD    (MD     ), // memory depth
             .DW    (DW     ), // data width
             .INI   (INI    )  // initializtion file, optional
  ) dprami ( .clk   (clk    ), // global clock
             .wEn0  (wEn0   ), // write enable  / port A - in
             .wEn1  (wEn1   ), // write enable  / port B - in
             .addr0 (addr0  ), // write address / port A - in [`log2(MD)-1:0]
             .addr1 (addr1  ), // write address / port B - in [`log2(MD)-1:0]
             .wData0(wData0 ), // write data    / port A - in [DW  -1:0]
             .wData1(wData1 ), // write data    / port B - in [DW  -1:0]
             .rData0(rData0i), // read  data    / port A - in [DW  -1:0]
             .rData1(rData1i)  // read  data    / port B - in [DW  -1:0]
  );

  // registers; will be removed if unused
  reg wEn0r;
  reg wEn1r;
  reg [`log2(MD)-1:0] addr0r;
  reg [`log2(MD)-1:0] addr1r;
  reg [DW-1:0] wData1r;
  reg [DW-1:0] wData0r;
  always @(posedge clk) begin
    wEn0r   <= wEn0  ;
    wEn1r   <= wEn1  ;
    addr0r  <= addr0 ;
    addr1r  <= addr1 ;
    wData0r <= wData0; // bypass register
    wData1r <= wData1; // bypass register
  end
  
  // bypass: single-staeg, two-stage (logic will be removed if unused)
  wire byp0s1,byp0s2,byp1s1,byp1s2;
  assign byp0s1 = (BYP >= 1) && wEn1r && !wEn0r && (addr1r == addr0r);
  assign byp0s2 = (BYP == 2) && wEn1  && !wEn0r && (addr1  == addr0r);
  assign byp1s1 = (BYP >= 1) && wEn0r && !wEn1r && (addr0r == addr1r);
  assign byp1s2 = (BYP == 2) && wEn0  && !wEn1r && (addr0  == addr1r);

  // output mux (mux or mux inputs will be removed if unused)
  always @*
    if (byp0s2)      rData0 = wData1 ;
    else if (byp0s1) rData0 = wData1r;
         else        rData0 = rData0i;

  always @*
    if (byp1s2)      rData1 = wData0 ;
    else if (byp1s1) rData1 = wData0r;
         else        rData1 = rData1i;

endmodule
