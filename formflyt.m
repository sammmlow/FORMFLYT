%% #######################################################################
% ########################################################################
% ###                                                                  ###
% ###     LUMELITE ORBIT DYNAMICS AND CONTROL FOR FORMATION FLYING     ###
% ###     ========================================================     ###
% ###     By Matthew Lo, Andrew Ng, Samuel Low, and Dr Poh Eng Kee     ###
% ###                                                                  ###
% ###                                                                  ###
% ########################################################################
% ########################################################################

clc 
clear 
close all


%% USER INPUTS

% Specify the number of satellites.
numSats = 3;
%days = 20;
days = 6;
% Specify the duration and the time step of the dynamics simulation (s).
tt = days * 86400;
dt = 1.0;
time_steps= linspace(0, tt, tt/dt+1);
% Specify thruster burn mode intervals (hot = firing, cool = cool-down).
duration_hot  = 300.0;   % About 300s of burn time
duration_cool = 28500.0; % About 5 orbits of cool down

% Specify fire duration 
duration_fire = 240.0;
% Specify the thruster's average force (N)
thrust = 0.760;
g0=9.80665;
Isp = 220; %s, from nanoavionics EPSS engine specs
fuel_consumption = thrust / (Isp * g0); %kg/s
% Initialise the pointing error DCM. Note that in the dynamics loop, this
% pointing error DCM should be re-initialised in each loop as a random
% variable to simulate the pointing error of the spacecraft thruster.
pointing_error_DCM = eye(3);


% Specify Satellite 2's RIC geometry requirements and tolerances (m)
desired_R2 = 0.0;       % Desired radial separation of Sat 2
desired_I2 = -100000.0; % Desired in-track separation of Sat 2
desired_C2 = 42000.0;   % Desired cross-track separation of Sat 2

% Specify Satellite 3's RIC geometry requirements and tolerances (m)
desired_R3 = 0.0;       % Desired radial separation of Sat 3
desired_I3 = -200000.0; % Desired in-track separation of Sat 3
desired_C3 = 0.0;       % Desired cross-track separation of Sat 3

% Specify the formation geometry tolerance (m)
tolerance_R = 1000.0;
tolerance_I = 1000.0;
tolerance_C = 1000.0;

% Toggle the following perturbation flags (0 = False, 1 = True).
f_J2 = 1; % Enable / disable J2
f_Dg = 0; % Enable / disable drag

% Toggle following flags to set initial conditions of satellites (0 =
% already in final formation, 1 = in initial formation)
f_initial = 1;

%% Read data from STK Astrogator
folder_path=".\data_STK_astrogator\Processed_data";
lumelite2_data=readtable(folder_path+"\original\Lumelite2_final_summary.xlsx", "VariableNamingRule","preserve");
lumelite3_data=readtable(folder_path+"\original\Lumelite3_final_summary.xlsx", "VariableNamingRule","preserve");
%lumelite2_data=readtable(folder_path+"\after normalisation\Lumelite2_final_summary.xlsx", "VariableNamingRule","preserve");
%lumelite3_data=readtable(folder_path+"\after normalisation\Lumelite3_final_summary.xlsx", "VariableNamingRule","preserve");


lumelite2_true_ephem = readtable(folder_path+"\Lumelite2_ground_truth.csv", "VariableNamingRule","preserve");
lumelite3_true_ephem = readtable(folder_path+"\Lumelite3_ground_truth.csv", "VariableNamingRule","preserve");

%Example to extract column--> lumelite2_data{:, column_name};


%% Initial conditions for satellites
% Input the initial osculating orbit elements for Satellite 1.
a1  = 6925140;     % Semi-major axis (m) = 585E03 + 6371E03 
e1  = 0.001;       % Eccentricity (unitless)
i1  = 10.00;       % Inclination (degrees)
w1  = 0.00;        % Arg of Periapsis (degrees)
R1  = 70.00;       % Right Ascension (degrees)
M1  = 46.654;      % Mean Anomaly (degrees)
Cd1 = 2.2;         % Drag coefficient
Ar1 = 0.374;       % Drag area (m^2)
Ms1 = 17.90;       % Spacecraft mass (kg)
Th1 = 0.00;        % Spacecraft thrust force (N)

