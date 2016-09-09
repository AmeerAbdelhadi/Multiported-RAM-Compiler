#!/bin/bash

####################################################################################
## Copyright (c) 2014, University of British Columbia (UBC)  All rights reserved. ##
##                                                                                ##
## Redistribution  and  use  in  source   and  binary  forms,   with  or  without ##
## modification,  are permitted  provided that  the following conditions are met: ##
##   * Redistributions   of  source   code  must  retain   the   above  copyright ##
##     notice,  this   list   of   conditions   and   the  following  disclaimer. ##
##   * Redistributions  in  binary  form  must  reproduce  the  above   copyright ##
##     notice, this  list  of  conditions  and the  following  disclaimer in  the ##
##     documentation and/or  other  materials  provided  with  the  distribution. ##
##   * Neither the name of the University of British Columbia (UBC) nor the names ##
##     of   its   contributors  may  be  used  to  endorse  or   promote products ##
##     derived from  this  software without  specific  prior  written permission. ##
##                                                                                ##
## THIS  SOFTWARE IS  PROVIDED  BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" ##
## AND  ANY EXPRESS  OR IMPLIED WARRANTIES,  INCLUDING,  BUT NOT LIMITED TO,  THE ##
## IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE ##
## DISCLAIMED.  IN NO  EVENT SHALL University of British Columbia (UBC) BE LIABLE ##
## FOR ANY DIRECT,  INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY, OR CONSEQUENTIAL ##
## DAMAGES  (INCLUDING,  BUT NOT LIMITED TO,  PROCUREMENT OF  SUBSTITUTE GOODS OR ##
## SERVICES;  LOSS OF USE,  DATA,  OR PROFITS;  OR BUSINESS INTERRUPTION) HOWEVER ##
## CAUSED AND ON ANY THEORY OF LIABILITY,  WHETHER IN CONTRACT, STRICT LIABILITY, ##
## OR TORT  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE ##
## OF  THIS SOFTWARE,  EVEN  IF  ADVISED  OF  THE  POSSIBILITY  OF  SUCH  DAMAGE. ##
####################################################################################

####################################################################################
##                      Run-in-batch Synthesis Flow Manager                       ##
##                                                                                ##
##   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   ##
##   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   ##
####################################################################################

####################################################################################
## USAGE:                                                                         ##
##   ./syn <Depth List> <Width List> <#Write Ports List (Fixed-Switched)> \       ##
##         <#Read Ports List (Fixed-Switched)> <Bypass List> <Architecture List>  ##
##                                                                                ##
## - Use a comma delimited list.                                                  ##
##   - No spaces.                                                                 ##
##   - May be surrounded by any brackets (), [], {}, or <>.                       ##
## - RAM depth, data width, and simulation cycles are positive integers.          ##
## - Numbers of read and write ports are:                                         ##
##   - Pairs of "fixed-switched" port numbers delimited with hyphen "-", or,      ##
##   - Fixed port number only, if switched ports are not required.                ##
##   * numbers of read/write ports are integers.                                  ##
##   * #switched_read_ports  < =  #fixed_read_ports                               ##
## - Bypassing type is one of: NON, WAW, RAW, or RDW.                             ##
##   - NON: No bypassing logic                                                    ##
##   - WAW: Allow Write-After-Write                                               ##
##   - RAW: new data for Read-after-Write                                         ##
##   - RDW: new data for Read-During-Write                                        ##
## - "verbose" is an optional argument; use if verbosed logging is required       ##
## - Architecture is one of: REG, XOR, LVTREG, LVTBIN, or LVT1HT.                 ##
##   - REG   : Register-based multi-ported RAM                                    ##
##   - XOR   : XOR-based multi-ported RAM                                         ##
##   - LVTREG: Register-based LVT multi-ported RAM                                ##
##   - LVTBIN: Binary-coded I-LVT-based multi-ported RAM                          ##
##   - LVT1HT: Onehot-coded I-LVT-based multi-ported RAM                          ##
##                                                                                ##
## EXAMPLES:                                                                      ##
## ./syn 1024 32 1-2 2-2 NON XOR                                                  ##
##    Synthesis a XOR-based RAM with no bypassing, 1K lines RAM, 32 bits width,   ##
##    1 fixed / 2 switched write and 2 fixed / 2 switched read ports.             ##
## ./syn 512,1024 16,32 3,4 2,3 RAW,RDW LVTBIN,LVT1HT                             ##
##    Synthesis LVTBIN & LVT1HT RAM with new data RAW & RDW bypassing, 512 & 1024 ##
##    lines, 16 & 32 data width, 3 & 4 fixed write ports, 2 & 3 fixed read ports. ##
##                                                                                ##
## The following files and directories will be created after compilation:         ##
##   - syn.res : A list of results, each run in a separate line, including:       ##
##               frequency, resources usage, and runtime                          ##
##   - log/    : Altera's logs and reports                                        ##
####################################################################################


