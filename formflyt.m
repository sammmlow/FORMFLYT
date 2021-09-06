%% #######################################################################
% ########################################################################
% ###                                                                  ###
% ###     LUMELITE ORBIT DYNAMICS AND CONTROL FOR FORMATION FLYING     ###
% ###     ========================================================     ###
% ###     By Matthew Lo, Andrew Ng, Samuel Low, and Dr Poh Eng Kee     ###
% ###                 Last Updated: 4th September 2021                 ###
% ###                                                                  ###
% ########################################################################
% ########################################################################

clc; clear; close all;

% ONE IMPORTANT NOTE TO ASSUME HERE IS THAT FORMFLYT DOES NOT ASSUME
% ANYTHING ABOUT THE FORMATION ANGULAR PARAMETERS, ESPECIALLY THE RELATIVE
% ARGUMENT OF PERIAPSIS. IT ASSUMES THAT ALL THREE SATELLITES ARE LAUNCHED
% IN A SINGLE COLLINEAR THROUGH-TRAIN CONFIGURATION.

%% USER INPUTS

% Specify the number of satellites.
numSats = 3;

% Specify the duration and the time step of the dynamics simulation (s).
tt = 1 * 86400;
dt = 10.0;

% Specify thruster burn mode intervals (hot = firing, cool = cool-down).
duration_hot  = 300.0;
duration_cool = 28500.0;

% Input the initial osculating orbit elements for Satellite 1.
a1  = 7000000;     % Semi-major axis (m)
e1  = 0.001;       % Eccentricity (unitless)
i1  = 10.00;       % Inclination (degrees)
w1  = 90.00;       % Arg of Periapsis (degrees)
R1  = 45.00;       % Right Ascension (degrees)
M1  = -90.00;       % Mean Anomaly (degrees)
Cd1 = 2.2;         % Drag coefficient
Ar1 = 0.374;       % Drag area (m^2)
Ms1 = 17.90;       % Spacecraft mass (kg)

% Input the initial osculating orbit elements for Satellite 2.
a2  = 7000000;     % Semi-major axis (m)
e2  = 0.001;       % Eccentricity (unitless)
i2  = 10.00;       % Inclination (degrees)
w2  = 90.00;       % Arg of Periapsis (degrees)
R2  = 45.00;       % Right Ascension (degrees)
M2  = 45.00;       % Mean Anomaly (degrees)
Cd2 = 2.2;         % Drag coefficient
Ar2 = 0.374;       % Drag area (m^2)
Ms2 = 17.90;       % Spacecraft mass (kg)

% Input the initial osculating orbit elements for Satellite 3.
a3  = 7000000;     % Semi-major axis (m)
e3  = 0.001;       % Eccentricity (unitless)
i3  = 10.00;       % Inclination (degrees)
w3  = 90.00;       % Arg of Periapsis (degrees)
R3  = 45.00;       % Right Ascension (degrees)
M3  = 45.00;       % Mean Anomaly (degrees)
Cd3 = 2.2;         % Drag coefficient
Ar3 = 0.374;       % Drag area (m^2)
Ms3 = 17.90;       % Spacecraft mass (kg)

% Specify Satellite 2's RIC geometry requirements and tolerances (m)
desired_R2 = 0.0;
desired_I2 = -100000.0;
desired_C2 = 42000.0;

% Specify Satellite 3's RIC geometry requirements and tolerances (m)
desired_R3 = 0.0;
desired_I3 = -200000.0;
desired_C3 = 0.0;

% Initialise the states of Satellite 2 and 3. There are 4 possible states:
% state == 1 ---> manoeuvres inactive, thrusters are warmed up
% state == 2 ---> manoeuvres inactive, thrusters are cooling down
% state == 3 ---> manoeuvres actively correcting radial errors (R)
% state == 4 ---> manoeuvres actively correcting in-track errors (I)
% state == 5 ---> manoeuvres actively correcting cross-track errors (C)
state_sat2 = 1;
state_sat3 = 1;

% Specify the formation geometry tolerance (m)
tolerance_R = 5000.0;
tolerance_I = 5000.0;
tolerance_C = 5000.0;

% Toggle the following perturbation flags (0 = False, 1 = True).
f_J2 = 1;
f_drag = 0;

% Toggle the following states

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

% Position, velocity, acceleration and true anomaly.
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

% ########################################################################
% ########################################################################

%% Main dynamics loop using an RK4 numerical integrator below 
% It is assumed that Satellite 1 is the chief reference.

% Initialise an integer variable for thruster-mode count down.
thruster_clock_2 = 0;
thruster_clock_3 = 0;

% Sun pointing in n2 hat direction inertial frame?

% Within the dynamics loop, there are key events that need to happen.

% First, the orbit is numerically propagated using the initial conditions
% above using the RK4 propagator written.

% Second, the formation geometry RIC vectors need to be computed, and used
% as feedback in the control law.

% Third, the dynamics loop is assumed to run in the same time step as the
% control loop, and has to keep track of two states at any point in time -
% the control-ready state (i.e. when thrusters are ready for fire), and the
% sunlit state (i.e. the spacecraft is in the illumination cone of the
% sun). Note that the control-ready state will only be toggle-able if the
% spacecraft is in sunlit state!

% Fourth, the frame used in the dynamics loop would be the pseudo-inertial
% ECI frame. This frame does not rotate with Earth's polar motion, but 

% Note, the number of satellites to be propagated is hard-coded in this
% for-loop to be three (Lumelites 1, 2, 3).

