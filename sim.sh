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
##                     Run-in-batch Simulation Flow Manager                       ##
##                                                                                ##
##   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   ##
##   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   ##
####################################################################################

####################################################################################
## USAGE:                                                                         ##
##   ./sim <Depth List> <Width List> <#Write Ports List (Fixed-Switched)> \       ##
##         <#Read Ports List (Fixed-Switched)> <Bypass List> <#Cycles> [verbose]  ##
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
##                                                                                ##
## EXAMPLES:                                                                      ##
## ./sim 1024 32 1-2 2-2 NON 1000000 verbose                                      ##
##    Simulate 1M cycles of a 1K lines RAM, 32 bits width, 1 fixed / 2 switched   ##
##    write & 2 fixed / 2 switched read ports, no bypassing, verbose logging,     ##
## ./sim 512,1024 8,16,32 2,3,4 1,2,3,4 RAW 1000000                               ##
##    Simulate 1M cycles of RAMs with 512 or 1024 lines, 8, 16, or 32 bits width, ##
##    2,3, or 4 fixed write ports, 1,2,3, or 4 fixed read ports, with RAW bypass. ##
##                                                                                ##
## The following files and directories will be created after simulation :         ##
##   - sim.res : A list of simulation results, each run in a separate line,       ##
##               including all design styles.                                     ##
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

# setup environment variables and Altera's CAD tools 
# add your own flow (after the last `else`) if necessary 
if [[ $(hostname -d) == "ece.ubc.ca" ]] ; then
  echo "Setup Altera CAD flow from The University of BC..."
  . ./altera.13.1.ubc.sh
else
  ## --> for other CAD environment, setup your flow here
  echor 'Error: Altera CAD flow is defined for UBC environment only.'
  echor '       Define your flow in ./sim.sh'
  echor '       Exiting...'
  exit 1
  ## <-- for other CAD environment, setup your flow here
fi

####################################################################################
##                                   Main Script                                  ##
####################################################################################