####################################################################################
##                                 Bash Functions                                 ##
####################################################################################

# echo colorful text if output is dumped to the terminal
function echor () { [ -t 1 ] && printf "\x1b[1;31m"; echo $1; [ -t 1 ] && printf "\x1b[0m"; }
function echog () { [ -t 1 ] && printf "\x1b[1;32m"; echo $1; [ -t 1 ] && printf "\x1b[0m"; }
function echob () { [ -t 1 ] && printf "\x1b[1;34m"; echo $1; [ -t 1 ] && printf "\x1b[0m"; }

# print error message
function reportExit () {
  echor "$1"
  echor "This is error message line 1"
  echor "This is error message line 2"
  exit 1
}

# remove and report all files and directories
# argumnets: file and directory names
function rmAll () {
local f;
for f in $@ ; do
  if [[ -d $f ]] ; then
    echo "--- removing directory '$f' and its contents recursively..."
    \rm -rf $f
  elif [[ -f $f ]] ; then
    echo "--- removing file '$f'..."
    \rm -rf $f
  fi
done
}

# repeat an input text several times
# arguments: text, times to repeat
function repeat () {
  local i
  for (( i=0 ; i<$2 ; i++ )) ; do
    printf "$1"
  done
}

# floating point division/Multiplication
# arguments: dividend/factor, divisor/factor, scale (number of digits decimal fractions)
function fdiv () { echo "scale=$3; $1/$2" | bc -l; }
function fmul () { echo "scale=$3; $1*$2" | bc -l; }

####################################################################################
##                                   Main Script                                  ##
####################################################################################

VCFGFN=fmpram.cfg.vh

# setup environment variables and Altera's CAD tools 
# add your own flow (after the last `else`) if necessary 
if [[ $(hostname -d) == "ece.ubc.ca" ]] ; then
  echo "Setup Altera CAD flow from The University of BC..."
  . ./altera.14.0.ubc.sh
else
  ## --> for other CAD environment, setup your flow here
  echor 'Error: Altera CAD flow is defined for UBC environment only.'
  echor '       Define your flow in ./sim.sh'
  echor '       Exiting...'
  exit 1
  ## <-- for other CAD environment, setup your flow here
fi

