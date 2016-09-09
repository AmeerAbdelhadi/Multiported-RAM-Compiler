#!/bin/bash         

#######################################################################################
##  Copyright (c) 2015, University of British Columbia (UBC).  All rights reserved.  ##
##                                                                                   ##
##  Redistribution  and  use  in  source   and  binary  forms,   with  or   without  ##
##  modification,  are permitted  provided that  the following conditions  are met:  ##
##    * Redistributions   of  source   code  must  retain   the   above   copyright  ##
##      notice,  this   list   of   conditions   and   the  following   disclaimer.  ##
##    * Redistributions   in  binary  form  must  reproduce  the  above   copyright  ##
##      notice,  this  list  of  conditions  and the  following  disclaimer in  the  ##
##      documentation  and/or  other  materials  provided  with  the  distribution.  ##
##    * Neither the name of the University of British Columbia (UBC) nor the  names  ##
##      of   its   contributors  may  be  used  to  endorse  or   promote  products  ##
##      derived from  this  software  without  specific  prior  written permission.  ##
##                                                                                   ##
##  THIS  SOFTWARE IS  PROVIDED  BY THE  COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"  ##
##  AND  ANY EXPRESS  OR IMPLIED  WARRANTIES,  INCLUDING,  BUT NOT LIMITED TO,  THE  ##
##  IMPLIED WARRANTIES OF  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE  ##
##  DISCLAIMED.  IN  NO  EVENT SHALL University of British Columbia (UBC) BE LIABLE  ##
##  FOR ANY DIRECT,  INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY,  OR CONSEQUENTIAL  ##
##  DAMAGES  (INCLUDING,  BUT NOT LIMITED TO,  PROCUREMENT  OF  SUBSTITUTE GOODS OR  ##
##  SERVICES;  LOSS OF USE,  DATA,  OR PROFITS;  OR BUSINESS  INTERRUPTION) HOWEVER  ##
##  CAUSED AND ON ANY THEORY  OF LIABILITY,  WHETHER IN CONTRACT, STRICT LIABILITY,  ##
##  OR TORT  (INCLUDING  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE  ##
##  OF  THIS  SOFTWARE,  EVEN  IF  ADVISED  OF  THE  POSSIBILITY  OF  SUCH  DAMAGE.  ##
#######################################################################################

#######################################################################################
##                     simulation and synthesis precompilation                       ##
##                                                                                   ##
##    Author:  Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)    ##
##    SRAM-based Multi-ported RAM with Flexible Ports;  The University of BC 2015    ##
#######################################################################################

#######################################################################################
##                                  Bash Functions                                   ##
#######################################################################################

# maximim/minimum of two numbers
# arguments: two integers
function max2 () { echo $(($1>$2?$1:$2)); }
function min2 () { echo $(($1<$2?$1:$2)); }

# convert decimal to onehot
# arguments: decimal integer, onehot width, indent width
function dec2onehot () {
  local i;
  local j;
  for (( i = 0 ; i < $2 ; i++ )) ; do
    if (( i == $1 )) ; then echo -n "1" ; else echo -n "0" ; fi
    for (( j = 0 ; j < $3 ; j++ )) ; do echo -n " "; done
  done
  echo
}

# sum of a list
# arguments: integer numbers to sum
function sumlist () {
 local total=0
 local arg
 for arg in $@; do
   (( total+=arg ))
 done
 echo $total
} 

# floating point division/Multiplication
# arguments: dividend/factor, divisor/factor, scale (number of digits decimal fractions)
function fdiv () { echo "scale=$3; $1/$2" | bc -l; }
function fmul () { echo "scale=$3; $1*$2" | bc -l; }

# echo with new line in the beginning
function necho () { echo -e "\n$1"; }

# integer/string padding
# arguments: integer/string, padding width
function iPad () { printf "%$2d"  $1;  }
function zPad () { printf "%0$2d"  $1;  }
function sPad () { printf "%$2s" "$1"; }

# repeat an input text several times
# arguments: text, times to repeat
function repeat () {
  local i
  for (( i=0 ; i<$2 ; i++ )) ; do
    printf "$1"
  done
}

#######################################################################################
##                                    Main Script                                    ##
#######################################################################################

#######################################################################################
##                      Script Arguments and Design Parameters                       ##
#######################################################################################

TFN=___temp___
FN=$1
DFGGFN=$FN.dfg.gv
SCPPFN=$FN.scp.prb
SCPDFN=$FN.scp.dat
SCPSFN=$FN.scp.sol
SCHGFN=$FN.sch.gv
VRLGVF=$FN.v
VCFGFN=fmpram.cfg.vh

shift