# check if verbose is required in case of 7 arguments;
# otherwise, exactly 6 arguments are required
VERB=0
if [[ $# == 7 ]] ; then
  if [[ ($7 == "verbose") || ($7 == "verb") || ($7 == "v") ]] ; then
    VERB=1
  else
    reportExit 'Error: Check arguments syntax'
  fi
elif [[ $# != 6 ]] ; then
  reportExit 'Error: Exactly 6 or 7 arguments are required'
fi


# convert each argument list into a bash list (remove commas, etc.)
MDLST=( $(echo $1 | tr ",()[]{}<>" " "))
DWLST=( $(echo $2 | tr ",()[]{}<>" " "))
INILST=($(echo $3 | tr ",()[]{}<>" " "))
BYPLST=($(echo $4 | tr ",()[]{}<>" " "))
CYCC=$5
PRTLST=($(echo $6 | tr ",()[]{}<>" " "))


# check arguments correctness (using regexp)
[[  ${MDLST[*]}    =~ ^([1-9][0-9]* *)+$                                 ]] || reportExit "Error (${MDLST[*]}): Memory depth list should be a list of possitive integer numbers"
[[  ${DWLST[*]}    =~ ^([1-9][0-9]* *)+$                                 ]] || reportExit "Error (${DWLST[*]}): Data width list should be a list of possitive integer numbers"
[[  $CYCC          =~ ^[1-9][0-9]*$                                      ]] || reportExit "Error ($CYCC): Number of simulation cycles shoudl be a possitive integer number"
[[ "${INILST[*]} " =~ ^((CLR|RND|.*\.hex|.*\.bin) +)+$                                   ]] || reportExit "Error (${INILST[*]}): RAM initializing method should be a list of CLR, RND or .hex/.bin file name"
[[ "${BYPLST[*]} " =~ ^((NON|WAW|RAW|RDW) +)+$                           ]] || reportExit "Error (${BYPLST[*]}): Bypass should be a list of NON, WAW, RAW, or RDW"
[[ "${PRTLST[*]} " =~ ^(([0-9]+-[0-9]+)(\.[1-9][0-9]*-[1-9][0-9]*)* +)+$ ]] || reportExit "Error (${PRTLST[*]}): Ports should be a list of write-read port numbers list"

# total different designs
let "runTot = ${#MDLST[*]} * ${#DWLST[*]} * ${#INILST[*]} * ${#BYPLST[*]} * ${#PRTLST[*]}"
let "runCnt = 1"

# print info to log
echog ">>> Simulate in batch $runTot designs with the following parameters:"
echob ">>> Memory depth         : ${MDLST[*]}"
echob ">>> Data width           : ${DWLST[*]}"
echob ">>> Bypass type          : ${BYPLST[*]}"
echob ">>> Initializing         : ${INILST[*]}"
echob ">>> Port write/read pairs: ${PRTLST[*]}"
echob ">>> Simulation cycles    : ${CYCC}"

# operate on all different RAM parameters
for MD in ${MDLST[*]} ; do
  for DW in ${DWLST[*]} ; do
    for INI in ${INILST[*]} ; do
      for BYP in ${BYPLST[*]} ; do
        for PRT in ${PRTLST[*]} ; do

          # capture start time and time stamp
          runStartTimeStamp=$(date +%s)

          # remove previous files
          rmAll fmpram_lvt.*

          # run precompile to generate Verilog and other files
          echog ">>> Starting Precompile (${runCnt}/${runTot}): [Depth:${MD}; Width:${DW}; Ports:${PRT}; Initialize:${INI}; Bypass:${BYP}; Cycles:${CYCC}]"
          precomp.sh fmpram_lvt $(echo $PRT | tr ".-" " ")

          # calculate precompile runtime
          preFinishTimeStamp=$(date +%s)
          (( preTimeDiff = preFinishTimeStamp - runStartTimeStamp ))
          preTimeMin=$(echo "scale=2;$preTimeDiff/60"|bc)

          echog ">>> Precompile (${runCnt}/${runTot}) completed after ${preTimeMin} minutes: [Depth:${MD}; Width:${DW}; Bypass:${BYP}; Ports:${PRT}; Architicture:${ARC}]"

          ## print header
          echog ">>> Starting Simulation (${runCnt}/${runTot}): [Depth:${MD}; Width:${DW}; Ports:${PRT}; Initialize:${INI}; Bypass:${BYP}; Cycles:${CYCC}]"
          # remove work directory to recompile verilog
          [[ -d work ]] && \rm -rf work
          # recreate work directory
          vlib work
          # run current simulation
          vlog -work work +define+SIM+ARC=\"\"+MD=$MD+DW=$DW+BYP=\"$BYP\"+INI=\"$INI\"+VERB=1+CYCC=$CYCC fmpram.cfg.vh utils.vh dpram.v dpram_bbs.v mrdpramSS.v mrdpramTS.v mrdpramTT.v mpram_reg.v mpram_xor.v lvt_reg.v lvt_bin.v lvt_1ht.v fmpram_lvt.v fmpram.v fmpram_tb.v
          vsim -c -L altera_mf_ver -L lpm_ver -do "run -all" fmpram_tb

          # calculate runtime
          runFinishTimeStamp=$(date +%s)
          (( runTimeDiff = runFinishTimeStamp - runStartTimeStamp ))
          runTimeMin=$(echo "scale=2;$runTimeDiff/60"|bc)

          # print footer
          echog ">>> Simulation (${runCnt}/${runTot}) Completed after ${runTimeMin} minutes: [Depth:${MD}; Width:${DW}; Ports:${PRT}; Initialize:${INI}; Bypass:${BYP}; Cycles:${CYCC}]"
          ((runCnt++))
        done
      done
    done
  done
done

# clean unrequired files / after run
rmAll work transcript randram.*

#sim.sh 64,128 4,8 CLR,RND NON,WAW,RAW,RDW 1000 3-3,0-0.1-1.1-1.1-1,2-0.1-1.1-1.1-1,0-2.1-1.1-1.1-1,2-1.2-1,1-2.2-1.3-2,2-3.3-4.1-1,2-3.3-4.1-1.2-1
