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
//                      dpram.v: Generic dual-ported RAM                          //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module dpram
#( parameter MD = 16, // memory depth
   parameter DW = 32, // data width
   parameter INI = ""  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
)( input                  clk   , // global clock
   input                  wEn0  , // write enable for port 0
   input                  wEn1  , // write enable for port 1
   input  [`log2(MD)-1:0] addr0 , // address      for port 0
   input  [`log2(MD)-1:0] addr1 , // address      for port 1
   input  [DW       -1:0] wData0, // write data   for port 0
   input  [DW       -1:0] wData1, // write data   for port 1
   output reg [DW   -1:0] rData0, // read  data   for port 0
   output reg [DW   -1:0] rData1  // read  data   for port 1
);

// local parameters
localparam INIEXT = INI[23:0]; // extension of initializing file (if exists)

// initialize RAM, with zeros if CLR or file if INI.
integer i;
reg [DW-1:0] mem [0:MD-1]; // memory array
initial
  if (INI=="CLR") // if "CLR" initialize with zeros
    for (i=0; i<MD; i=i+1) mem[i] = {DW{1'b0}};
  else
    case (INIEXT) // check if file extension
       "hex": $readmemh(INI, mem); // if ".hex" use readmemh
       "bin": $readmemb(INI, mem); // if ".bin" use readmemb
    endcase

// PORT A
always @(posedge clk) begin
  // write/read; nonblocking statement to read old data
  if (wEn0) begin
    mem[addr0] <= wData0; // Change into blocking statement (=) to read new data
    rData0     <= wData0; // flow-through
  end else
    rData0 <= mem[addr0]; //Change into blocking statement (=) to read new data
end

// PORT B
always @(posedge clk) begin
  // write/read; nonblocking statement to read old data
  if (wEn1) begin
    mem[addr1] <= wData1; // Change into blocking statement (=) to read new data
    rData1     <= wData1; // flow-through
  end else
    rData1 <= mem[addr1]; //Change into blocking statement (=) to read new data
end

endmodule