args=("$@") # input arguments
(( nP = $#/2 )) # total number of switched ports

for (( i = 0 ; i < $nP ; i++ )) ; do
  wP[$i]=${args[2*$i]}   # number of writes per port
  rP[$i]=${args[2*$i+1]} # number of reads  per port
done

#######################################################################################
##                                Create DFG database                                ##
#######################################################################################

## write and read node arrays

nR=0
nW=0
for (( p = 0 ; p < $nP ; p++ )) ; do
  for (( wi = 0 ; wi < ${wP[$p]} ; wi++ )) ; do
    wrName[$nW]="\"w$p,$wi\""
    wrIdx1[$nW]=$p
    wrIdx2[$nW]=$wi
    ((nW++))
  done
  for (( ri = 0 ; ri < ${rP[$p]} ; ri++ )) ; do
    rdName[$nR]="\"r$p,$ri\""
    rdIdx1[$nR]=$p
    rdIdx2[$nR]=$ri
    ((nR++))
  done
done 

## edges array

nE=0; # edges index
for (( pi = 0 ; pi < $nP ; pi++ )) ; do
  for (( wpi = 0 ; wpi < ${wP[$pi]} ; wpi++ )) ; do
    for (( pj = 0 ; pj < $nP ; pj++ )) ; do
      for (( rpj = 0 ; rpj < ${rP[$pj]} ; rpj++ )) ; do
        if (( pi && pj && pi == pj )) ; then
          edgeIsSw[$nE]=1
          edgeName[$nE]="W$pi,$wpi--R$pj,$rpj"
        else
          edgeIsSw[$nE]=0
          edgeName[$nE]="W$pi,$wpi==R$pj,$rpj"
        fi
        edgeAMPL[$nE]="W$pi,$wpi-R$pj,$rpj"
        edgeWrPi[$nE]=$pi
        edgeWrPj[$nE]=$wpi
        edgeRdPi[$nE]=$pj
        edgeRdPj[$nE]=$rpj
        edgeWrName[$nE]="\"w$pi,$wpi\""
        edgeRdName[$nE]="\"r$pj,$rpj\""
        ((nE++))
      done
    done
  done
done


#######################################################################################
##                              Write DOT DFG (.dfg.gv)                              ##
#######################################################################################
     

echo "graph G {" > $DFGGFN
echo "  rankdir=LR;" >> $DFGGFN
echo "  concentrate=true;" >> $DFGGFN
echo "  overlap=false;" >> $DFGGFN
echo "  splines=true;" >> $DFGGFN
echo "  ranksep=$(fdiv $(max2 $nW $nR) 2 2);" >> $DFGGFN

#echo "  size=\"7,10\";" >> $DFGGFN
#echo "  ratio=fill;" >> $DFGGFN

# writes cluster

echo >> $DFGGFN
echo "  // writes cluster" >> $DFGGFN
echo "  subgraph cluster0 {" >> $DFGGFN
echo "    label = \"writes\";" >> $DFGGFN

for (( wi = 0 ; wi < $nW ; wi++ )) ; do
  echo -n "    ${wrName[$wi]}" >> $DFGGFN
   if (( wrIdx1[$wi] == 0 )) ; then
     echo -n " [style=\"       " >> $DFGGFN
   else
     echo -n " [style=\"dashed," >> $DFGGFN
   fi
   echo "filled\",label=<w<FONT POINT-SIZE=\"8\">${wrIdx1[$wi]},${wrIdx2[$wi]}</FONT>>];" >> $DFGGFN
done

echo -e "  }\n" >> $DFGGFN

# reads cluster

echo "  // reads cluster"     >> $DFGGFN
echo "  subgraph cluster1 {"  >> $DFGGFN
echo "    label = \"reads\";" >> $DFGGFN

for (( ri = 0 ; ri < $nR ; ri++ )) ; do
  echo -n "    ${rdName[$ri]}" >> $DFGGFN
   if (( rdIdx1[$ri] == 0 )) ; then
     echo -n " [             " >> $DFGGFN
   else
     echo -n " [style=dashed," >> $DFGGFN
   fi
   echo "label=<r<FONT POINT-SIZE=\"8\">${rdIdx1[$ri]},${rdIdx2[$ri]}</FONT>>];" >> $DFGGFN
done

echo -e "  }\n" >> $DFGGFN

# edges

echo "  // edges" >> $DFGGFN
for (( ei = 0 ; ei < $nE ; ei++ )) ; do
  echo -n "  ${edgeWrName[$ei]} -- ${edgeRdName[$ei]}" >> $DFGGFN
  if (( edgeIsSw[$ei] )) ; then
    echo " [style=dashed,color=red];" >> $DFGGFN
  else
    echo "                         ;" >> $DFGGFN
  fi
done
echo "}" >> $DFGGFN

dot -Tpdf -o $FN.dfg.pdf $DFGGFN

#######################################################################################
##                              Create covers database                               ##
#######################################################################################

##  array of covers

nC=0; # covers index

# pattern 1W1R fixed
for (( p = 0 ; p < $nP      ; p++ )) ; do
  for (( i = 0 ; i < ${wP[$p]} ; i++ )) ; do
    for (( q = 0 ; q < $nP       ; q++ )) ; do
      for (( l = 0 ; l < ${rP[$q]} ; l++ )) ; do
        if (( p != q || p*q == 0 )) ; then
          coverStamp[$nC]="1W1Rf:W$p,$i-R$q,$l"
          coverType[$nC]="1W1Rf"
          coverCost[$nC]=1
          ((nC++))
        fi       
      done
    done
  done
done  

# pattern 1W1R switched
for (( p = 1 ; p < $nP      ; p++ )) ; do
  for (( i = 0 ; i < ${wP[$p]} ; i++ )) ; do
    for (( j = 0 ; j < ${rP[$p]} ; j++ )) ; do
      coverStamp[$nC]="1W1Rs:W$p,$i-R$p,$j"
      coverType[$nC]="1W1Rs"
      coverCost[$nC]=1
      ((nC++))
    done
  done
done

# pattern 1W2R fixed
for (( p = 1 ; p < $nP      ; p++ )) ; do
  for (( i = 0 ; i < ${wP[$p]} ; i++ )) ; do
    for (( j = 0 ; j < ${rP[$p]} ; j++ )) ; do
      for (( q = 0 ; q < $nP       ; q++ )) ; do
        for (( l = 0 ; l < ${rP[$q]} ; l++ )) ; do
          if (( p != q )) ; then
            coverStamp[$nC]="1W2Rf:W$p,$i-R$p,$j;W$p,$i-R$q,$l"
            coverType[$nC]="1W2Rf"
            coverCost[$nC]=1.001
            ((nC++))
          fi
        done
      done
    done
  done
done

# pattern 1W2R switched
for (( p = 1   ; p < $nP      ; p++ )) ; do
  for (( i = 0   ; i < ${wP[$p]} ; i++ )) ; do
    for (( j = 0   ; j < ${rP[$p]} ; j++ )) ; do
      for (( l = j+1 ; l < ${rP[$p]} ; l++ )) ; do
        coverStamp[$nC]="1W2Rs:W$p,$i-R$p,$j;W$p,$i-R$p,$l"
        coverType[$nC]="1W2Rs"
        coverCost[$nC]=1.001
        ((nC++))
      done
    done
  done
done

# pattern 2W1R fixed
for (( p = 1 ; p < $nP      ; p++ )) ; do
  for (( j = 0 ; j < ${rP[$p]} ; j++ )) ; do
    for (( i = 0 ; i < ${wP[$p]} ; i++ )) ; do
      for (( q = 0 ; q < $nP       ; q++ )) ; do
        for (( k = 0 ; k < ${wP[$q]} ; k++ )) ; do
          if (( p != q )) ; then
            coverStamp[$nC]="2W1Rf:W$p,$i-R$p,$j;W$q,$k-R$p,$j"
            coverType[$nC]="2W1Rf"
            coverCost[$nC]=1.001
            ((nC++))
          fi
        done
      done
    done
  done
done

# pattern 2W1R switched
for (( p = 1   ; p < $nP      ; p++ )) ; do
  for (( j = 0   ; j < ${rP[$p]} ; j++ )) ; do
    for (( i = 0   ; i < ${wP[$p]} ; i++ )) ; do
      for (( k = i+1 ; k < ${wP[$p]} ; k++ )) ; do
        coverStamp[$nC]="2W1Rs:W$p,$i-R$p,$j;W$p,$k-R$p,$j"
        coverType[$nC]="2W1Rs"
        coverCost[$nC]=1.001
        ((nC++))
      done
    done
  done
done

# pattern 2W2R fixed
for (( p = 1   ; p < $nP      ; p++ )) ; do
  for (( i = 0   ; i < ${wP[$p]} ; i++ )) ; do
    for (( j = 0   ; j < ${rP[$p]} ; j++ )) ; do
      for (( q = p+1 ; q < $nP       ; q++ )) ; do
        for (( k = 0   ; k < ${wP[$q]} ; k++ )) ; do
          for (( l = 0   ; l < ${rP[$q]} ; l++ )) ; do
            if (( p != q )) ; then
              coverStamp[$nC]="2W2Rf:W$p,$i-R$p,$j;W$p,$i-R$q,$l;W$q,$k-R$p,$j;W$q,$k-R$q,$l"
              coverType[$nC]="2W2Rf"
              coverCost[$nC]=1.002
              ((nC++))
            fi
          done
        done
      done
    done
  done
done

# pattern 2W2R switched
for (( p = 1   ; p < $nP      ; p++ )) ; do
  for (( i = 0   ; i < ${wP[$p]} ; i++ )) ; do
    for (( j = 0   ; j < ${rP[$p]} ; j++ )) ; do
      for (( k = i+1   ; k < ${wP[$p]} ; k++ )) ; do
        for (( l = j+1   ; l < ${rP[$p]} ; l++ )) ; do
          if (( i != k && j != l)) ; then
            coverStamp[$nC]="2W2Rs:W$p,$i-R$p,$j;W$p,$i-R$p,$l;W$p,$k-R$p,$j;W$p,$k-R$p,$l"
            coverType[$nC]="2W2Rs"
            coverCost[$nC]=1.002
            ((nC++))
          fi
        done
      done
    done
  done
done

#######################################################################################
##                     Write Set Cover Problem Description File                      ##
#######################################################################################

echo    "# Set cover description file:  First line lists the universe" >  $SCPPFN 
echo -e "# (all elements), while each other line lists a coverage set\n" >> $SCPPFN

echo -n "{" >> $SCPPFN
for (( ei = 0 ; ei < $nE ; ei++ )) ; do
  echo -n "\"${edgeAMPL[$ei]}\""  >>  $SCPPFN
  (( ei < $nE-1 )) && echo -n "," >> $SCPPFN
done
echo "}" >> $SCPPFN
for (( ci = 0 ; ci < $nC ; ci++ )) ; do
  echo "${coverStamp[$ci]}\"}"|cut -d: -f2 | sed s/^/{\"/ | sed s/\;/\",\"/ >> $SCPPFN
done

#######################################################################################
##                      Write AMPL Data File for Set Cover ILP                       ##
#######################################################################################

echo -e "# Set cover ILP AMPL data file\n"  > $SCPDFN
echo -e "data;\n" >> $SCPDFN

echo -n "set I := " >> $SCPDFN
for (( ei = 0 ; ei < $nE ; ei++ )) ; do
  echo -n "\"${edgeAMPL[$ei]}\" " >> $SCPDFN
done
echo ";" >> $SCPDFN

echo -n "set J := " >> $SCPDFN
for (( ci = 0 ; ci < $nC ; ci++ )) ; do
  echo -n "\"${coverStamp[$ci]}\" " >> $SCPDFN
done
echo -e ";\n" >> $SCPDFN

echo "param c:=" >> $SCPDFN
for (( ci = 0 ; ci < $nC ; ci++ )) ; do
  sPad "\"${coverStamp[$ci]}\"" -48 >> $SCPDFN
  echo "${coverCost[$ci]}" >> $SCPDFN
done
echo -e ";\n" >> $SCPDFN

echo "param a (tr):" >> $SCPDFN

sPad "" 48 >> $SCPDFN
for (( ei = 0 ; ei < $nE ; ei++ )) ; do
  echo -n "\"${edgeAMPL[$ei]}\" " >> $SCPDFN
done
echo ":=" >> $SCPDFN

for (( ci = 0 ; ci < $nC ; ci++ )) ; do
  sPad "\"${coverStamp[$ci]}\"" -48 >> $SCPDFN
  for (( ei = 0 ; ei < $nE ; ei++ )) ; do
    if [[ ${coverStamp[$ci]} == *${edgeAMPL[$ei]}* ]] ; then
      echo -n "     1      " >> $SCPDFN
    else
      echo -n "     0      " >> $SCPDFN
    fi
  done
  echo >> $SCPDFN
done
echo -e ";\n\nend;" >> $SCPDFN

#######################################################################################
##                          Solve ILP Using GLPK ILP Solver                          ##
#######################################################################################

if [[ ! -x glpk-4.55/bin/glpsol  ]] ; then
  # run in a subshell
  (
    echo "--- glpk binary is not found, compiling from source located in glpk-4.55.tar.gz"
    [[ -d glpk-4.55 ]] && \rm -rf glpk-4.55
    tar -xvzf glpk-4.55.tar.gz
    cd glpk-4.55
    configure --disable-shared --prefix=$PWD
    make
    make check
    make install
    make clean
    make distclean
  )
fi

# Solve ILP Using GLPK ILP Solver  
glpk-4.55/bin/glpsol -m setcovering.mod -d $SCPDFN -y $SCPSFN

# store solution cover stamps into an array
solStamp=($(<$SCPSFN))

# parase solution cover stamps array into dual-ported BRAM ports
nS=0
for s in ${solStamp[@]} ; do
  solType[$nS]=$( echo $s|cut -d: -f1)
  solCover[$nS]=$(echo $s|cut -d: -f2)
  solCoverList=($(echo ${solCover[$nS]}| tr -d WR | tr ";,-" " "))
  case ${solType[$nS]} in
    1W1Rf|1W1Rs)
      solW0p[$nS]=${solCoverList[0]}
      solW0i[$nS]=${solCoverList[1]}
      solR0p[$nS]=""
      solR0i[$nS]=""
      solW1p[$nS]=""
      solW1i[$nS]=""
      solR1p[$nS]=${solCoverList[2]}
      solR1i[$nS]=${solCoverList[3]}
      wEn0[$nS]="wEn_${solW0p[$nS]}_${solW0i[$nS]}"
      wData0[$nS]="wData_${solW0p[$nS]}_${solW0i[$nS]}"
      addr0[$nS]="wAddr_${solW0p[$nS]}_${solW0i[$nS]}"
      rData0[$nS]=""
      wEn1[$nS]="1'b0   "
      wData1[$nS]="{DW{1'b0}}"
      addr1[$nS]="rAddr_${solR1p[$nS]}_${solR1i[$nS]}"
      rData1[$nS]="rData_r_${solR1p[$nS]}_${solR1i[$nS]}_w_${solW0p[$nS]}_${solW0i[$nS]}"
      ini[$nS]="\"NON\""; (( solW0p[$nS]+solW0i[$nS] )) || ini[$nS]=" INI "
      ;;
    1W2Rf|1W2Rs)
      solW0p[$nS]=${solCoverList[0]}
      solW0i[$nS]=${solCoverList[1]}
      solR0p[$nS]=${solCoverList[2]}
      solR0i[$nS]=${solCoverList[3]}
      solW1p[$nS]=""
      solW1i[$nS]=""
      solR1p[$nS]=${solCoverList[6]}
      solR1i[$nS]=${solCoverList[7]}
      wEn0[$nS]="wEn_${solW0p[$nS]}_${solW0i[$nS]}"
      wData0[$nS]="wData_${solW0p[$nS]}_${solW0i[$nS]}"
      addr0[$nS]="${wEn0[$nS]}?wAddr_${solW0p[$nS]}_${solW0i[$nS]}:rAddr_${solR0p[$nS]}_${solR0i[$nS]}"
      rData0[$nS]="rData_r_${solR0p[$nS]}_${solR0i[$nS]}_w_${solW0p[$nS]}_${solW0i[$nS]}"
      wEn1[$nS]="1'b0   "
      wData1[$nS]="{DW{1'b0}}"
      addr1[$nS]="rAddr_${solR1p[$nS]}_${solR1i[$nS]}"
      rData1[$nS]="rData_r_${solR1p[$nS]}_${solR1i[$nS]}_w_${solW0p[$nS]}_${solW0i[$nS]}"
      ini[$nS]="\"NON\""; (( solW0p[$nS]+solW0i[$nS] )) || ini[$nS]=" INI "
      ;;
    2W1Rf|2W1Rs)
      solW0p[$nS]=${solCoverList[0]}
      solW0i[$nS]=${solCoverList[1]}
      solR0p[$nS]=${solCoverList[2]}
      solR0i[$nS]=${solCoverList[3]}
      solW1p[$nS]=${solCoverList[4]}
      solW1i[$nS]=${solCoverList[5]}
      solR1p[$nS]=""
      solR1i[$nS]=""
      wEn0[$nS]="wEn_${solW0p[$nS]}_${solW0i[$nS]}"
      wData0[$nS]="wData_${solW0p[$nS]}_${solW0i[$nS]}"
      addr0[$nS]="${wEn0[$nS]}?wAddr_${solW0p[$nS]}_${solW0i[$nS]}:rAddr_${solR0p[$nS]}_${solR0i[$nS]}"
      rData0[$nS]="rData_r_${solR0p[$nS]}_${solR0i[$nS]}_w_${solW0p[$nS]}_${solW0i[$nS]}_w_${solW1p[$nS]}_${solW1i[$nS]}"
      wEn1[$nS]="wEn_${solW1p[$nS]}_${solW1i[$nS]}"
      wData1[$nS]="wData_${solW1p[$nS]}_${solW1i[$nS]} "
      addr1[$nS]="wAddr_${solW1p[$nS]}_${solW1i[$nS]}"
      rData1[$nS]=""
      ini[$nS]="\"NON\""; (( (solW0p[$nS]+solW0i[$nS])*(solW1p[$nS]+solW1i[$nS]) )) || ini[$nS]=" INI "
      ;;
    2W2Rf|2W2Rs)
      solW0p[$nS]=${solCoverList[0]}
      solW0i[$nS]=${solCoverList[1]}
      solR0p[$nS]=${solCoverList[2]}
      solR0i[$nS]=${solCoverList[3]}
      solW1p[$nS]=${solCoverList[12]}
      solW1i[$nS]=${solCoverList[13]}
      solR1p[$nS]=${solCoverList[14]}
      solR1i[$nS]=${solCoverList[15]}
      wEn0[$nS]="wEn_${solW0p[$nS]}_${solW0i[$nS]}"
      wData0[$nS]="wData_${solW0p[$nS]}_${solW0i[$nS]}"
      addr0[$nS]="${wEn0[$nS]}?wAddr_${solW0p[$nS]}_${solW0i[$nS]}:rAddr_${solR0p[$nS]}_${solR0i[$nS]}"
      rData0[$nS]="rData_r_${solR0p[$nS]}_${solR0i[$nS]}_w_${solW0p[$nS]}_${solW0i[$nS]}_w_${solW1p[$nS]}_${solW1i[$nS]}"
      wEn1[$nS]="wEn_${solW1p[$nS]}_${solW1i[$nS]}"
      wData1[$nS]="wData_${solW1p[$nS]}_${solW1i[$nS]} "
      addr1[$nS]="${wEn1[$nS]}?wAddr_${solW1p[$nS]}_${solW1i[$nS]}:rAddr_${solR1p[$nS]}_${solR1i[$nS]}"
      rData1[$nS]="rData_r_${solR1p[$nS]}_${solR1i[$nS]}_w_${solW0p[$nS]}_${solW0i[$nS]}_w_${solW1p[$nS]}_${solW1i[$nS]}"
      ini[$nS]="\"NON\""; (( (solW0p[$nS]+solW0i[$nS])*(solW1p[$nS]+solW1i[$nS]) )) || ini[$nS]=" INI "
      ;;
  esac
  ((nS++))
