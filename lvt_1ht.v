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
//                 lvt_1ht.v: Onehot-coded LVT (Live-Value-Table)                 //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   //
////////////////////////////////////////////////////////////////////////////////////

`include "utils.vh"

module lvt_1ht
#( parameter MD  = 16, // memory depth
   parameter nR  = 1 , // number of reading ports
   parameter nW  = 3 , // number of writing ports
   parameter WAW = 1 , // allow Write-After-Write (need to bypass feedback ram)
   parameter RAW = 1 , // new data for Read-after-Write (need to bypass output ram)
   parameter RDW = 0 , // new data for Read-During-Write
   parameter INI = ""  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
)( input                    clk  , // clock
   input [          nW-1:0] wEn  , // write enable for each writing port
   input [`log2(MD)*nW-1:0] wAddr, // write addresses    - packed from nW write ports
   input [`log2(MD)*nR-1:0] rAddr, // read  addresses    - packed from nR  read  ports
   output reg [nW  *nR-1:0] rBank  // read bank selector - packed from nR read ports
);

  localparam AW = `log2(MD); // address width
  localparam LW = nW - 1   ; // required memory width

  // Register write addresses, data and enables
  reg [AW*nW-1:0] wAddr_r; // registered write addresses - packed from nW write ports
  reg [   nW-1:0] wEn_r  ; // registered write enable for each writing port
  always @(posedge clk) begin
    wAddr_r <= wAddr;
    wEn_r   <= wEn  ;
  end

  // unpacked/pack addresses and data
  reg  [AW   -1:0] wAddr2D    [nW-1:0]        ; // write addresses            / 2D
  reg  [AW   -1:0] wAddr2D_r  [nW-1:0]        ; // registered write addresses / 2D
  wire [LW*nR-1:0] rDataOut2D [nW-1:0]        ; // read data out              / 2D
  reg  [LW   -1:0] rDataOut3D [nW-1:0][nR-1:0]; // read data out              / 3D
  reg  [AW*LW-1:0] rAddrFB2D  [nW-1:0]        ; // read address fb            / 2D
  reg  [AW   -1:0] rAddrFB3D  [nW-1:0][LW-1:0]; // read address fb            / 3D
  wire [LW*LW-1:0] rDataFB2D  [nW-1:0]        ; // read data fb               / 2D
  reg  [LW   -1:0] rDataFB3D  [nW-1:0][LW-1:0]; // read data fb               / 3D
  reg  [LW   -1:0] wDataFB2D  [nW-1:0]        ; // write data                 / 2D
  reg  [LW   -1:0] InvData2D  [nW-1:0]        ; // write data                 / 2D
  reg  [nW   -1:0] rBank2D    [nR-1:0]        ; // read bank selector         / 2D
  `ARRINIT;
  always @* begin
    `ARR1D2D(nW, AW,     wAddr     , wAddr2D   );
    `ARR1D2D(nW, AW,     wAddr_r   , wAddr2D_r );
    `ARR2D1D(nR, nW,     rBank2D   , rBank     );
    `ARR2D3D(nW, nR, LW, rDataOut2D, rDataOut3D);
    `ARR3D2D(nW, LW, AW, rAddrFB3D , rAddrFB2D );
    `ARR2D3D(nW, LW, LW, rDataFB2D , rDataFB3D );
  end

  // generate and instantiate mulriread BRAMs
  genvar wpi;
  generate
    for (wpi=0 ; wpi<nW ; wpi=wpi+1) begin: RPORTwpi
      // feedback multiread ram instantiation
      mrdpramSS   #( .MD   (MD             ),  // memory depth
                     .DW   (LW             ),  // data width
                     .nR   (nW-1           ),  // number of reading ports
                     .BYP  (WAW||RDW||RAW  ),  // bypass? 0:none; 1:single-stage; 2:two-stages
                     .INI  (INI            ))  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
      mrdpramSSfdb ( .clk  (clk            ),  // clock                                        - in
                     .wEn  (wEn_r[wpi]     ),  // write enable  (1 port)                       - in
                     .wAddr(wAddr2D_r[wpi] ),  // write address (1 port)                       - in : [`log2(MD)    -1:0]
                     .wData(wDataFB2D[wpi] ),  // write data (1 port)                          - in : [LW           -1:0]
                     .rAddr(rAddrFB2D[wpi] ),  // read  addresses - packed from nR read ports - in : [`log2(MD)*nR-1:0]
                     .rData(rDataFB2D[wpi] )); // read  data      - packed from nR read ports - out: [LW       *nR-1:0]
      // output multiread ram instantiation
      mrdpramSS   #( .MD   (MD             ),  // memory depth
                     .DW   (LW             ),  // data width
                     .nR   (nR             ),  // number of reading ports
                     .BYP  (RDW ? 2 : RAW  ),  // bypass? 0:none; 1:single-stage; 2:two-stages
                     .INI  (INI            ))  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
      mrdpramSSout ( .clk  (clk            ),  // clock                                        - in
                     .wEn  (wEn_r[wpi]     ),  // write enable  (1 port)                       - in
                     .wAddr(wAddr2D_r[wpi] ),  // write address (1 port)                       - in : [`log2(MD)    -1:0]
                     .wData(wDataFB2D[wpi] ),  // write data (1 port)                          - in : [LW           -1:0]
                     .rAddr(rAddr          ),  // read  addresses - packed from nR read ports - in : [`log2(MD)*nR-1:0]
                     .rData(rDataOut2D[wpi])); // read  data      - packed from nR read ports - out: [LW       *nR-1:0]

    end
  endgenerate

  // combinatorial logic for output and feedback functions
  integer wp; // write port counter
  integer wf; // write feedback counter
  integer rf; // read  feedback counter
  integer rp; // read port counter
  integer lv; // lvt bit counter
  integer fi; // feedback bit index
  always @* begin
    // generate inversion vector
    for(wp=0;wp<nW;wp=wp+1) InvData2D[wp] = (1<<wp)-1; // 2^wp-1
    // initialize output read bank
    for(rp=0;rp<nR;rp=rp+1)
      for(wp=0;wp<nW;wp=wp+1)
        rBank2D[rp][wp] = 1;
    // generate feedback functions
    for(wp=0;wp<nW;wp=wp+1) begin
      wf = 0;
      for(lv=0;lv<LW;lv=lv+1) begin
        wf=wf+(lv==wp);
        rf=wp-(wf<wp);
        fi=wp-(InvData2D[wp][lv]);
        rAddrFB3D[wp][lv] = wAddr2D[wf];
        wDataFB2D[wp][lv] = rDataFB3D[wf][rf][fi] ^ InvData2D[wp][lv];
        for(rp=0;rp<nR;rp=rp+1) rBank2D[rp][wp] = rBank2D[rp][wp] && (( rDataOut3D[wf][rp][fi] ^ InvData2D[wp][lv]) == rDataOut3D[wp][rp][lv]);
        wf=wf+1;
      end
    end
  end

endmodule

