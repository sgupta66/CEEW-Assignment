######################################################################
#  DEFINE THE AMPL MODEL FOR DSM SRATEGIES USING E-BUS
######################################################################
reset;

#---- DECLARE SPACE FOR UP TO 4000 E-BUS.

set EBUS := {1..70};	         # Number of E-Buses
set T := {1..288};		 # Time Intervals (24 hours*60 minutes)

##-----------------------------------##
##-------- DEFINE PARAMETERS --------##
##-----------------------------------##

#---- Charging Windows
param morning_dep{i in EBUS} = floor(Uniform(12,24));		# 7-8 AM
param morning_ret{i in EBUS} = floor(Uniform(96,132));		# 1-4 PM
param morning_charge_end{i in EBUS} = 144;			# 5 PM

param evening_dep{i in EBUS} = floor(Uniform(132,144));		# 4-5 PM
param evening_ret{i in EBUS} = floor(Uniform(168,216));		# 7-11 PM
param evening_charge_end{i in EBUS} = 288;			# 5 AM next day

#---- Battery Parameters
param SoC_initial{i in EBUS} = 100;				# Intial SoC (Assumed: As they are fully charged at time of start of day)
param battery_cap_kwh{i in EBUS} = 260;				# Battery Capacity (Given)
param SoC_final{i in EBUS} = 100;				# Final SoC (Assumed: As they are fully charged at the time of departure)

#---- Energy Consumption Parameters (Assume)
param min_trip_ener_kWh{i in EBUS} = 80;		# Minimum energy consumed per trip
param max_trip_energy_kWh{i in EBUS} = 180;		# Maximum energy consumed per trip
param morning_trip_energy{i in EBUS} = Uniform(80,180);	# Energy consumed during day-trip
param evening_trip_energy{i in EBUS} = Uniform(80,180);	# Energy consumed during evening-trip

#----Charger Parameters
param charger_eff = 0.9;				# Charger efficiency (Assume 90%)
param charger_power = 240;				# Each charger rating is 240 kW (Given)
param charger_number = 16;				# Maximum number of Chagrers available

#---- State Of Charge Variability
param morning_SoC_ret{i in EBUS} = SoC_initial[i] - ((morning_trip_energy[i]/battery_cap_kwh[i])*100);	# SoC upon return for charging during day-time
param morning_energy_req{i in EBUS} = (75 - morning_SoC_ret[i]) / 100 * (battery_cap_kwh[i] / charger_eff); # Energy required during day-time charging
param morning_ch_t_req{i in EBUS} = ceil((morning_energy_req[i]/charger_power)*12); # Total time required to charge ith E-BUS

param evening_SoC_ret{i in EBUS} = SoC_initial[i] - ((evening_trip_energy[i]/battery_cap_kwh[i])*100);	# SoC upon return for charging during evening-time
param evening_energy_req{i in EBUS} = (100 - evening_SoC_ret[i]) / 100 * (battery_cap_kwh[i] / charger_eff); # Energy required during evening-time charging
param evening_ch_t_req{i in EBUS} = ceil((evening_energy_req[i]/charger_power)*12); # Total time required to charge ith E-BUS


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

printf "\nKNITRO is complete, writing report to 'Res_CEEW.txt' \n\n";

printf "EBUS      MorningReturn      MorningChargeEnd      MorSoCReturn     MorSoCDesired     MorChargetimereq \n">> Res_CEEW.txt;
for{i in EBUS}
	 {
	   printf "%4d %14d %15d %14.2f %14.2f %14.2f \n",
		  i, morning_ret[i], morning_charge_end[i], morning_SoC_ret[i], morning_energy_req[i], morning_ch_t_req[i]  >> Res_CEEW.txt;
	 };

printf "-------------------------------------------------------------------------------\n">> Res_CEEW.txt;
printf "-------------------------------------------------------------------------------\n\n">> Res_CEEW.txt;
printf "EBUS      EveningReturn      EveningChargeEnd      EveSoCReturn    EveSoCDesired      EveChargetimereq \n">> Res_CEEW.txt;
for{i in EBUS}
	 {
	   printf "%4d %14d %15d %14.2f %14.2f %14.2f \n",
		  i, evening_ret[i], evening_charge_end[i], evening_SoC_ret[i], evening_energy_req[i], evening_ch_t_req[i]  >> Res_CEEW.txt;
	 };

printf "-------------------------------------------------------------------------------\n">> Res_CEEW.txt;
printf "-------------------------------------------------------------------------------\n\n">> Res_CEEW.txt;