done

# add comments to first line
sed -i '1s/^/# Set cover ILP solution; optimal covers are listed bellow\n\n/' $SCPSFN

#######################################################################################
## Generate Schematic of The Final Data Bank Connectivity Using  Graphviz DOT Format ##
#######################################################################################

echo "digraph G {" > $SCHGFN
echo "  rankdir=LR;" >> $SCHGFN
echo "  splines=spline;" >> $SCHGFN
echo "  overlap=false;" >> $SCHGFN
echo "  ranksep=$(fdiv $nS 4 2);" >> $SCHGFN

## write write port nodes
echo "  // write port nodes" >> $SCHGFN
for (( wi = 0 ; wi < nW ; wi++ )) ; do
    echo -e "  ${wrName[$wi]}\t[label=<w<FONT POINT-SIZE=\"8\">${wrIdx1[$wi]},${wrIdx2[$wi]}</FONT>>];" >> $SCHGFN
done
## write read port nodes
echo "  // read  port nodes" >> $SCHGFN
for (( ri = 0 ; ri < nR ; ri++ )) ; do
    echo -e "  ${rdName[$ri]}\t\t[shape=trapezium,orientation=270,height=2,label=<r<FONT POINT-SIZE=\"8\">${rdIdx1[$ri]},${rdIdx2[$ri]}</FONT>>];" >> $SCHGFN
