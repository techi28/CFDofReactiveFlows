% ----------------------------------------------------------------------- %
%     ?????????????   ???????        ??       ??????                      %
%     ?????????????   ???????       ????      ??????                      %
%     ??????????????????????????????????????????????????????????          %
%     ??????????????????????????????????????????????????????????          %
%     ??????  ??????????????????????????????????  ??????????????          % 
%     ??????  ??????????????????????????????????  ??????????????          %
% ----------------------------------------------------------------------- %
%                                                                         %
%   Author: Alberto Cuoci <alberto.cuoci@polimi.it>                       %
%   CRECK Modeling Group <http://creckmodeling.chem.polimi.it>            %
%   Department of Chemistry, Materials and Chemical Engineering           %
%   Politecnico di Milano                                                 %
%   P.zza Leonardo da Vinci 32, 20133 Milano                              %
%                                                                         %
% ----------------------------------------------------------------------- %
%                                                                         %
%   This file is part of CFDofReactiveFlows framework.                    %
%                                                                         %
%   License                                                               %
%                                                                         %
%   Copyright(C) 2018 Alberto Cuoci                                       %
%   CFDofReactiveFlows is free software: you can redistribute it and/or   %
%   modify it under the terms of the GNU General Public License as        %
%   published by the Free Software Foundation, either version 3 of the    %
%   License, or (at your option) any later version.                       %
%                                                                         %
%   CFDofReactiveFlows is distributed in the hope that it will be useful, %
%   but WITHOUT ANY WARRANTY; without even the implied warranty of        %
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         %
%   GNU General Public License for more details.                          %
%                                                                         %
%   You should have received a copy of the GNU General Public License     %
%   along with CFDofReactiveFlows.                                        %
%   If not, see <http://www.gnu.org/licenses/>.                           %
%                                                                         %
%-------------------------------------------------------------------------%
%                                                                         %
%  Code: 2D driven-cavity problem on a staggered grid                     %
%        The code is adapted and extended from Tryggvason, Computational  %
%        Fluid Dynamics http://www.nd.edu/~gtryggva/CFD-Course/           %
%                                                                         %
% ----------------------------------------------------------------------- %
close all;
clear variables;

% ----------------------------------------------------------------------- %
% User data
% ----------------------------------------------------------------------- %

% Only even numbers of cells are acceptable
nx=58;      % number of (physical) cells along x
ny=nx;      % number of (physical) cells along y
L=1;        % length [m]
nu=0.01;    % kinematic viscosity [m2/s] (if L=1 and un=1, then Re=1/nu)
tau=10;     % total time of simulation [s]

% Boundary conditions
un=1;       % north wall velocity [m/s]
us=0;       % south wall velocity [m/s]
ve=0;       % east wall velocity [m/s]
vw=0;       % west wall velocity [m/s]
uin=1;      % [INOUT] inlet velocity [m/s]

% Parameters for SOR
max_iterations=10000;   % maximum number of iterations
beta=1.2;               % SOR coefficient
max_error=1e-5;         % error for convergence

% [INOUT] Inlet section (west side)
nin_start = 1/2*(ny+2);         % first cell index 
nin_end = 3/4*(ny+2);           % last cell index

% [INOUT] Outlet section (east side)
nout_start = 1/4*(ny+2);            % first cell index 
nout_end = 1/2*(ny+2);              % last cell index


% ----------------------------------------------------------------------- %
% Data processing
% ----------------------------------------------------------------------- %

% Grid step
h=L/nx;                             % grid step (uniform grid) [m]

% Time step
umax=max(un,max(us,max(ve,max(vw,uin))));   % [INOUT] maximum velocity [m/s]
sigma = 0.5;                                % safety factor for time step (stability)
dt_diff=h^2/4/nu;                           % time step (diffusion stability) [s]
dt_conv=4*nu/umax^2;                        % [INOUT] time step (convection stability) [s]
dt=sigma*min(dt_diff, dt_conv);             % time step (stability) [s]
nsteps=tau/dt;                              % number of steps
Re = umax*L/nu;                             % [INOUT] Reynolds' number

% [INOUT] Inlet/Outlet section areas
Ain = h*(nin_end-nin_start+1);      % inlet section area [m]
Aout = h*(nout_end-nout_start+1);   % outlet section area [m]

% Print on the screen
fprintf('Time step: %f\n', dt);
fprintf(' - Diffusion:  %f\n', dt_diff);
fprintf(' - Convection: %f\n', dt_conv);
fprintf('Reynolds number: %f\n', Re);