for N = 1 : nSamples
    
    % Fetch the current positions and velocities of the satellites.
    p1 = pos1a(N,:);
    v1 = vel1a(N,:);
    p2 = pos2a(N,:);
    v2 = vel2a(N,:);
    p3 = pos3a(N,:);
    v3 = vel3a(N,:);
    
    % Compute the Hill Frame of Satellite 1 as a Direction Cosine Matrix
    % All coordinates in RIC will be rotated via the Hill DCM
    h1 = cross(p1, v1);                   % Angular momentum vector
    r_hat = p1 / norm(p1);                % Local X-axis
    h_hat = h1 / norm(h1);                % Local Z-axis
    y_hat = cross(h_hat, r_hat);          % Local Y-axis
    hill_dcm = [ r_hat ; h_hat ; y_hat ]; % Hill DCM
    
    % Compute the RIC for Satellite 2 as feedback into the control loop.
    pRIC2 = hill_dcm * p2;
    posRIC2a(N,:) = pRIC2;
    
    % Compute the RIC for Satellite 3 as feedback into the control loop.
    pRIC3 = hill_dcm * p3;
    posRIC3a(N,:) = pRIC3;
    
    % Control Step 2R: Check for feedback control to Satellite 2's Radial
    if abs( pRIC2(1) - desired_R2 ) > tolerance_R && state_sat2 == 1
        % Input R-feedback control here
        if thruster_clock_2 < duration_hot
            thruster_clock_2 = thruster_clock_2 + dt; % Update the clock
        else
            state_sat2 = 2; % Set the thruster state to cool-down
            thruster_clock_2 = 0; % Reset the thruster clock.
        end
        
    % Control Step 2I: If Radial is OK, check for Satellite 2's In-Track
    elseif abs( pRIC2(2) - desired_I2 ) > tolerance_I && state_sat2 == 1
        % Input I-feedback control here
        if thruster_clock_2 < duration_hot
            thruster_clock_2 = thruster_clock_2 + dt; % Update the clock
        else
            state_sat2 = 2; % Set the thruster state to cool-down
            thruster_clock_2 = 0; % Reset the thruster clock.
        end
        
    % Control Step 2C: If In-Track is OK, check for Satellite 2's C-Track
    elseif abs( pRIC2(3) - desired_C2 ) > tolerance_C && state_sat2 == 1
        % Input C-feedback control here
        if thruster_clock_2 < duration_hot
            thruster_clock_2 = thruster_clock_2 + dt; % Update the clock
        else
            state_sat2 = 2; % Set the thruster state to cool-down
            thruster_clock_2 = 0; % Reset the thruster clock.
        end
        
    % If nothing gets triggered, it means two things: either the thruster
    % is in cool down mode (meaning state_sat == 2) or the satellite is
    % already in formation geometry.
    else
        
        % All is good, thrusters are ready, just propagate...
        if state_sat2 == 1
            ;
        % There may be formation positioning errors, but the thruster is
        % currently in cool down mode. Coast on...
        elseif state_sat2 == 2
            
            % Check if the cool down time limit has been reached...
            if thruster_clock_2 < duration_cool
                thruster_clock_2 = thruster_clock_2 + dt;
            else
                state_sat2 = 1;
                thruster_clock_2 = 0;
            end
            
        end
    end
    
    % Runge-Kutta 4th Order (RK4) Propagator (3/8 Rule Variant).
    % This code below is meant to only propagate LEO 1.
    [p1f, v1f] = prop_RK4_38( dt, p1, v1, Cd1, Ar1, Ms1, f_J2, f_drag );
    pos1a(N+1,:) = p1f;
    vel1a(N+1,:) = v1f;
    
    % Runge-Kutta 4th Order (RK4) Propagator (3/8 Rule Variant).
    % This code below is meant to only propagate LEO 2.
    [p2f, v2f] = prop_RK4_38( dt, p2, v2, Cd2, Ar2, Ms2, f_J2, f_drag );
    pos2a(N+1,:) = p2f;
    vel2a(N+1,:) = v2f;
    
    % Runge-Kutta 4th Order (RK4) Propagator (3/8 Rule Variant).
    % This code below is meant to only propagate LEO 3.
    [p3f, v3f] = prop_RK4_38( dt, p3, v3, Cd3, Ar3, Ms3, f_J2, f_drag );
    pos3a(N+1,:) = p3f;
    vel3a(N+1,:) = v3f;
    % Control 
    % One problem right now is that we have the algorithm to determine the
    % impulsive manoeuvre DV solution. Now, how do we actually translate
    % that into the finite manoeuvre solution? What we can do is... given
    % the impulsive DV solution for the RI solution - compute the hohmann
    % transfer needed to bring R to the same level first
    
    % R correction mode: while R_i != R_f, compute the total change in dV
    % needed for the Hohmann transfer
    
    
    
    % Check if the RIC vectors for Satellite 2 exceed the geometry limits.
    
    
    
    
    
    
    % If RIC vectors exceed the tolerances, enter the maintenance states
    % first and foremost by correcting R-I, and second by correcting C
    % using a RAAN or inclination plane change depending on the formation
    % control parameters selected by the user above.
    
    % If R-I first... then RI == True, C == False. Perform RI.
    
    % If R-I satisfied, then RI == False, 
    
    % Else, if RIC are all true, then
    
    % Within the above if-else check,
    % Check if the thruster is in cooldown mode. if it is not, and
    % it enters orbit manoeuvre mode, reset cool down time to 0 and begin
    % ticking up the firing time. else, once firing time hits the firing
    % time limit, then reset firing time down to 0 and begin ticking up the
    % cool down time.
    
end

writematrix(pos1a,'P.csv');
writematrix(vel1a,'V.csv');
writematrix(posRIC2a,'posRIC2a.csv');
writematrix(posRIC3a,'posRIC3a.csv');

% Plot the central body.
% plot_body(1);
% Plot the trajectory about the central body.