if f_initial == 0
    % Input the initial osculating orbit elements for Satellite 2.
    a2  = 6925140;     % Semi-major axis (m)
    e2  = 0.001;       % Eccentricity (unitless)
    i2  = 10.00;       % Inclination (degrees)
    w2  = 0.00;        % Arg of Periapsis (degrees)
    R2  = 72.00;       % Right Ascension (degrees)
    M2  = 43.925 ;     % Mean Anomaly (degrees)
    Cd2 = 2.2;         % Drag coefficient
    Ar2 = 0.374;       % Drag area (m^2)
    Ms2 = 17.90;       % Spacecraft mass (kg)
    Th2 = [0 0 0];     % Spacecraft thrust force vector(N)
    
    % Input the initial osculating orbit elements for Satellite 3.
    a3  = 6925140;     % Semi-major axis (m)
    e3  = 0.001;       % Eccentricity (unitless)
    i3  = 10.00;       % Inclination (degrees)
    w3  = 0.00;        % Arg of Periapsis (degrees)
    R3  = 70.00;       % Right Ascension (degrees)
    M3  = 44.996;      % Mean Anomaly (degrees)
    Cd3 = 2.2;         % Drag coefficient
    Ar3 = 0.374;       % Drag area (m^2)
    Ms3 = 17.90;       % Spacecraft mass (kg)
    Th3 = [0 0 0];     % Spacecraft thrust force vector(N)
    
else
    a2  = 6925140;     % Semi-major axis (m)
    e2  = 0.001;       % Eccentricity (unitless)
    i2  = 10.00;       % Inclination (degrees)
    w2  = 0.00;        % Arg of Periapsis (degrees)
    R2  = 70.00;       % Right Ascension (degrees)
    M2  = 29.876 ;     % Mean Anomaly (degrees)
    Cd2 = 2.2;         % Drag coefficient
    Ar2 = 0.374;       % Drag area (m^2)
    Ms2 = 17.90;       % Spacecraft mass (kg)
    Th2 = [0 0 0];        % Spacecraft thrust force (N)
    
    % Input the initial osculating orbit elements for Satellite 3.
    a3  = 6925140;     % Semi-major axis (m)
    e3  = 0.001;       % Eccentricity (unitless)
    i3  = 10.00;       % Inclination (degrees)
    w3  = 0.00;        % Arg of Periapsis (degrees)
    R3  = 70.00;       % Right Ascension (degrees)
    M3  = 11.39;      % Mean Anomaly (degrees)
    Cd3 = 2.2;         % Drag coefficient
    Ar3 = 0.374;       % Drag area (m^2)
    Ms3 = 17.90;       % Spacecraft mass (kg)
    Th3 = [0 0 0];        % Spacecraft thrust force (N)
    
end
    
% ########################################################################
% ########################################################################

%% HOUSEKEEPING OF MATLAB FILE PATHS

[directory, ~, ~]  = fileparts( mfilename('fullpath') );
paths = {[ directory '\library\formflyt_forces' ]; ...
         [ directory '\library\formflyt_numint' ]; ...
         [ directory '\library\formflyt_orbits' ]; ...
         [ directory '\library\formflyt_planet' ]; ...
         [ directory '\library\formflyt_rotate' ]};

for n = 1 : length( paths )
    addpath( string( paths(n) ) );
end

% ########################################################################
% ########################################################################

%% INITIALISATION OF ALL ORBIT STATES

% Initialise the gravitational constant and planet radius.
GM = 3.9860e+14;
RE = 6378140.00;

% Position, velocity, acceleration and true anomaly in ECI coords.
[pos1, vel1, acc1, nu1] = kepler_states(a1, e1, i1, R1, w1, M1, GM);
[pos2, vel2, acc2, nu2] = kepler_states(a2, e2, i2, R2, w2, M2, GM);
[pos3, vel3, acc3, nu3] = kepler_states(a3, e3, i3, R3, w3, M3, GM);

% Initialise the total number of samples.
nSamples = floor( tt / dt ) + 1;

% Initialise the position arrays 
pos1a      = zeros( nSamples, 3 );
pos1a(1,:) = pos1; % Initial position of LEO1
pos2a      = zeros( nSamples, 3 );
pos2a(1,:) = pos2; % Initial position of LEO2
pos3a      = zeros( nSamples, 3 );
pos3a(1,:) = pos3; % Initial position of LEO3

% Initialise the velocity arrays 
vel1a      = zeros( nSamples, 3 );
vel1a(1,:) = vel1; % Initial velocity of LEO1
vel2a      = zeros( nSamples, 3 );
vel2a(1,:) = vel2; % Initial velocity of LEO2
vel3a      = zeros( nSamples, 3 );
vel3a(1,:) = vel3; % Initial velocity of LEO3