% Grid construction
x=0:h:1;                % grid coordinates (x axis)
y=0:h:1;                % grid coordinates (y axis)
[X,Y] = meshgrid(x,y);  % MATLAB grid

% ----------------------------------------------------------------------- %
% Memory allocation
% ----------------------------------------------------------------------- %

% Main fields (velocities and pressure)
u=zeros(nx+1,ny+2);
v=zeros(nx+2,ny+1);
p=zeros(nx+2,ny+2);

% Temporary velocity fields
ut=zeros(nx+1,ny+2);
vt=zeros(nx+2,ny+1);

% Temporary pressure field (convergence of SOR)
po=zeros(nx+2,ny+2);

% Fields used only for graphical post-processing purposes
uu=zeros(nx+1,ny+1);
vv=zeros(nx+1,ny+1);
pp=zeros(nx+1,ny+1);

% Coefficient for pressure equation
gamma=zeros(nx+2,ny+2)+1/4;
gamma(2,3:ny)=1/3;gamma(nx+1,3:ny)=1/3;gamma(3:nx,2)=1/3;gamma(3:nx,ny+1)=1/3;
gamma(2,2)=1/2;gamma(2,ny+1)=1/2;gamma(nx+1,2)=1/2;gamma(nx+1,ny+1)=1/2;

% ----------------------------------------------------------------------- %
% Solution over time
% ----------------------------------------------------------------------- %
t=0.0;
for is=1:nsteps
    
    % Boundary conditions
    u(1:nx+1,1)=2*us-u(1:nx+1,2);               % south wall
    u(1:nx+1,ny+2)=2*un-u(1:nx+1,ny+1);         % north wall
    v(1,1:ny+1)=2*vw-v(2,1:ny+1);               % west wall
    v(nx+2,1:ny+1)=2*ve-v(nx+1,1:ny+1);         % east wall
    
    % [INOUT] Over-writing inlet conditions    
    u(1,nin_start:nin_end) = uin;               % fixed velocity
    Qin = mean(u(1,nin_start:nin_end))*Ain;     % inlet flow rate [m2/s]
    
    % [INOUT] Over-writing outlet conditions
    u(nx+1,nout_start:nout_end) = u(nx,nout_start:nout_end);    % 0-gradient
    Qout = mean(u(nx+1,nout_start:nout_end))*Aout;              % outlet flow rate [m2/s]
    
    % [INOUT] Correction on outlet to ensure conservation of mass
    if (abs(Qout)>1.e-12)
        u(nx+1,nout_start:nout_end) = u(nx+1,nout_start:nout_end)*abs(Qin/Qout);
    end
    
    % [INOUT] Create a temporary copy of velocity fields
    ut = u;
    vt = v;
    
    % Temporary u-velocity
    for i=2:nx
        for j=2:ny+1 
            
            ue2 = 0.25*( u(i+1,j)+u(i,j) )^2;
            uw2 = 0.25*( u(i,j)+u(i-1,j) )^2;
            unv = 0.25*( u(i,j+1)+u(i,j) )*( v(i+1,j)+v(i,j) );
            usv = 0.25*( u(i,j)+u(i,j-1) )*( v(i+1,j-1)+v(i,j-1) );
            
            A = (ue2-uw2+unv-usv)/h;
            D = (nu/h^2)*(u(i+1,j)+u(i-1,j)+u(i,j+1)+u(i,j-1)-4*u(i,j));
            
            ut(i,j)=u(i,j)+dt*(-A+D);
            
        end
    end
    
    % Temporary v-velocity
    for i=2:nx+1
        for j=2:ny 
            
            vn2 = 0.25*( v(i,j+1)+v(i,j) )^2;
            vs2 = 0.25*( v(i,j)+v(i,j-1) )^2;
            veu = 0.25*( u(i,j+1)+u(i,j) )*( v(i+1,j)+v(i,j) );
            vwu = 0.25*( u(i-1,j+1)+u(i-1,j) )*( v(i,j)+v(i-1,j) );
            A = (vn2 - vs2 + veu - vwu)/h;
            D = (nu/h^2)*(v(i+1,j)+v(i-1,j)+v(i,j+1)+v(i,j-1)-4*v(i,j));
            
            vt(i,j)=v(i,j)+dt*(-A+D);
            
        end
    end
    
    % Pressure equation (Poisson)
    for it=1:max_iterations
        
        po=p;
        for i=2:nx+1
            for j=2:ny+1
                
                delta = p(i+1,j)+p(i-1,j)+p(i,j+1)+p(i,j-1);
                S = (h/dt)*(ut(i,j)-ut(i-1,j)+vt(i,j)-vt(i,j-1));
                p(i,j)=beta*gamma(i,j)*( delta-S )+(1-beta)*p(i,j);
                
            end
        end
        
        % Estimate the error
        epsilon=0.0; 
        for i=2:nx+1
            for j=2:ny+1
                epsilon=epsilon+abs(po(i,j)-p(i,j)); 
            end
        end
        epsilon = epsilon / (nx*ny);
        
        % Check the error
        if (epsilon <= max_error) % stop if converged
            break;
        end 
        
    end
    
    % Correct the velocity
    u(2:nx,2:ny+1)=ut(2:nx,2:ny+1)-(dt/h)*(p(3:nx+1,2:ny+1)-p(2:nx,2:ny+1));
    v(2:nx+1,2:ny)=vt(2:nx+1,2:ny)-(dt/h)*(p(2:nx+1,3:ny+1)-p(2:nx+1,2:ny));
    
    if (mod(is,25)==1)
        fprintf('Step: %d - Time: %f - Poisson iterations: %d\n', is, t, it);
    end
    
    % Advance time
    t=t+dt;
 
