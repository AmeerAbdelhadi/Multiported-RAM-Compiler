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
//                smpram_tb.v: switched multiported-RAM testbench                 //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   //
////////////////////////////////////////////////////////////////////////////////////


`include "utils.vh"
`include "fmpram.cfg.vh"

module fmpram_tb;

  // design parameters
  localparam MD   = `MD; // memory depth
  localparam DW   = `DW; // data width
  localparam nW   = `nW;  // total write ports number
  localparam nR   = `nR;  // total read ports number
  localparam nP   = `nP;  // number of switchable and fixed read/write port pairs
  localparam CYCC = `CYCC; // simulation cycles count
  localparam BYP  = `BYP; // set data-dependency and allowance
                           // bypassing type: NON, WAW, RAW, RDW
                           // WAW: Allow Write-After-Write
                           // RAW: new data for Read-after-Write
                           // RDW: new data for Read-During-Write
  localparam INI  = (`INI=="RND")? // initialization: CLR for zeros, or .hex/.bin file name;
                    "randram.hex": // "RND" option for simulation only; pass randram.hex;
                    `INI         ; //  a hex file with random values
  localparam VERB = `VERB; // verbose logging (1:yes; 0:no)

  // bypassing indicators
  localparam WDW  = 0                         ; // allow Write-During-Write (WDW)
  localparam WAW  =  BYP!="NON"               ; // allow Write-After-Write (WAW)
  localparam RAW  = (BYP=="RAW")||(BYP=="RDW"); // provide recently written data when Read-After-Write (RAW)
  localparam RDW  =  BYP=="RDW"               ; // provide recently written data when Read-During-Write (RDW)

  // local parameters
  localparam AW      = `log2(MD)  ; // address size
  localparam CYCT    = 10         ; // cycle      time
  localparam RSTT    = 5.2*CYCT   ; // reset      time
  localparam TERFAIL = 0          ; // terminate if fail?
  localparam TIMEOUT = 2*CYCT*CYCC; // simulation time

  reg              clk = 1'b0               ; // global clock
  reg              rst = 1'b1               ; // global reset
  reg  [   nP-1:0] wrRd                     ; // switch write/read (read is active low)
  reg  [   nW-1:0] wEn                      ; // write enable for each writing port
  reg  [nR*DW-1:0] compMask                 ; // compare mask
  reg  [AW*nW-1:0] wAddr_pck                ; // write addresses - packed from nW write ports
  reg  [AW   -1:0] wAddr_upk        [nW-1:0]; // write addresses - unpacked 2D array 
  reg  [AW*nR-1:0] rAddr_pck                ; // read  addresses - packed from nR  read  ports
  reg  [AW   -1:0] rAddr_upk        [nR-1:0]; // read  addresses - unpacked 2D array 
  reg  [DW*nW-1:0] wData_pck                ; // write data - packed from nW read ports
  reg  [DW   -1:0] wData_upk        [nW-1:0]; // write data - unpacked 2D array 
  wire [DW*nR-1:0] rData_pck_reg            ; // read  data - packed from nR read ports
  reg  [DW   -1:0] rData_upk_reg    [nR-1:0]; // read  data - unpacked 2D array 
  wire [DW*nR-1:0] rData_pck_xor            ; // read  data - packed from nR read ports
  reg  [DW   -1:0] rData_upk_xor    [nR-1:0]; // read  data - unpacked 2D array
  wire [DW*nR-1:0] rData_pck_lvtreg         ; // read  data - packed from nR read ports
  reg  [DW   -1:0] rData_upk_lvtreg [nR-1:0]; // read  data - unpacked 2D array 
  wire [DW*nR-1:0] rData_pck_lvtbin         ; // read  data - packed from nR read ports
  reg  [DW   -1:0] rData_upk_lvtbin [nR-1:0]; // read  data - unpacked 2D array 
  wire [DW*nR-1:0] rData_pck_lvt1ht         ; // read  data - packed from nR read ports
  reg  [DW   -1:0] rData_upk_lvt1ht [nR-1:0]; // read  data - unpacked 2D array 

  integer i,j,k; // general indeces

  // generates random ram hex/mif initializing files
  task genInitFiles;
    input [31  :0] DEPTH  ; // memory depth
    input [31  :0] WIDTH  ; // memoty width
    input [255 :0] INITVAL; // initial vlaue (if not random)
    input          RAND   ; // random value?
    input [1:8*20] FILEN  ; // memory initializing file name
    reg   [255 :0] ramdata;
    integer addr,hex_fd,mif_fd;
    begin
      // open hex/mif file descriptors
      hex_fd = $fopen({FILEN,".hex"},"w");
      mif_fd = $fopen({FILEN,".mif"},"w");
      // write mif header
      $fwrite(mif_fd,"WIDTH         = %0d;\n",WIDTH);
      $fwrite(mif_fd,"DEPTH         = %0d;\n",DEPTH);
      $fwrite(mif_fd,"ADDRESS_RADIX = HEX;\n"      );
      $fwrite(mif_fd,"DATA_RADIX    = HEX;\n\n"    );
      $fwrite(mif_fd,"CONTENT BEGIN\n"             );
      // write random memory lines
      for(addr=0;addr<DEPTH;addr=addr+1) begin
        if (RAND) begin
          `GETRAND(ramdata,WIDTH); 
        end else ramdata = INITVAL;
        $fwrite(hex_fd,"%0h\n",ramdata);
        $fwrite(mif_fd,"  %0h :  %0h;\n",addr,ramdata);
      end
      // write mif tail
      $fwrite(mif_fd,"END;\n");
      // close hex/mif file descriptors
      $fclose(hex_fd);
      $fclose(mif_fd);
    end
  endtask

  integer rep_fd, ferr;
  initial begin
    // write header
    rep_fd = $fopen("sim.res","r"); // try to open report file for read
    $ferror(rep_fd,ferr);       // detect error
    $fclose(rep_fd);
    rep_fd = $fopen("sim.res","a+"); // open report file for append
    if (ferr) begin     // if file is new (can't open for read); write header
      $fwrite(rep_fd,"           Flexible-Ports Multiported RAM Architectural Parameters                  Simulation Results  \n");
      $fwrite(rep_fd,"==============================================================================    ======================\n");
      $fwrite(rep_fd,"Memory   Data    Dot Seperated Write-Read Pairs   Initi-   Bypass   Simulation    XOR-  Reg-  Bin   1hot\n");
      $fwrite(rep_fd,"Depth    Width   1st pair:fixed;others:switched   alize    Type     Cycles        data  LVT   ILVT  ILVT\n");
      $fwrite(rep_fd,"==============================================================================    ======================\n");
    end

    $write("Simulating multi-ported RAM:\n");
    $write("Total write ports: %0d\n"  , nW);
    $write("Total read  ports: %0d\n"  , nR);
    $write("total port  pairs: %0d\n"  , nP);
    $write("Data width       : %0d\n"  , DW);
    $write("RAM depth        : %0d\n"  , MD);
    $write("Address width    : %0d\n\n", AW);
    // generate random ram hex/mif initializing file
    if (`INI=="RND") genInitFiles(MD,DW   ,0,1,"randram");
    // finish simulation
    #(TIMEOUT) begin 
      $write("*** Simulation terminated due to timeout\n");
      $finish;
    end
  end

  // generate clock and reset
  always  #(CYCT/2) clk = ~clk; // toggle clock
  initial #(RSTT  ) rst = 1'b0; // lower reset

  // pack/unpack data and addresses
  `ARRINIT;
  always @* begin
    `ARR2D1D(nR,AW,rAddr_upk       ,rAddr_pck       );
    `ARR2D1D(nW,AW,wAddr_upk       ,wAddr_pck       );
    `ARR1D2D(nW,DW,wData_pck       ,wData_upk       );
    `ARR1D2D(nR,DW,rData_pck_reg   ,rData_upk_reg   );
    `ARR1D2D(nR,DW,rData_pck_xor   ,rData_upk_xor   );
    `ARR1D2D(nR,DW,rData_pck_lvtreg,rData_upk_lvtreg);
    `ARR1D2D(nR,DW,rData_pck_lvtbin,rData_upk_lvtbin);
    `ARR1D2D(nR,DW,rData_pck_lvt1ht,rData_upk_lvt1ht);
end

  // register write addresses
  reg  [AW-1:0] wAddr_r_upk [nW-1:0]; // previous (registerd) write addresses - unpacked 2D array 
  always @(posedge clk)
    //wAddr_r_pck <= wAddr_pck;
    for (i=0;i<nW;i=i+1) wAddr_r_upk[i] <= wAddr_upk[i];

  // register read addresses
  reg  [AW-1:0] rAddr_r_upk [nR-1:0]; // previous (registerd) write addresses - unpacked 2D array 
  always @(posedge clk)
    //wAddr_r_pck <= wAddr_pck;
    for (i=0;i<nR;i=i+1) rAddr_r_upk[i] <= rAddr_upk[i];

  // generate random write data and random write/read addresses; on falling edge
  reg wdw_addr; // indicates same write addresses on same cycle (Write-During-Write)
  reg waw_addr; // indicates same write addresses on next cycle (Write-After-Write)
  reg rdw_addr; // indicates same read/write addresses on same cycle (Read-During-Write)
  reg raw_addr; // indicates same read address on next cycle (Read-After-Write)
  always @(negedge clk) begin
    // generate random write addresses; different that current and previous write addresses
    for (i=0;i<nW;i=i+1) begin
      wdw_addr = 1; waw_addr = 1;
      while (wdw_addr || waw_addr) begin
        `GETRAND(wAddr_upk[i],AW);
        wdw_addr = 0; waw_addr = 0;
        if (!WDW) for (j=0;j<i ;j=j+1) wdw_addr = wdw_addr || (wAddr_upk[i] == wAddr_upk[j]  );
        if (!WAW) for (j=0;j<nW;j=j+1) waw_addr = waw_addr || (wAddr_upk[i] == wAddr_r_upk[j]);
      end
    end
    // generate random read addresses; different that current and previous write addresses
    for (i=0;i<nR;i=i+1) begin
      rdw_addr = 1; raw_addr = 1;
      while (rdw_addr || raw_addr) begin
        `GETRAND(rAddr_upk[i],AW);
        rdw_addr = 0; raw_addr = 0;
        if (!RDW) for (j=0;j<nW;j=j+1) rdw_addr = rdw_addr || (rAddr_upk[i] == wAddr_upk[j]  );
        if (!RAW) for (j=0;j<nW;j=j+1) raw_addr = raw_addr || (rAddr_upk[i] == wAddr_r_upk[j]);
      end
    end
    // generate random write data and write enables
    `GETRAND(wData_pck,DW*nW);
    `GETRAND(wrRd     ,nP   ); wrRd[0]=1'b1;

    // create wEn; enable port with active wrRd only
    k=0;
    for (i=0;i<nP;i=i+1) begin
      for (j=0;j<`nWP(i);j=j+1) begin
        wEn[k]=wrRd[i];
        k=k+1;
      end
    end
    if (rst) wEn={nW{1'b0}}      ; // if reset, disable all writes

    // create compare mask, read ports associated with inactive write ports (low wrRd) are compared
    k=0;
    for (i=0;i<nP;i=i+1) begin
      for (j=0;j<`nRP(i);j=j+1) begin
        compMask[k*DW +: DW]={DW{((i==0)?1'b1:(!wrRd[i]))}};
        k=k+1;
      end
    end


  end

  integer cycc=1; // cycles count
  integer cycp=0; // cycles percentage
  integer errc=0; // errors count
  integer fail  ;
  integer pass_xor_cur    ; // xor multiported-ram passed in current cycle
  integer pass_lvt_reg_cur; // lvt_reg multiported-ram passed in current cycle
  integer pass_lvt_bin_cur; // lvt_bin multiported-ram passed in current cycle
  integer pass_lvt_1ht_cur; // lvt_1ht multiported-ram passed in current cycle
  integer pass_xor     = 1; // xor multiported-ram passed
  integer pass_lvt_reg = 1; // lvt_reg multiported-ram passed
  integer pass_lvt_bin = 1; // lvt_bin multiported-ram passed
  integer pass_lvt_1ht = 1; // lvt_qht multiported-ram passed

  always @(negedge clk)
    if (!rst) begin
      #(CYCT/10) // a little after falling edge
      if (VERB) begin // write input data
        $write("%-7d:\t",cycc);
        $write("BeforeRise: ");
        $write("write/read=" ); `ARRPRN(nP,wrRd     ); $write("; " );
        $write("compMask=%h",compMask); $write("; " );
        $write("wEn="        ); `ARRPRN(nW,wEn      ); $write("; " );
        $write("wAddr="      ); `ARRPRN(nW,wAddr_upk); $write("; " );
        $write("wData="      ); `ARRPRN(nW,wData_upk); $write("; " );
        $write("rAddr="      ); `ARRPRN(nR,rAddr_upk); $write(" - ");
      end
      #(CYCT/2) // a little after rising edge
      // compare results
      pass_xor_cur     = ( (rData_pck_reg & compMask) === (rData_pck_xor    & compMask));
      pass_lvt_reg_cur = ( (rData_pck_reg & compMask) === (rData_pck_lvtreg & compMask));
      pass_lvt_bin_cur = ( (rData_pck_reg & compMask) === (rData_pck_lvtbin & compMask));
      pass_lvt_1ht_cur = ( (rData_pck_reg & compMask) === (rData_pck_lvt1ht & compMask));
      pass_xor     = pass_xor     && pass_xor_cur    ;
      pass_lvt_reg = pass_lvt_reg && pass_lvt_reg_cur;
      pass_lvt_bin = pass_lvt_bin && pass_lvt_bin_cur;
      pass_lvt_1ht = pass_lvt_1ht && pass_lvt_1ht_cur;
      fail = !(pass_xor && pass_lvt_reg && pass_lvt_bin && pass_lvt_1ht);
      if (VERB) begin // write outputs
        $write("AfterRise: ");
        $write("rData_reg="    ); `ARRPRN(nR,rData_upk_reg   ); $write("; ");
        $write("rData_xor="    ); `ARRPRN(nR,rData_upk_xor   ); $write(":%s",pass_xor_cur     ? "pass" : "fail"); $write("; " );
        $write("rData_lvt_reg="); `ARRPRN(nR,rData_upk_lvtreg); $write(":%s",pass_lvt_reg_cur ? "pass" : "fail"); $write("; " );
        $write("rData_lvt_bin="); `ARRPRN(nR,rData_upk_lvtbin); $write(":%s",pass_lvt_bin_cur ? "pass" : "fail"); $write("; " );
        $write("rData_lvt_1ht="); `ARRPRN(nR,rData_upk_lvt1ht); $write(":%s",pass_lvt_1ht_cur ? "pass" : "fail"); $write(";\n");
      end else begin
        if ((100*cycc/CYCC)!=cycp) begin cycp=100*cycc/CYCC; $write("%-3d%%  passed\t(%-7d / %-7d) cycles\n",cycp,cycc,CYCC); end
      
end
      if (fail && TERFAIL) begin
        $write("*** Simulation terminated due to a mismatch\n");
        $finish;
      end
      if (cycc==CYCC) begin
        $write("*** Simulation terminated after %0d cycles. Simulation results:\n",CYCC);
        $write("XOR-based          = %s",pass_xor     ? "pass;\n" : "fail;\n");
        $write("Register-based LVT = %s",pass_lvt_reg ? "pass;\n" : "fail;\n");
        $write("Binary I-LVT       = %s",pass_lvt_bin ? "pass;\n" : "fail;\n");
        $write("Onehot I-LVT       = %s",pass_lvt_1ht ? "pass;\n" : "fail;\n");
        // Append report file
        $fwrite(rep_fd,"%-8d %-7d %-32s %-8s %-8s %-10d    %-4s  %-4s  %-4s  %-4s\n",MD,DW,`portTag,`INI,BYP,CYCC,pass_xor?"pass":"fail",pass_lvt_reg?"pass":"fail",pass_lvt_bin?"pass":"fail",pass_lvt_1ht?"pass":"fail");
        $fclose(rep_fd);
        $finish;
      end
      cycc=cycc+1;
    end

  // instantiate multiported register-based ram as reference for all other implementations
  fmpram       #( .MD   (MD              ),  // memory depth
                  .DW   (DW              ),  // data width
                  .nR   (nR              ),  // number of fixed (simple) read  ports
                  .nW   (nW              ),  // number of fixed (simple) write ports
                  .ARC  ("REG"           ),  // architecture: REG, XOR, LVTREG, LVTBIN, LVT1HT, AUTO
                  .BYP  (BYP             ),  // Bypassing type: NON, WAW, RAW, RDW
                  .INI  (INI             ))  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
  mpram_reg_ref ( .clk  (clk             ),  // clock
                  .wEn  (wEn             ),  // write enable    - packed from nW write ports - in : [          nW-1:0]
                  .wAddr(wAddr_pck       ),  // write addresses - packed from nW write ports - in : [`log2(MD)*nW-1:0]
                  .wData(wData_pck       ),  // write data      - packed from nW write ports - in : [      DW *nW-1:0]
                  .rAddr(rAddr_pck       ),  // read  addresses - packed from nR read  ports - in : [`log2(MD)*nR-1:0]
                  .rData(rData_pck_reg   )); // read  data      - packed from nR read  ports - out: [      DW *nR-1:0]
  // instantiate XOR-based multiported-RAM
  fmpram       #( .MD   (MD              ),  // memory depth
                  .DW   (DW              ),  // data width
                  .nR   (nR              ),  // number of fixed (simple) read  ports
                  .nW   (nW              ),  // number of fixed (simple) write ports
                  .ARC  ("XOR"           ),  // architecture: REG, XOR, LVTREG, LVTBIN, LVT1HT, AUTO
                  .BYP  (BYP             ),  // Bypassing type: NON, WAW, RAW, RDW
                  .INI  (INI             ))  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
  fmpram_xor    ( .clk  (clk             ),  // clock
                  .wEn  (wEn             ),  // write enable    - packed from nW write ports - in : [          nW-1:0]
                  .wAddr(wAddr_pck       ),  // write addresses - packed from nW write ports - in : [`log2(MD)*nW-1:0]
                  .wData(wData_pck       ),  // write data      - packed from nW write ports - in : [      DW *nW-1:0]
                  .rAddr(rAddr_pck       ),  // read  addresses - packed from nR read  ports - in : [`log2(MD)*nR-1:0]
                  .rData(rData_pck_xor   )); // read  data      - packed from nR read  ports - out: [      DW *nR-1:0]
  // instantiate a multiported-RAM with binary-coded register-based LVT
  fmpram       #( .MD   (MD              ),  // memory depth
                  .DW   (DW              ),  // data width
                  .nW   (nW              ),  // total write ports
                  .nR   (nR              ),  // total read pairs
                  .nP   (nP              ),  // total write-read pairs (LVT only)
                  .ARC  ("LVTREG"        ),  // multi-port RAM implementation type
                  .BYP  (BYP             ),  // Bypassing type: NON, WAW, RAW, RDW
                  .INI  (INI             ))  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
  fmpram_lvtreg ( .clk  (clk             ),  // clock
                  .wrRd (wrRd            ),  // switch read/write (write is active low)
                  .wEn  (wEn             ),  // write enable    - packed from nW write ports - in : [          nW-1:0]
                  .wAddr(wAddr_pck       ),  // write addresses - packed from nW write ports - in : [`log2(MD)*nW-1:0]
                  .wData(wData_pck       ),  // write data      - packed from nW write ports - in : [      DW *nW-1:0]
                  .rAddr(rAddr_pck       ),  // read  addresses - packed from nR read  ports - in : [`log2(MD)*nR-1:0]
                  .rData(rData_pck_lvtreg)); // read  data      - packed from nR read  ports - out: [      DW *nR-1:0]
  // instantiate a multiported-RAM with binary-coded SRAM LVT
  fmpram       #( .MD   (MD              ),  // memory depth
                  .DW   (DW              ),  // data width
                  .nW   (nW              ),  // total write ports
                  .nR   (nR              ),  // total read pairs
                  .nP   (nP              ),  // total write-read pairs (LVT only)
                  .ARC  ("LVTBIN"        ),  // multi-port RAM implementation type
                  .BYP  (BYP             ),  // Bypassing type: NON, WAW, RAW, RDW
                  .INI  (INI             ))  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
  fmpram_lvtbin ( .clk  (clk             ),  // clock
                  .wrRd (wrRd            ),  // switch read/write (write is active low)
                  .wEn  (wEn             ),  // write enable    - packed from nW write ports - in : [          nW-1:0]
                  .wAddr(wAddr_pck       ),  // write addresses - packed from nW write ports - in : [`log2(MD)*nW-1:0]
                  .wData(wData_pck       ),  // write data      - packed from nW write ports - in : [      DW *nW-1:0]
                  .rAddr(rAddr_pck       ),  // read  addresses - packed from nR read  ports - in : [`log2(MD)*nR-1:0]
                  .rData(rData_pck_lvtbin)); // read  data      - packed from nR read  ports - out: [      DW *nR-1:0]
  // instantiate a multiported-RAM with onehot-coded SRAM LVT
  fmpram       #( .MD   (MD              ),  // memory depth
                  .DW   (DW              ),  // data width
                  .nW   (nW              ),  // total write ports
                  .nR   (nR              ),  // total read pairs
                  .nP   (nP              ),  // total write-read pairs (LVT only)
                  .ARC  ("LVT1HT"        ),  // multi-port RAM implementation type
                  .BYP  (BYP             ),  // Bypassing type: NON, WAW, RAW, RDW
                  .INI  (INI             ))  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
  fmpram_lvt1ht ( .clk  (clk             ),  // clock
                  .wrRd (wrRd            ),  // switch read/write (write is active low)
                  .wEn  (wEn             ),  // write enable    - packed from nW write ports - in : [          nW-1:0]
                  .wAddr(wAddr_pck       ),  // write addresses - packed from nW write ports - in : [`log2(MD)*nW-1:0]
                  .wData(wData_pck       ),  // write data      - packed from nW write ports - in : [      DW *nW-1:0]
                  .rAddr(rAddr_pck       ),  // read  addresses - packed from nR read  ports - in : [`log2(MD)*nR-1:0]
                  .rData(rData_pck_lvt1ht)); // read  data      - packed from nR read  ports - out: [      DW *nR-1:0]

endmodule