% Initialise the relative position arrays of LEO2 and LEO3
posRIC2a = zeros( nSamples, 3 );
posRIC3a = zeros( nSamples, 3 );

% Initialise the estimated Keplerian orbit period of LEO1 (for reference)
orbT = sqrt(( 4 * (pi^2) * (a1^3) ) / GM);
recharge_time = 5 * orbT; %5 orbits needed to recharge for next firing. 
% ########################################################################
% ########################################################################

%% Main dynamics loop using an RK4 numerical integrator below 
% It is assumed that Satellite 1 is the chief reference.

% Initialise an integer variable for thruster-mode count down.
thruster_clock_2 = 0;
thruster_clock_3 = 0;
next_fire_time_2 = 0;
next_fire_time_3 = 0;

%% Obtain the time schedule for both satellites

lum2_segment = lumelite2_data{:, "Segment Name"};
lum2_schedule = lumelite2_data{:,"Time from mission start (s)"};
lum2_segment_durations = lumelite2_data{:,"segment_duration"};
lum2_num_segments= size(lum2_segment, 1);
lum2_ismanuever = ~isnan(lumelite2_data{:, "Delta V (m/sec)"});
lum2_next_segment_start = 0;
Th2_total = zeros(3 , size(time_steps,2));

lum3_segment = lumelite3_data{:, "Segment Name"};
lum3_schedule = lumelite3_data{:,"Time from mission start (s)"};
lum3_segment_durations = lumelite3_data{:,"segment_duration"};
lum3_num_segments = size(lum3_segment, 1);
lum3_ismanuever = ~isnan(lumelite3_data{:, "Delta V (m/sec)"});
lum3_next_segment_start = 0;
Th3_total=zeros(3,size(time_steps,2));

%% BEGIN THE DYNAMICS LOOP
lum2_schedule_index=1;
lum3_schedule_index=1;

for N = 1 : nSamples
    
    % Fetch the current positions and velocities of the satellites.
    % Cartesian coords.
    p1 = pos1a(N,:);
    v1 = vel1a(N,:);
    p2 = pos2a(N,:);
    v2 = vel2a(N,:);
    p3 = pos3a(N,:);
    v3 = vel3a(N,:);
    
    % Compute the Hill Frame of Satellite 1 as a Direction Cosine Matrix
    h1 = cross(p1, v1);                   % Angular momentum vector
    r_hat = p1 / norm(p1);                % Local X-axis
    h_hat = h1 / norm(h1);                % Local Z-axis
    y_hat = cross(h_hat, r_hat);          % Local Y-axis
    hill_dcm = [ r_hat ; h_hat ; y_hat ]; % Hill DCM
    
    % Compute the RIC for Satellite 2 as feedback into the control loop.
    pRIC2 = hill_dcm * (p2-p1).';

    if isnan(pRIC2)
        disp("HALT!")
    end
    posRIC2a(N,:) = pRIC2;
    error_R2 = pRIC2(1) - desired_R2; % This should not exceed tolerance
    error_I2 = pRIC2(3) - desired_I2; % This should not exceed tolerance
    error_C2 = pRIC2(2) - desired_C2; % This should not exceed tolerance
    
    % Compute the RIC for Satellite 3 as feedback into the control loop.
    pRIC3 = hill_dcm * (p3-p1).';
    posRIC3a(N,:) = pRIC3;
    error_R3 = pRIC3(1) - desired_R3; % This should not exceed tolerance
    error_I3 = pRIC3(3) - desired_I3; % This should not exceed tolerance
    error_C3 = pRIC3(2) - desired_C3; % This should not exceed tolerance
    
    % ####################################################################
    % ####################################################################
    % RIC Notation:
    % X axis - radial
    % Z axis - cross track
    % Y axis - in track/ along track
    % ####################################################################
    % Conduct a check to see whether satellite 2 or 3 has already reached
    % the desired position using the error_R2, error_I2... variables. This
    % can determine when to stop thrusters from firing. 
    % if error_R3< tolerance_R
    % Do something ....
    
    % ####################################################################
    % KEEP TRACK OF WHETHER THRUSTER HAS ALREADY FIRED FOR >= 300 seconds. 
    % If so, thruster has to rest for 5 orbits. 
    % ####################################################################
    % Assume that orbital period of all 3 satellites are the same; effect
    % of radial displacement on period is negligible (~ E-13 which is tiny)
    current_time = (N-1) * dt;
    
    % Perform radial, in-track and cross-track corrections for satellite 2,
    % Th2. Control solution outputs the 1X3 Thrust vector 'Th2'.
    %% Manuever plan: 
    % Segment 1: Thruster burn in intrack direction to enter lower orbit.
    % Allocate 120s of burn.
    % Segment 2: Drift to catch reduce intrack separation to 100km.
    % Segment 3: Thruster burn against intrack direction to reenter higher
    % orbit. 120s of burn. 
    if current_time <= lum2_next_segment_start
        %Branch to keep the thrust vector as before.
    elseif current_time >= lum2_schedule(lum2_schedule_index) + lum2_segment_durations(lum2_schedule_index) 
        Th2=[0 0 0];
        lum2_schedule_index = lum2_schedule_index + 1;
        if lum2_schedule_index < lum2_num_segments - 1
            % Branch for mission segments up to last mission segment
            lum2_next_segment_start = lum2_schedule(lum2_schedule_index + 1);
        end
    end
    if lum2_ismanuever(lum2_schedule_index)==1
        % Fire thruster as this is a manuever.
        Th2 = [ lumelite2_data{lum2_schedule_index, "RIC X Thrust Component"} * thrust,...
                lumelite2_data{lum2_schedule_index, "RIC Y Thrust Component"} * thrust,...
                lumelite2_data{lum2_schedule_index, "RIC Z Thrust Component"} * thrust
            ];
    end
    