end

% ----------------------------------------------------------------------- %
% Final post-processing                                                   %
% ----------------------------------------------------------------------- %

% Field reconstruction
uu(1:nx+1,1:ny+1)=0.50*(u(1:nx+1,2:ny+2)+u(1:nx+1,1:ny+1));
vv(1:nx+1,1:ny+1)=0.50*(v(2:nx+2,1:ny+1)+v(1:nx+1,1:ny+1));
pp(1:nx+1,1:ny+1)=0.25*(p(1:nx+1,1:ny+1)+p(1:nx+1,2:ny+2)+...
                        p(2:nx+2,1:ny+1)+p(2:nx+2,2:ny+2));

% Surface map: u-velocity
subplot(231);
surface(X,Y,uu');
axis('square'); title('u'); xlabel('x'); ylabel('y'); shading interp;

% Surface map: v-velocity
subplot(234);
surface(X,Y,vv');
axis('square'); title('v'); xlabel('x'); ylabel('y'); shading interp;

% Surface map: pressure
% subplot(232);
% surface(X,Y,pp');
% axis('square'); title('pressure'); xlabel('x'); ylabel('y');

% Streamlines
subplot(233);
sx = [0:2*h:1 0.1*(1:-2*h:0)];
sy = [0:2*h:1 0:2*h:1];
streamline(X,Y,uu',vv',sx,sy)
axis([0 1 0 1], 'square');
title('streamlines'); xlabel('x'); ylabel('y');

% Surface map: velocity vectors
subplot(236);
quiver(X,Y,uu',vv');
axis([0 1 0 1], 'square');
title('velocity vector field'); xlabel('x'); ylabel('y');

% Plot: velocity components along the horizontal middle axis
subplot(232);
plot(x,uu(:, round(ny/2)+1));
hold on;
plot(x,vv(:, round(ny/2)+1));
axis('square');
xlabel('x [m]');ylabel('velocity [m/s]'); title('velocity along x-axis');
legend('x-velocity', 'y-velocity');
hold off;

% Plot: velocity components along the horizontal middle axis
subplot(235);
plot(y,uu(round(nx/2)+1,:));
hold on;
plot(y,vv(round(nx/2)+1,:));
axis('square');
xlabel('y [m]');ylabel('velocity [m/s]'); title('velocity along y-axis');
legend('x-velocity', 'y-velocity');
hold off;


% ------------------------------------------------------------------- %
% Write velocity profiles along the centerlines for exp comparison
% ------------------------------------------------------------------- %
u_profile = uu(round(nx/2)+1,:);
fileVertical = fopen('vertical.txt','w');
for i=1:ny+1 
    fprintf(fileVertical,'%f %f\n',y(i), u_profile(i));
end
fclose(fileVertical);

v_profile = vv(:,round(ny/2)+1);
fileHorizontal = fopen('horizontal.txt','w');
for i=1:nx+1
    fprintf(fileHorizontal,'%f %f\n',x(i), v_profile(i));
end
fclose(fileHorizontal);