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
//              mpram_reg.v: generic register-based multiported-RAM.              //
//   Reading addresses are registered and old data will be read in case of RAW.   //
//   Implemented in FF's if the number of reading or writing ports exceeds one.   //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module mpram_reg
#( parameter MD  = 16, // memory depth
   parameter DW  = 32, // data width
   parameter nR  = 3 , // number of reading ports
   parameter nW  = 2 , // number of writing ports
   parameter RDW = 0 , // provide new data when Read-During-Write?
   parameter INI = ""  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
)( input                    clk  , // clock
   input [          nW-1:0] wEn  , // write enable for each writing port
   input [`log2(MD)*nW-1:0] wAddr, // write addresses - packed from nW write ports
   input [DW       *nW-1:0] wData, // write data      - packed from nR read ports
   input [`log2(MD)*nR-1:0] rAddr, // read  addresses - packed from nR  read  ports
   output reg [DW  *nR-1:0] rData  // read  data      - packed from nR read ports
);

// local parameters
localparam AW     = `log2(MD); // address width
localparam INIEXT = INI[23:0]; // extension of initializing file (if exists)

integer i;

// initialize RAM, with zeros if CLR or file if INI.
(* ramstyle = "logic" *) reg [DW-1:0] mem [0:MD-1]; // memory array; implemented with logic cells (registers)
initial
  if (INI=="CLR") // if "CLR" initialize with zeros
    for (i=0; i<MD; i=i+1) mem[i] = {DW{1'b0}};
  else
    case (INIEXT) // check if file extension
       "hex": $readmemh(INI, mem); // if ".hex" use readmemh
       "bin": $readmemb(INI, mem); // if ".bin" use readmemb
    endcase

always @(posedge clk) begin
  // write to nW ports; nonblocking statement to read old data
  for (i=1; i<=nW; i=i+1)
    if (wEn[i-1]) 
      if (RDW) mem[wAddr[i*AW-1 -: AW]]  = wData[i*DW-1 -: DW]; //     blocking statement (= ) to read new data
      else     mem[wAddr[i*AW-1 -: AW]] <= wData[i*DW-1 -: DW]; // non-blocking statement (<=) to read old data 
  // Read from nR ports; nonblocking statement to read old data
  for (i=1; i<=nR; i=i+1)
    if (RDW) rData[i*DW-1 -: DW]  = mem[rAddr[i*AW-1 -: AW]]; //    blocking statement (= ) to read new data
    else     rData[i*DW-1 -: DW] <= mem[rAddr[i*AW-1 -: AW]]; //non-blocking statement (<=) to read old data
end

endmodule