%     fprintf("Mission leg: %d, Current time: %d sec. Thrust vector: ", lum2_schedule_index, current_time)
%     disp(Th2)
%     fprintf("\n")
    Th2_total(:, N)=Th2';
    
%     if current_time < next_fire_time_2
%         % Branch to skip firing as the thruster is cooling down. Do
%         % nothing!
%     else
%         if thruster_clock_2 >= duration_hot
%             % Branch to determine when to next ignite thruster. 
%             thruster_clock_2 = 0;
%             next_fire_time_2 = current_time + duration_cool;
%         elseif thruster_clock_2 < 120
%             % Branch to ignite thruster. 
%             Th2 = thrust.*[0, -1,0];
%         end
%         thruster_clock_2 = thruster_clock_2 + dt;
%     end
    %#####################################################################
    % Repeat the process for satellite 3, Th3. Outputs thrust vector 'Th3'.
    
    %% Manuever plan for satellite 3: 
    % Segment 1: Propagate for 12 hours. 
    % Segment 2: Thruster burn against intrack direction to enter higher
    % orbit. 65s of burn. 
    % Segment 3: Drift to reduce intrack separation to 200km.
    % Segment 4: Thruster burn against intrack direction to reenter higher
    % orbit. 45s of burn.
    if current_time <= lum3_next_segment_start
        %Branch to keep the thrust vector as before.
    elseif current_time >= lum3_schedule(lum3_schedule_index) + lum3_segment_durations(lum3_schedule_index) 
        Th3=[0 0 0];
        lum3_schedule_index = lum3_schedule_index + 1;
        if lum3_schedule_index < lum3_num_segments - 1
            % Branch for mission segments up to last mission segment
            lum3_next_segment_start = lum3_schedule(lum3_schedule_index + 1);
        end
    end
    if lum3_ismanuever(lum3_schedule_index)==1
        % Fire thruster as this is a manuever.
        Th3 = [ lumelite3_data{lum3_schedule_index, "RIC X Thrust Component"} * thrust,...
                lumelite3_data{lum3_schedule_index, "RIC Y Thrust Component"} * thrust,...
                lumelite3_data{lum3_schedule_index, "RIC Z Thrust Component"} * thrust
            ];
    end
    
%     fprintf("Mission leg: %d, Current time: %d sec. Thrust vector: ", lum3_schedule_index, current_time)
%     disp(Th3)
%     fprintf("\n")
    Th3_total(:, N)=Th3';
%     if current_time < next_fire_time_3
%         % Branch to skip firing as the thruster is cooling down. Do
%         % nothing!
%     else
%         % Branch to ignite thruster. 
%         
%         if thruster_clock_3 >= 300
%             thruster_clock_3 =0;
%             next_fire_time_3 = current_time + orbT;
%         else
%             
%         end
%         thruster_clock_3 = thruster_clock_3 + dt;
%     end
    % MAIN INTEGRATOR BELOW.
    
    % You should not need to change anything below in the propagator, your
    % control solution above should only affect the values of the thrust
    % vectors `Th1`, `Th2`, `Th3`.
    
    % Runge-Kutta 4th Order (RK4) Propagator (3/8 Rule Variant).
    % This code below is meant to only propagate LEO 1.
    [p1f, v1f] = prop_RK4_38( dt, p1, v1, Cd1, Ar1, Ms1, f_J2, f_Dg, Th1 );
    pos1a(N+1,:) = p1f;
    vel1a(N+1,:) = v1f;
    
