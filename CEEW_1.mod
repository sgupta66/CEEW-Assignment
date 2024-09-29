######################################################################
#   bus_type = 0  Neither First Nor Last Bus
#   bus_type = 2  End Bus
#   bus_type = 1  slack/reference bus (Start Bus)
######################################################################

#################################################################################
########  DEFINE THE AMPL MODEL FOR DERs AGGREGATION AT COMMUNITY LEVEL  ########
#################################################################################
reset;

#---- DECLARE SETS
#---- DECLARE SPACE FOR UP TO 4000 BUSES.
set BUS;                                                # set of buses
set T = 1..288 by 1;
set NIL = 1..500 by 1;
set OT = 1..5 by 1;

set TBUS within T cross BUS;

set NILOTB within NIL cross OT cross BUS;
set BRANCH within {1..4000} cross BUS cross BUS;        # set of branches

#---- DECLARE ITEMS TO BE READ FROM THE .bus DATA FILE.
param bus_type       {BUS};
param bus_voltage0   {BUS};


#---- DECLARE ITEMS TO BE READ FROM THE .ILOTB DATA FILE.
param bus_p_nil0     {NILOTB};
param nil_t_req      {NILOTB};
param niltot_t_req   {NILOTB};
param nil_t_st	     {NILOTB};
param nil_t_end      {NILOTB};

#---- DECLARE ITEMS TO BE READ FROM THE .branch DATA FILE.
param branch_r       {BRANCH};
param branch_x       {BRANCH};
param bus_p_flow0    {BRANCH};
param bus_q_flow0    {BRANCH};

#---- DEFINE PARAMETER LIMITS ON VOLTAGES, AND POWER GENERATION.
#---- LIMIT VALUES ARE SET LATER IN THE "data" SECTION.
param bus_voltage_min;
param bus_voltage_max;

#---- DECLARE VARIABLES, WITH UPPER AND LOWER BOUNDS.
var bus_voltage {t in T, i in BUS} >= (bus_voltage_min)^2,
				   <= (bus_voltage_max)^2;
var bus_p_flow {t in T, (l,k,m) in BRANCH};
var bus_q_flow {t in T, (l,k,m) in BRANCH};
var branch_current {t in T, (l,k,m) in BRANCH};

var nil_st {t in T, (s,j,i) in NILOTB} binary;

#---- OBJECTIVE FUNCTION.
var p_grid {t in T} = sum{(l,k,m) in BRANCH: l == 1} bus_p_flow[t,l,k,m]*10^3;
minimize supply: sum{t in T} p_grid[t];

#---- AC POWER FLOW BALANCE EQUATIONS (NONLINEAR CONSTRAINTS).

subject to p_flow_1 {t in T, (l,k,m) in BRANCH : bus_type[m] == 2}:
  bus_p_flow[t,l,k,m] - sum{(s,j,m) in NILOTB} bus_p_nil0[s,j,m]*nil_st[t,s,j,m]
		    - (branch_r[l,k,m] * branch_current[t,l,k,m]) = 0;

subject to p_flow {t in T, (l,k,m) in BRANCH : bus_type[m] != 2}:
  bus_p_flow[t,l,k,m] - sum{(s,j,m) in NILOTB} bus_p_nil0[s,j,m]*nil_st[t,s,j,m]
		    - (branch_r[l,k,m] * branch_current[t,l,k,m])
                    - sum{(j,m,i) in BRANCH} (bus_p_flow[t,j,m,i]) = 0;

subject to q_flow_1 {t in T, (l,k,m) in BRANCH : bus_type[m] == 2}:
  bus_q_flow[t,l,k,m] - (branch_x[l,k,m] * branch_current[t,l,k,m]) = 0;

subject to q_flow {t in T, (l,k,m) in BRANCH : bus_type[m] != 2}:
  bus_q_flow[t,l,k,m] - (branch_x[l,k,m] * branch_current[t,l,k,m])
                    - sum{(j,m,i) in BRANCH} (bus_q_flow[t,j,m,i]) = 0;

subject to V_bus {t in T, (l,k,m) in BRANCH}:
  bus_voltage[t,k] - bus_voltage[t,m] - (2*(branch_r[l,k,m] * bus_p_flow[t,l,k,m]))
                    - (2*(branch_x[l,k,m] * bus_q_flow[t,l,k,m])) + ((branch_r[l,k,m]^2 + branch_x[l,k,m]^2)
                    * branch_current[t,l,k,m]) = 0;

subject to I_flow {t in T, (l,k,m) in BRANCH}:
  ((bus_p_flow[t,l,k,m]^2 + bus_q_flow[t,l,k,m]^2)/bus_voltage[t,k]) - (branch_current[t,l,k,m]) = 0;

#---- NON-INTRUPTIBLE SHIFTABLE LOAD CONSTRAINTS

subject to nil_status {t in T, (s,j,i) in NILOTB}:
  nil_st[t,s,j,i] = if (nil_t_st[s,j,i] <= t <= nil_t_end[s,j,i]) then
		nil_st[t,s,j,i] else 0;

