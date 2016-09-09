 #!/bin/sh
 # -*- mode: tcl; tab-width: 4; coding: iso-8859-1 -*-
 # Restart with tcl:  \
 exec wish $0 ${1+"$@"}

  package require Tk

  array set S { np 1  w1 1   x2 50  w2  8 \
                t1 500 title "Neuronal Processing" \
                s1 0   s2 0  sum 0  out 0 }

  set nP     1
  set nP_prv 0
  set nW(0)  0
  set nR(0)  0

  set WP(0) 0 
  set RP(0) 0
  set pi 0

  array set G { offX 20 offY 20 maxP 8 maxW 8 maxR 8 sclW 60 sclL 90 plineL 100 pboxW 50} 

  proc int x { expr int($x) }

  proc Calc x {
  #: Calculate results + update display
    global S

    set S(s1)  [expr {$S(x1) * $S(w1)} ]
    set S(s2)  [expr {$S(x2) * $S(w2)} ]
    set S(sum) [expr {$S(s1) + $S(s2)} ]
    set S(out) [expr {$S(sum) >= $S(t1)} ]
    if { $S(out) } {
      .c itemconfig out -fill red
    } else {
      .c itemconfig out -fill cyan
    }
  }


  proc Prn x {
    puts "========="
    global nP
    global nP_prv
    global nW
    global nR
    global S
    global G
    global WP
    global pi

    # add ports
    if { $nP > $nP_prv } {
      for { set pi $nP_prv}  {$pi < $nP} {incr pi} {
         puts "adding of pi nP nP_prv: $pi $nP $nP_prv"
         scale .c.wp$pi -from 0 -to $G(maxW) -variable nW($pi) -command {addLines $nP} -length $G(sclL) -label "w$pi"  
         .c create window $G(offX) [expr $G(offY)+($pi+1)*$G(sclL)] -window .c.wp$pi -anchor nw
         scale .c.rp$pi -from 0 -to $G(maxR) -variable nR($pi) -command {addLines $nP} -length $G(sclL) -label "r$pi"  
         .c create window [expr $G(offX)+$G(sclW)+$G(sclL)+2*$G(plineL)] [expr $G(offY)+($pi+1)*$G(sclL)] -window .c.rp$pi -anchor nw
      }
      incr pi -1
    }
    # delete ports
    if { $nP < $nP_prv } {
      for { set i $nP}  {$i < $nP_prv} {incr i} {
        puts "destroying of i nP nP_prv: $i $nP $nP_prv"
        destroy  .c.wp$i
        destroy  .c.rp$i
        set nW($i) 0
      }
      addLines $nP x
    }

    set nP_prv $nP

  }

  proc addLines {x y} {
    global S
    global G
    global nW
    global nR

    # delete old graphics for this ports to redraw it
    .c delete wlines
    .c delete pboxes
    .c delete rlines
    for { set p 0}  {$p < $x} {incr p} {
      puts "Adding lines for port $p"
        # ceate write port arrows
        for { set w 1}  {$w <= $nW($p)} {incr w} {
          set h [expr $G(offY)+$G(sclL)*($p+1)+$w*($G(sclL)/($nW($p)+1))]
          puts ==$h
          .c create line [expr $G(offX)+$G(sclW)] $h [expr $G(offX)+$G(sclW)+$G(plineL)] $h -width 5 -arrow last -tag wlines
        }
        # create port box
        set pboxX [expr $G(offX)+$G(sclW)+$G(plineL)]
        set pboxY [expr $G(offY)+$G(sclL)*($p+1)]
        .c create rectangle $pboxX $pboxY [expr $pboxX+$G(sclL)] [expr $pboxY+$G(sclL)] -width 3 -tag pboxes
        if { $p > 0} {
          .c create line $pboxX $pboxY [expr $pboxX+$G(sclL)] [expr $pboxY+$G(sclL)] -width 2 -tag pboxes
        }
        # create read port arrows
        for { set r 1}  {$r <= $nR($p)} {incr r} {
          set h [expr $G(offY)+$G(sclL)	+$G(sclL)*$p+$r*($G(sclL)/($nR($p)+1))]
          puts ==$h
          .c create line [expr $G(offX)+$G(sclW)+$G(sclL)+$G(plineL)] $h [expr $G(offX)+$G(sclW)+$G(sclL)+2*$G(plineL)] $h -width 5 -arrow last -tag wlines
        }
    }
  }

  proc precompArgs {} {
    global nP
    global nW
    global nR
    set list pArgs
    for {set p 0} {$p < $nP} {incr p} {
      lappend pArgs $nW($p) $nR($p)
    }
    return $pArgs
  }

  proc compute {} {
    global G
    eval exec ./precomp.sh fmpram [precompArgs] >&@stdout
    set dfgImg [image create photo imgobj1 -file "./fmpram.dfg.gif"]
    set schImg [image create photo imgobj2 -file "./fmpram.sch.gif"]
   .c create image [expr 2*$G(offX)+2*$G(sclW)+$G(sclL)+2*$G(plineL)] $G(offY) -anchor nw -image $dfgImg
   .c create image [expr 2*$G(offX)+2*$G(sclW)+$G(sclL)+2*$G(plineL)+500] $G(offY) -anchor nw -image $schImg

  }

  proc Init {} {
  #: Build GUI
    global S
    global G
    global nP

#    set canH [expr 2*$G(offX)+($G(maxP)+1)*$G(sclL)]
     set canH 2000
    wm title . "Multi-ported Memory"
    canvas .c -relief raised  -borderwidth 0  -height $canH -width 3000  -bg white
    pack   .c

    option add *Scale.highlightThickness 0
    option add *Scale.orient vertical
    option add *Scale.relief ridge
    option add *Entry.relief sunken



    scale .c.nP -from 1 -to $G(maxP) -variable nP -command Prn -orient horizontal -length $G(sclL) -label "nP"
    .c create window [expr $G(offX)+$G(plineL)+$G(sclW)] $G(offY) -window .c.nP -anchor nw

    button  .c.b0 -text "Compute" -command compute
    .c create window [expr $G(offX)] [expr $G(offY)] -window .c.b0 -anchor nw

  }

  proc Init2 {} {
  #: Build GUI
    global S

    wm title . "Neuro1"
    canvas .c -relief raised  -borderwidth 0  -height 400  -width 560  -bg white
    pack   .c

    option add *Scale.highlightThickness 0
    option add *Scale.orient vertical
    option add *Scale.relief ridge
    option add *Entry.relief sunken

    scale .c.sx1 -from 100 -to    0 -variable S(x1) -command Calc -label "x1"  
    scale .c.sx2 -from 100 -to    0 -variable S(x2) -command Calc -label "x2"  
    scale .c.sw1 -from  10 -to    0 -variable S(w1) -command Calc -label "w1"  
    scale .c.sw2 -from  10 -to    0 -variable S(w2) -command Calc -label "w2"  
    scale .c.st1 -from   0 -to 2000 -variable S(t1) -command Calc -label "Threshold" -orient horizontal 

    entry .c.es1 -width 5 -textvar S(s1)  -state readonly
    entry .c.es2 -width 5 -textvar S(s2)  -state readonly
   #entry .c.es3 -width 5 -textvar S(sum) -state readonly  ;##
    scale .c.ss3 -from 2000 -to   0 -variable S(sum) -length 200 -sliderlength 5 -state disabled -bg green2
    entry .c.es4 -width 3 -textvar S(out) -state readonly

    .c create text   280  20          -text $S(title) -font {Times 24 bold}

    .c create text    12  80          -text "Input 1"   -anchor w
    .c create line    30 100  310 100 -width 5 -arrow last
    .c create window  50  50          -window .c.sx1    -anchor nw
    .c create window  50 200          -window .c.sx2    -anchor nw
    .c create window 240  75          -window .c.es1    -anchor w

    .c create text    12 230          -text "Input 2"   -anchor w
    .c create line    30 250  310 250 -width 5 -arrow last
    .c create window 150  50          -window .c.sw1    -anchor nw
    .c create window 150 200          -window .c.sw2    -anchor nw
    .c create window 240 225          -window .c.es2    -anchor w

    .c create text   160 315          -text "Weight"    -anchor w

    .c create window 275 320          -window .c.st1    -anchor nw
    .c create line   350 320  350 300 -width 1 -arrow last

    .c create oval   300  50  400 300 -width 3 -fill green2
    .c create text   350  65          -text "Sum"
    .c create window 350 175          -window .c.ss3  ;## .c.es3 / .c.ss3
    .c create line   400 175  450 175 -width 5 -arrow last

    .c create oval   450 125  530 225 -width 3 -tag out
    .c create text   490 150          -text "Output"
    .c create window 490 175          -window .c.es4

    # Debug: show cursor-position :
   #bind .c <Motion>  {wm title . [int [%W canvasx %x]],[int [%W canvasy %y]]}
  }




  Init
  return