%     if N==153
%         disp("HALT!")
%     end
    % Runge-Kutta 4th Order (RK4) Propagator (3/8 Rule Variant).
    % This code below is meant to only propagate LEO 2.
    [p2f, v2f] = prop_RK4_38( dt, p2, v2, Cd2, Ar2, Ms2, f_J2, f_Dg, Th2 );
    pos2a(N+1,:) = p2f;
    vel2a(N+1,:) = v2f;
    
    % Runge-Kutta 4th Order (RK4) Propagator (3/8 Rule Variant).
    % This code below is meant to only propagate LEO 3.
    [p3f, v3f] = prop_RK4_38( dt, p3, v3, Cd3, Ar3, Ms3, f_J2, f_Dg, Th3 );
    pos3a(N+1,:) = p3f;
    vel3a(N+1,:) = v3f;
    
end
%% Check that instantaneous thrust is equal to the thrust value, because it fires at a constant Isp. 
[instant_thrust_2, fire_indices_2] = instantaneous_thrust_when_firing(Th2_total);
[instant_thrust_3, fire_indices_3] = instantaneous_thrust_when_firing(Th3_total);
fprintf("sat 2 intrack: %f km\n", posRIC2a(1,3)/1000)
fprintf("sat 3 intrack: %f km", posRIC3a(1,3)/1000)

%% Process the ground truth for plotting
true_ephem_time_steps_2 = lumelite2_true_ephem.('Time from mission start (s)');
true_ephem_time_steps_3 = lumelite3_true_ephem.('Time from mission start (s)');

%% PLOT THE RADIAL, INTRACK, CROSS-TRACK OF SATELLITE 2 WRT 1
fh=figure(1);
fh.WindowState = 'maximized';

box on
grid minor
hold on
radial_plot = plot(time_steps, posRIC2a(:,1), 'rx', 'MarkerSize', 5);
crosstrack_plot= plot(time_steps, posRIC2a(:,2), 'bx', 'MarkerSize', 5);
intrack_plot= plot(time_steps, posRIC2a(:,3), 'gx', 'MarkerSize', 5);

radial_plot_STK = plot(true_ephem_time_steps_2, lumelite2_true_ephem.('Radial (km)').*1000, 'r',  'LineWidth', 1);
crosstrack_plot_STK = plot(true_ephem_time_steps_2, lumelite2_true_ephem.('Cross-Track (km)').*1000, 'b', 'LineWidth', 1);
intrack_plot_STK = plot(true_ephem_time_steps_2, lumelite2_true_ephem.('In-Track (km)').* 1000, 'g',  'LineWidth', 1);


xline(43200)
xline(1252842.554)

set(gca,'FontSize',15)
xlabel('Time after ignition (s)','interpreter', 'latex', 'fontsize', 20, 'Rotation', 0)
ylabel('Distance','interpreter', 'latex', 'fontsize', 20, 'Rotation', 90)
title('Displacements of satellite 2 w.r.t 1', 'interpreter', 'latex', 'fontsize', 20, 'Rotation', 0)
L=legend([radial_plot crosstrack_plot intrack_plot radial_plot_STK ...
    crosstrack_plot_STK intrack_plot_STK], 'Radial', 'Cross-track', 'Intrack', ...
          'Radial STK', 'Cross-track STK', 'Intrack STK');
L.FontSize=15;

%% PLOT THE RADIAL, INTRACK, CROSS-TRACK OF SATELLITE 3 WRT 1
fh=figure(2);
fh.WindowState = 'maximized';

box on
grid minor
hold on

radial_plot = plot(time_steps, posRIC3a(:,1), 'rx', 'MarkerSize', 5);
crosstrack_plot = plot(time_steps, posRIC3a(:,2), 'bx', 'MarkerSize', 5);
intrack_plot = plot(time_steps, posRIC3a(:,3), 'gx', 'MarkerSize', 5);

radial_plot_STK = plot(true_ephem_time_steps_3, lumelite3_true_ephem.('Radial (km)').*1000, 'r', 'LineWidth', 1);
crosstrack_plot_STK = plot(true_ephem_time_steps_3, lumelite3_true_ephem.('Cross-Track (km)').*1000, 'b',  'LineWidth', 1);
intrack_plot_STK = plot(true_ephem_time_steps_3, lumelite3_true_ephem.('In-Track (km)').* 1000, 'g',  'LineWidth', 1);