done

echo "  // dual-porte BRAMs and edges" >> $SCHGFN
echo "  node[shape=record];" >> $SCHGFN

for (( si = 0 ; si < $nS ; si++ )) ; do
  ## write BRAM records
  echo "  \"${coverStamp[$si]}\" [label=\"<p1>wr1&#92; &#92; &#92; &#92; rd1|<p2>wr2&#92; &#92; &#92; &#92; rd2\"];" >> $SCHGFN
  ## write edges based on BCAM type
  case ${solType[$si]} in
    1W1Rf|1W1Rs)
      echo "  \"w${solW0p[$si]},${solW0i[$si]}\" -> \"${coverStamp[$si]}\":p1:w;" >> $SCHGFN
      echo "  \"${coverStamp[$si]}\":p2:e -> \"r${solR1p[$si]},${solR1i[$si]}\":w">> $SCHGFN
      ;;
    1W2Rf|1W2Rs)
      echo "  \"w${solW0p[$si]},${solW0i[$si]}\" -> \"${coverStamp[$si]}\":p1:w;" >> $SCHGFN
      echo "  \"${coverStamp[$si]}\":p1:e -> \"r${solR0p[$si]},${solR0i[$si]}\":w;" >> $SCHGFN
      echo "  \"${coverStamp[$si]}\":p2:e -> \"r${solR1p[$si]},${solR1i[$si]}\":w;" >> $SCHGFN
      ;;
    2W1Rf|2W1Rs)
      echo "  \"w${solW0p[$si]},${solW0i[$si]}\" -> \"${coverStamp[$si]}\":p1:w;" >> $SCHGFN
      echo "  \"w${solW1p[$si]},${solW1i[$si]}\" -> \"${coverStamp[$si]}\":p2:w;" >> $SCHGFN
      echo "  \"${coverStamp[$si]}\":p1:e -> \"r${solR0p[$si]},${solR0i[$si]}\":w;" >> $SCHGFN
      ;;
    2W2Rf|2W2Rs)
      echo "  \"w${solW0p[$si]},${solW0i[$si]}\" -> \"${coverStamp[$si]}\":p1:w;" >> $SCHGFN
      echo "  \"w${solW1p[$si]},${solW1i[$si]}\" -> \"${coverStamp[$si]}\":p2:w;" >> $SCHGFN
      echo "  \"${coverStamp[$si]}\":p1:e -> \"r${solR0p[$si]},${solR0i[$si]}\":w;" >> $SCHGFN
      echo "  \"${coverStamp[$si]}\":p2:e -> \"r${solR1p[$si]},${solR1i[$si]}\":w;" >> $SCHGFN
      ;;
  esac
