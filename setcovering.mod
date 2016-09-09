# SETS
set I;
set J;

#PARAMS

param c{J};
param a{I,J};

# VARS

var x{j in J} binary >=0;

# OBJECTIVE FUNCTION

minimize cost:
  sum{j in J} c[j] * x[j];

# CONSTRAINTS

subject to nutrients{i in I}:
  sum{j in J} a[i,j] * x[j] >= 1;

solve;

#printf "Optimal cover has total weight: %d\n",
#   sum{j in J} c[j] * x[j];

#printf "\nSets:\n";
printf{j in J: x[j]} "%s\n", j;
#printf "\n";




end;