xline(43200)
xline(1252865.075)
%plot(43200, 0, 'kx', 'MarkerSize', 10) %First thruster fire
%plot(1252865.075, 0, 'kx', 'MarkerSize', 10) %Second thruster fire. 
set(gca,'FontSize',15)
xlabel('Time after ignition (s)','interpreter', 'latex', 'fontsize', 20, 'Rotation', 0)
ylabel('Distance','interpreter', 'latex', 'fontsize', 20, 'Rotation', 90)
title('Displacements of satellite 3 w.r.t 1', 'interpreter', 'latex', 'fontsize', 20, 'Rotation', 0)
L=legend([radial_plot crosstrack_plot intrack_plot radial_plot_STK ...
    crosstrack_plot_STK intrack_plot_STK], 'Radial', 'Cross-track', 'Intrack', ...
          'Radial STK', 'Cross-track STK', 'Intrack STK');
      
L.FontSize=15;


%% PLOT THE thrust vector over time of SATELLITE 2 
fh=figure(3);
fh.WindowState = 'maximized';

box on
grid minor
hold on

x_plot = plot(time_steps, Th2_total(1,:), 'xr', 'LineWidth', 1);
y_plot = plot(time_steps, Th2_total(2,:), 'xb', 'LineWidth', 1);
z_plot = plot(time_steps, Th2_total(3,:), 'xg', 'LineWidth', 1);
xline(43200)
xline(1252842.554)
%plot(43200, 0, 'kx', 'MarkerSize', 10) %First thruster fire
%plot(1252865.075, 0, 'kx', 'MarkerSize', 10) %Second thruster fire. 
set(gca,'FontSize',15)
xlabel('Time after ignition (s)','interpreter', 'latex', 'fontsize', 20, 'Rotation', 0)
ylabel('Thrust','interpreter', 'latex', 'fontsize', 20, 'Rotation', 90)
title('Thrust vector of satellite 2', 'interpreter', 'latex', 'fontsize', 20, 'Rotation', 0)
L=legend([x_plot y_plot z_plot], 'x', 'y', 'z');
L.FontSize=15;


%% PLOT THE thrust vector over time of SATELLITE 3 
fh=figure(4);
fh.WindowState = 'maximized';

box on
grid minor
hold on

x_plot = plot(time_steps, Th3_total(1,:), 'xr', 'LineWidth', 1);
y_plot = plot(time_steps, Th3_total(2,:), 'xb', 'LineWidth', 1);
z_plot = plot(time_steps, Th3_total(3,:), 'xg', 'LineWidth', 1);
xline(43200) %First thruster fire
xline(1252865.075) %Second thruster fire. 
%plot(43200, 0, 'kx', 'MarkerSize', 10) 
%plot(1252865.075, 0, 'kx', 'MarkerSize', 10) 
set(gca,'FontSize',15)
xlabel('Time after ignition (s)','interpreter', 'latex', 'fontsize', 20, 'Rotation', 0)
ylabel('Thrust','interpreter', 'latex', 'fontsize', 20, 'Rotation', 90)
title('Thrust vector of satellite 3', 'interpreter', 'latex', 'fontsize', 20, 'Rotation', 0)
L=legend([x_plot y_plot z_plot], 'x', 'y', 'z');
L.FontSize=15;

%% FOR DEBUGGING...
% CAN PLOT THE ORBIT ABOUT CENTRAL BODY USING THE PLOTTER BELOW TOO

% writematrix(pos1a,'P1.csv');
% writematrix(vel1a,'V1.csv');
% writematrix(pos2a,'P2.csv');
% writematrix(vel2a,'V2.csv');
% writematrix(pos3a,'P3.csv');
% writematrix(vel3a,'V3.csv');
% writematrix(posRIC2a,'posRIC2a.csv');
% writematrix(posRIC3a,'posRIC3a.csv');

% Plot the central body.
% plot_body(1);
% Plot the trajectory about the central body.


function [instant_thrust, fire_indices] = instantaneous_thrust_when_firing(Th_total)
%%% Function to output the thrust when it is firing. Outputs the time of
%%% firing as well as an array. 
%%% Use this function to check that thrust at all firings times equals
%%% thrust specified, as the thrust is of constant thrust. 
fire_indices = find(any(Th_total, 1));
instant_thrust = sqrt(sum(Th_total(:,fire_indices).^2));

end