# require exactly 6 arguments
[[ $# == 5 ]] || reportExit 'Error: Exactly 5 arguments are required'

# convert each argument list into a bash list (remove commas, etc.)
MDLST=( $(echo $1 | tr ",()[]{}<>" " "))
DWLST=( $(echo $2 | tr ",()[]{}<>" " "))
BYPLST=($(echo $3 | tr ",()[]{}<>" " "))
PRTLST=($(echo $4 | tr ",()[]{}<>" " "))
ARCLST=($(echo $5 | tr ",()[]{}<>" " "))

# check arguments correctness (using regexp)
[[  ${MDLST[*]}    =~ ^([1-9][0-9]* *)+$                                 ]] || reportExit "Error (${MDLST[*]}): Memory depth list should be a list of possitive integer numbers"
[[  ${DWLST[*]}    =~ ^([1-9][0-9]* *)+$                                 ]] || reportExit "Error (${DWLST[*]}): Data width list should be a list of possitive integer numbers"
[[ "${BYPLST[*]} " =~ ^((NON|WAW|RAW|RDW) +)+$                           ]] || reportExit "Error (${BYPLST[*]}): Bypass should be a list of NON, WAW, RAW, or RDW"
[[ "${PRTLST[*]} " =~ ^(([0-9]+-[0-9]+)(\.[1-9][0-9]*-[1-9][0-9]*)* +)+$ ]] || reportExit "Error (${PRTLST[*]}): Ports should be a list of write-read port numbers list"
[[ "${ARCLST[*]} " =~ ^((REG|XOR|LVTREG|LVTBIN|LVT1HT) +)+$                           ]] || reportExit "Error (${BYPLST[*]}): Bypass should be a list of NON, WAW, RAW, or RDW"

# total different designs
let "runTot = ${#MDLST[*]} * ${#DWLST[*]} * ${#BYPLST[*]} * ${#PRTLST[*]} * ${#ARCLST[*]}"
let "runCnt = 1"

# print info to log
echog ">>> Synthesis in batch $runTot designs with the following parameters:"
echob ">>> Memory depth         : ${MDLST[*]}"
echob ">>> Data width           : ${DWLST[*]}"
echob ">>> Bypass type          : ${BYPLST[*]}"
echob ">>> Port write/read pairs: ${PRTLST[*]}"
echob ">>> Architecture         : ${ARCLST[*]}"

#print header
#FML=$(grep " FAMILY " fmpram.qsf | cut -d\"  -f2)
#DEV=$(grep " DEVICE " fmpram.qsf | cut -d" " -f4)
TTL1='                                                          Fmax-MHz 0.9v     Combinational ALUT usage for logic                               LABs           I/O Pins   BRAM  M20K      BRAM Bits Utiliz.             \n'
TTL2='              RAM   Data  Dot Seperated Write-Read Pairs ------------- ----------------------------------------- Route  Total  Total  ----------------- -------------- ---------- MLAB -----------------      Runtime\n'
TTL3='Arch.  Bypass Depth Width 1st pair:fixed;others:switched T = 0c T= 85c Total  7-LUTs 6-LUTs 5-LUTs 4-LUTs 3-LUTs ALUTs  Reg.   ALMs   Total Logic Mem.  Tot. Clk  Ded. Total ILVT Bits Utilized Occupied DSPs Minutes\n'
SEPR='====== ====== ===== ===== ============================== ====== ====== ====== ====== ====== ====== ====== ====== ====== ====== ====== ===== ===== ===== ==== ==== ==== ===== ==== ==== ======== ======== ==== =======\n'
FRMT=($(echo $SEPR| tr " " "\n" | perl -nle '$a= length; print "%-${a}s"' | tr "\n" " "))
[[ -f syn.res ]] ||  printf "$FML $DEV\n\n$TTL1$TTL2$TTL3$SEPR" > syn.res

# create log directoy
[[ -d log ]] || mkdir log

# operate on all different RAM parameters
for MD in ${MDLST[*]} ; do
  for DW in ${DWLST[*]} ; do
    for BYP in ${BYPLST[*]} ; do
      for PRT in ${PRTLST[*]} ; do
        for ARC in ${ARCLST[*]} ; do

          # capture start time and time stamp
          runStartTimeStamp=$(date +%s)
          # current run tag name for file naming
          runTag="${ARC}-${BYP}_${MD}x${DW}_${PRT}"

          # print header
          echog ">>> Starting synthesis (${runCnt}/${runTot})  @${runStartTime}: [Depth:${MD}; Width:${DW}; Bypass:${BYP}; Ports:${PRT}; Architicture:${ARC}]"

          # remove previouslt generated files before run
          rmAll fmpram_lvt.* $VCFGFN output_files
 
          # run precompile to generate Verilog and other files
          ./precomp.sh fmpram_lvt $(echo $PRT | tr ".-" " ")

          # calculate precompile runtime
          preFinishTimeStamp=$(date +%s)
          (( preTimeDiff = preFinishTimeStamp - runStartTimeStamp ))
          preTimeMin=$(echo "scale=2;$preTimeDiff/60"|bc)

          echog ">>> Precompile (${runCnt}/${runTot}) completed after ${preTimeMin} minutes: [Depth:${MD}; Width:${DW}; Bypass:${BYP}; Ports:${PRT}; Architicture:${ARC}]"

          #################### START SYNTHESIS AND REPORTS WITH CURRENT PARAMETERS ####################

          # create configuration file base on architectural
          sed -i '$ d' $VCFGFN
          printf '\n// Additional parameters required for synthesis\n'                           >> $VCFGFN
          printf '// Generated by flow manager before logic synthesis\n'                         >> $VCFGFN
          printf '`define ARC %-8s // Architecture: REG, XOR, LVTREG, LVTBIN, LVT1HT\n' \"$ARC\" >> $VCFGFN
          printf '`define BYP %-8s // Bypass: NON, WAW, RAW, RDW\n'                     \"$BYP\" >> $VCFGFN
          printf '`define MD  %-8s // Memory Depth (lines) \n'                            $MD    >> $VCFGFN
          printf '`define DW  %-8s // Data Width (bits) \n'                               $DW    >> $VCFGFN
          printf '\n`endif //__FMPRAM_CFG_VH__'                                                  >> $VCFGFN

          # run current synthesis
          quartus_map --64bit --read_settings_files=on  --write_settings_files=off fmpram -c fmpram | tee log/${runTag}.map.log
          quartus_cdb --64bit --merge  fmpram -c fmpram                                             | tee log/${runTag}.cdb.log
          quartus_fit --64bit --read_settings_files=off --write_settings_files=off fmpram -c fmpram | tee log/${runTag}.fit.log
          quartus_sta --64bit fmpram -c fmpram                                                      | tee log/${runTag}.sta.log

          # calculate runtime and generate a report / per run
          runFinishTimeStamp=$(date +%s)
          (( runTimeDiff = runFinishTimeStamp - runStartTimeStamp ))
          runTimeMin=$(echo "scale=2;$runTimeDiff/60"|bc)

          # assign "N/A" for all values (to invalidate values from previous run)
          for i in {0..28} ; do val[$i]="N/A"; done

          # collect data
          val[0]=$ARC
          val[1]=$BYP
          val[2]=$MD
          val[3]=$DW
          val[4]=$PRT
          if [[ -f output_files/fmpram.sta.rpt ]] ; then
            val[5]=$(grep -a4 "Slow 900mV 0C Model Fmax Summary"  output_files/fmpram.sta.rpt | tail -1 | cut -d" " -f2 | tr -d " \n")
            val[6]=$(grep -a4 "Slow 900mV 85C Model Fmax Summary" output_files/fmpram.sta.rpt | tail -1 | cut -d" " -f2 | tr -d " \n")
          fi
          if [[ -f output_files/fmpram.fit.rpt ]] ; then
            grep -A88 "; Fitter Resource Usage Summary" output_files/fmpram.fit.rpt > __fit_rpt__
            val[7]=$( grep -m1    "ALUT usage for logic"        __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[8]=$( grep -m1    "7 input"                     __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[9]=$( grep -m1    "6 input"                     __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[10]=$(grep -m1    "5 input"                     __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[11]=$(grep -m1    "4 input"                     __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[12]=$(grep -m1    "<=3 input"                   __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[13]=$(grep -m1    "ALUT usage for route"        __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[14]=$(grep -m1    "Dedicated logic registers"   __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[15]=$(grep -m1    "ALMs needed \["              __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[16]=$(grep -m1    "Total LABs"                  __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[17]=$(grep -m1    "Logic LABs"                  __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[18]=$(grep -m1    "Memory LABs"                 __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[19]=$(grep -m1    "I/O pins"                    __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[20]=$(grep -m1    "Clock pins"                  __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[21]=$(grep -m1    "Dedicated input"             __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[22]=$(grep -m1    "M20K"                        __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[23]=$(grep -m1 -E ";       \|lvt_"              output_files/fmpram.fit.rpt | cut -d';' -f12| tr -d " " )
            val[24]=$(grep -m1    "MLAB"                        __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[25]=$(grep -m1    "block memory bits"           __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[26]=$(grep -m1    "block memory implementation" __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[27]=$(grep -m1    "DSP"                         __fit_rpt__ | cut -d";" -f3 | cut -d"/" -f1 | tr -d ", ")
            val[28]=$runTimeMin
            \rm -rf __fit_rpt__
          fi

          # assign "N/A" for non matching values
          for i in {0..28} ; do [[ ${val[$i]} == "" ]] && val[$i]="N/A"; done

          # print to report
          printf "${FRMT[*]}\n" ${val[*]} >> syn.res

          # move log files and design specific into log directory
          if [ -d output_files ] ; then
            mv -f fmpram_lvt.* $VCFGFN output_files/
            for f in output_files/* ; do
              mv $f $(echo $f|cut -d. -f2-|sed s/^/log\\/$runTag./g)
            done
            \rm -rf output_files
          fi

          #################### FINISH SYNTHESIS AND REPORTS WITH CURRENT PARAMETERS ####################

          echog ">>> Synthesis (${runCnt}/${runTot}) completed after ${runTimeMin} minutes: [Depth:${MD}; Width:${DW}; Bypass:${BYP}; Ports:${PRT}; Architicture:${ARC}]"
          ((runCnt++))

        done
      done
    done
  done
done

# clean unrequired files / after run
rmAll db incremental_db

# syn.sh 64 4 RDW 2-2 LVT1HT