subject to nil_exe {(s,j,i) in NILOTB}:
  sum{t in T} nil_st[t,s,j,i] - nil_t_req[s,j,i] = 0;
  
#subject to nil_seq {t in T, (s,j,i) in NILOTB}:
#  sum{x in 1..t-1, y in 1..j-1} nil_st[x,s,y,i] - sum{y in 1..j-1} nil_t_req[s,y,i]*nil_st[t,s,j,i] >= 0;

#subject to nil_non_int {t in T, (s,j,i) in NILOTB: t < (nil_t_end[s,j,i] - niltot_t_req[s,j,i])}:
#  sum{x in t+1..(t+nil_t_req[s,j,i])} nil_st[x,s,j,i] - nil_t_req[s,j,i]*(nil_st[t+1,s,j,i] - nil_st[t,s,j,i]) >= 0;

subject to nil_status_count {t in T}:
  sum{(s,j,i) in NILOTB} nil_st[t,s,j,i] - 16 <= 0;

subject to power_flow{t in T, (l,k,m) in BRANCH}:
  sum{(s,j,m) in NILOTB} bus_p_nil0[s,j,m]*nil_st[t,s,j,m] - 60/10^3 <= 0;

#---- AUXILIARY VARIABLES, USED ONLY FOR PRINTING OUT RESULTS.
var bus_vm {t in T, i in BUS};      # Bus voltage magnitude

######################################################################
#  SET THE PARAMETRIC DATA
######################################################################
data;

param: BUS: bus_type bus_voltage0 := 
1	1	1.0000
2	2	1.0000;

param: NILOTB: bus_p_nil0 nil_t_req niltot_t_req nil_t_st nil_t_end:= include Load.txt;

param: BRANCH: branch_r branch_x bus_p_flow0 bus_q_flow0 := 
1	1	2	0.002545703	0.002580752	0.00	0.00;

#---- VOLTAGES LIMITS:
param bus_voltage_min :=  0.95;
param bus_voltage_max :=  1.05;

#----SCALE AND INITIALIZE THE DATA.

for{t in T, i in BUS}
{
   let bus_voltage[t,i] := bus_voltage0[i];
};

for {(s,j,i) in NILOTB}
{
   let bus_p_nil0[s,j,i] := bus_p_nil0[s,j,i]/10^3;
};

for{t in T, (l,k,m) in BRANCH}
{
   let bus_p_flow[t,l,k,m] := bus_p_flow0[l,k,m];
   let bus_q_flow[t,l,k,m] := bus_q_flow0[l,k,m];
};

#---- FREEZE THE REFERENCE BUS VOLTAGE TO ONE
fix {t in T, i in BUS : bus_type[i] == 1}
 bus_voltage[t,i];

######################################################################
#  SOLVE THE PROBLEM AND PRINT RESULTS
######################################################################

#---- ASSUME THE USER HAS DEFINED solver=knitroampl BEFORE STARTING AMPL.
#---- ON WINDOWS, ASSUMING A DEFAULT INSTALLATION, THE COMMAND IS:
#----   set solver=knitro-5.1.1-student-WinMSVC71\knitroampl\knitroampl

#---- INVOKE KNITRO TO SOLVE THE PROBLEM.
printf "\nCalling the nonlinear optimization solver:\n\n";
option knitro_options "outlev=1 alg=1";
solve;

printf "\nKNITRO is complete, writing report to 'RES_CEEW_1.txt' \n\n";

for {t in T, i in BUS}
 {
   let bus_vm[t,i] := sqrt(bus_voltage[t,i]);
 };

printf "total_solve_time  %6.3f sec\n",_total_solve_time >> RES_CEEW_1.txt;
printf "************************************************\n\n">> RES_CEEW_1.txt;

printf "total Power Supplied  %6.3f kW\n", sum{t in T} p_grid[t] >> RES_CEEW_1.txt;

printf "*************************************************\n">> RES_CEEW_1.txt;

for {t in T: 96<= t <= 144}
{
 printf "----------------------Hour = %2d-----------------\n", t>> RES_CEEW_1.txt;
 printf "*************************************************\n\n">> RES_CEEW_1.txt;
 printf "Hourly power supplied %8.2f kW\n", p_grid[t] >> RES_CEEW_1.txt;
}
 for {t in T: 168 <= t <= 288}
{
 printf "----------------------Hour = %2d-----------------\n", t>> RES_CEEW_1.txt;
 printf "*************************************************\n\n">> RES_CEEW_1.txt;
 printf "Hourly power supplied %8.2f kW\n", p_grid[t] >> RES_CEEW_1.txt;
}

printf "\n\n*************************************************\n\n">> RES_CEEW_1.txt;

 for {t in T: 96<= t <= 144}
{
 printf " %10.2f \n", p_grid[t] >> RES_CEEW_1.txt;
}
for {t in T: 168 <= t <= 288}
{
 printf " %8.2f \n", p_grid[t] >> RES_CEEW_1.txt;
}