done

echo "}" >> $SCHGFN

dot -Tpdf -o $FN.sch.pdf $SCHGFN

#######################################################################################
##                          Write Main fmpram_lvt.v Verilog                          ##
#######################################################################################

cat << EOF > $VRLGVF
////////////////////////////////////////////////////////////////////////////////////
// mpram_lvt.v: LVT-based Multiported-RAM for register-base and SRAM-based        //
//              one-hot/binary-coded I-LVT                                        //
//                                                                                //
//   Author: Ameer M.S. Abdelhadi (ameer@ece.ubc.ca, ameer.abdelhadi@gmail.com)   //
//   Switched SRAM-based Multi-ported RAM; University of British Columbia, 2014   //
////////////////////////////////////////////////////////////////////////////////////

\`include "utils.vh"

module fmpram_lvt #(
  parameter MD  = 16   , // memory depth
  parameter DW  = 32   , // data width
  parameter LVT = ""   , // LVT architecture type: LVTREG, LVTBIN, LVT1HT
  parameter WAW = 1    , // allow Write-After-Write (need to bypass feedback ram)
  parameter RAW = 1    , // new data for Read-after-Write (need to bypass output ram)
  parameter RDW = 0    , // new data for Read-During-Write
  parameter INI = "NON"  // initialization: CLR for zeros, or hex/bin file name (file extension .hex/.bin)
) (
  input                     clk  ,  // global clock
  input  [          $(iPad $nP 2)-1:0] wrRd , // write/read(inverted) - packed from $nP-1 ports (bit 0 is unused)
  input  [          $(iPad $nW 2)-1:0] wEn  , // write enables   - packed from $nW   ports
  input  [\`log2(MD)*$(iPad $nW 2)-1:0] wAddr, // write addresses - packed from $nW  writes
  input  [DW       *$(iPad $nW 2)-1:0] wData, // write data      - packed from  $nW  writes
  input  [\`log2(MD)*$(iPad $nR 2)-1:0] rAddr, // read  addresses - packed from $nR  reads
  output [DW       *$(iPad $nR 2)-1:0] rData  // read  data      - packed from $nR   reads
);

  // local parameters
  localparam nW = $(iPad $nW -21); // total number of write ports
  localparam nR = $(iPad $nR -21); // total number of read  ports
  localparam nP = $(iPad $nP -21); // total number of read/write pairs (fixed+switched groups)
  localparam AW = \`log2(MD)            ; // Address width
  localparam LW = \`log2(nW)            ; // LVT     width
  localparam SW = (LVT=="LVT1HT")?nW:LW; // data bank selector width 
  localparam INIEXT = INI[23:0]; // extension of initializing file (if exists)
  localparam isINI  = (INI   =="CLR" ) || // RAM is initialized if cleared,
                      (INIEXT=="hex") || // or initialized from .hex file,
                      (INIEXT=="bin")  ; // or initialized from .bin file

EOF

## generate write enables and write/read control
necho "  // write enables and write/read control" >> $VRLGVF
for (( wi = 0 ; wi < $nW ; wi++ )) ; do
  wrRd=$(sPad "" 11); (( ${wrIdx1[$wi]} > 0 )) && wrRd=" && wrRd[${wrIdx1[$wi]}]"
  echo "  wire wEn_${wrIdx1[$wi]}_${wrIdx2[$wi]} =   wEn[${wi}]$wrRd;" >> $VRLGVF
done

## generate write address and data wires
necho "  // write addresses and data" >> $VRLGVF
for (( wi = 0 ; wi < $nW ; wi++ )) ; do
  echo "  wire [AW-1:0] wAddr_${wrIdx1[$wi]}_${wrIdx2[$wi]} = wAddr[${wi}*AW +: AW];" >> $VRLGVF
  echo "  wire [DW-1:0] wData_${wrIdx1[$wi]}_${wrIdx2[$wi]} = wData[${wi}*DW +: DW];" >> $VRLGVF
done

## generate read address wires
necho "  // read addresses" >> $VRLGVF
#rpi=0
#for (( pi = 0 ; pi < $nP ; pi++ )) ; do
#  ((rP[pi]>0)) && echo "  wire [${rP[$pi]}*AW-1:0] rAddr_${pi} = rAddr[$((${rP[$pi]}+rpi))*AW-1:${rpi}*AW];" >> $VRLGVF
#  ((rpi+=${rP[$pi]}))
#done

for (( ri = 0 ; ri < $nR ; ri++ )) ; do
  echo "  wire [AW-1:0] rAddr_${rdIdx1[$ri]}_${rdIdx2[$ri]} = rAddr[${ri}*AW +: AW];" >> $VRLGVF
done

## generate read data wires
rDataWires=($(echo ${rData0[@]} ${rData1[@]} | tr ' ' '\n' | sort -u))
necho "  // read data" >> $VRLGVF
for r in ${rDataWires[@]} ; do
  echo "  wire [DW-1:0] $(sPad $r -23);" >> $VRLGVF
done

## read outputs from all writes
necho "  // read outputs from all writes" >> $VRLGVF
for (( ri = 0 ; ri < $nR ; ri++ )) ; do
  echo "  wire [$nW*DW-1:0] rData_${rdIdx1[$ri]}_${rdIdx2[$ri]};" >> $VRLGVF
done

## read outputs from all writes / used for one-hot LVT
necho "  // read outputs from all writes / used for one-hot LVT" >> $VRLGVF
for (( ri = 0 ; ri < $nR ; ri++ )) ; do
  echo "  wire [  DW-1:0] rData_${rdIdx1[$ri]}_${rdIdx2[$ri]}z;" >> $VRLGVF
done

## generate and instantiate LVT
cat << EOF >> $VRLGVF

  // read bank selectors
  wire [SW*nR-1:0] rBank           ; // read bank selector / 1D
  reg  [SW   -1:0] rBank2D [nR-1:0]; // read bank selector / 2D

  // unpack rBank into 2D array rBank2D
  \`ARRINIT;
  always @* \`ARR1D2D(nR,SW,rBank,rBank2D);

  // generate and instantiate LVT with specific implementation
  generate
    if (LVT=="LVTREG") begin
      // instantiate register-based LVT
      lvt_reg #(.MD(MD), .nR(nR), .nW(nW),                       .RDW(RDW), .INI(isINI?"CLR":"NON")) lvt_reg_i (.clk(clk), .wEn(wEn), .wAddr(wAddr), .rAddr(rAddr), .rBank(rBank));
    end
    else if (LVT=="LVTBIN") begin
      // instantiate binary BRAM-based LVT
      lvt_bin #(.MD(MD), .nR(nR), .nW(nW), .WAW(WAW), .RAW(RAW), .RDW(RDW), .INI(isINI?"CLR":"NON")) lvt_bin_i (.clk(clk), .wEn(wEn), .wAddr(wAddr), .rAddr(rAddr), .rBank(rBank));
    end
    else begin
      // instantiate one-hot BRAM-based LVT
      lvt_1ht #(.MD(MD), .nR(nR), .nW(nW), .WAW(WAW), .RAW(RAW), .RDW(RDW), .INI(isINI?"CLR":"NON")) lvt_1ht_i (.clk(clk), .wEn(wEn), .wAddr(wAddr), .rAddr(rAddr), .rBank(rBank));
    end
  endgenerate
EOF

## generate dual-ported RAM instantiation
necho "  // dual-ported RAM instantiation" >> $VRLGVF
for (( si = 0 ; si < $nS ; si++ )) ; do
  echo "  dpram_bbs #(.MD(MD), .DW(DW), .BYP(RDW), .INI(${ini[$si]})) dpram_$(zPad $si 3) (.clk(clk), .wEn0(${wEn0[$si]}), .wEn1(${wEn1[$si]}), .addr0($(sPad ${addr0[$si]} 27)), .addr1($(sPad ${addr1[$si]} 27)), .wData0(${wData0[$si]}), .wData1(${wData1[$si]}), .rData0($(sPad "${rData0[$si]}" -23)), .rData1($(sPad "${rData1[$si]}" -23))); // ${solStamp[$si]}" >> $VRLGVF
done

necho "  generate" >> $VRLGVF
echo  "  if (LVT==\"LVT1HT\") begin" >> $VRLGVF
echo  "    // infer tri-state buffers" >> $VRLGVF
for (( ri = 0 ; ri < nR ; ri++ )) ; do
  for (( wi = 0 ; wi < nW ; wi++ )) ; do
    echo -n "    assign rData_${rdIdx1[$ri]}_${rdIdx2[$ri]}z = rBank2D[$ri][$wi] ? " >> $VRLGVF
    for r in ${rDataWires[@]} ; do
      if [[ $r == rData_r_${rdIdx1[$ri]}_${rdIdx2[$ri]}*w_${wrIdx1[$wi]}_${wrIdx2[$wi]}* ]] ; then
        echo "$(sPad $r -23) : {DW{1'bz}};" >> $VRLGVF
        break
      fi
    done
  done
done

echo "    // pack read output from all read ports" >> $VRLGVF
echo -n "    assign rData = {"        >> $VRLGVF
for (( ri = nR-1 ; ri >= 0 ; ri-- )) ; do
  echo -n "rData_${rdIdx1[$ri]}_${rdIdx2[$ri]}z" >> $VRLGVF
  (( ri )) && echo -n "," >> $VRLGVF
done
echo -e "};\n  end\n  else begin" >> $VRLGVF

## read outputs from all writes, ordered by write port indices
echo "    // read outputs from all writes, ordered by write port indices" >> $VRLGVF
for (( ri = 0 ; ri < $nR ; ri++ )) ; do
  echo -n "    assign rData_${rdIdx1[$ri]}_${rdIdx2[$ri]} = {" >> $VRLGVF
  for (( wi = nW-1 ; wi >= 0 ; wi-- )) ; do
    for r in ${rDataWires[@]} ; do
      if [[ $r == rData_r_${rdIdx1[$ri]}_${rdIdx2[$ri]}*w_${wrIdx1[$wi]}_${wrIdx2[$wi]}* ]] ; then
        echo -n "$(sPad $r -23)" >> $VRLGVF
        break
      fi
    done
    (( wi )) && echo -n " ," >> $VRLGVF
  done
  echo    "};" >> $VRLGVF
done

## read ports mux array
echo "    // read ports mux array" >> $VRLGVF
echo "    assign rData = {"        >> $VRLGVF
for (( ri = nR-1 ; ri >= 0 ; ri-- )) ; do
  echo -n "      rData_${rdIdx1[$ri]}_${rdIdx2[$ri]}[rBank[$ri*SW +: SW]*DW +: DW]" >> $VRLGVF
  (( ri )) && echo "," >> $VRLGVF
done
echo -e "\n    };\n    end\n  endgenerate\n\nendmodule" >> $VRLGVF

#######################################################################################
##                        Write Verilog Header fmpram.cfg.vh                         ##
#######################################################################################

cat << EOF > $VCFGFN
\`ifndef __FMPRAM_CFG_VH__
\`define __FMPRAM_CFG_VH__

// total write ports number
\`define nW $nW

// total read  ports number 
\`define nR $nR

// total switched and fixed write/read port pairs
\`define nP $nP
EOF

echo -ne "\n// port configtaion as a text for taging\n\`define portTag \"" >> $VCFGFN
for (( pi = 0 ; pi < nP  ; pi++ )) ; do
  echo -n "${wP[$pi]}-${rP[$pi]}" >> $VCFGFN
  (( pi < nP-1 )) && echo -n "." >> $VCFGFN
done
echo "\"" >> $VCFGFN

echo -ne "\n// number of write ports for each pair\n\`define nWP(n) " >> $VCFGFN
for (( pi = 0 ; pi < nP  ; pi++ )) ; do
  (( pi > 0 )) && echo -n "               " >> $VCFGFN
  echo -n "( ((n)==$pi) ? ${wP[$pi]}" >> $VCFGFN
  ((pi < nP-1)) && echo " : \\"  >> $VCFGFN
done
echo " : 0 $(repeat " )" $nP)" >> $VCFGFN 

echo -ne "\n// number of read ports for each pair\n\`define nRP(n) " >> $VCFGFN
for (( pi = 0 ; pi < nP  ; pi++ )) ; do
  (( pi > 0 )) && echo -n "               " >> $VCFGFN
  echo -n "( ((n)==$pi) ? ${rP[$pi]}" >> $VCFGFN
  ((pi < nP-1)) && echo " : \\" >> $VCFGFN
done
echo " : 0 $(repeat " )" $nP)" >> $VCFGFN

echo -e '\n`endif //__FMPRAM_CFG_VH__' >> $VCFGFN

