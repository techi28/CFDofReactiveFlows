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
nx=78;      % number of (physical) cells along x
ny=nx;      % number of (physical) cells along y
L=1;        % length [m]
nu=0.01;    % kinematic viscosity [m2/s] (if L=1 and un=1, then Re=1/nu)
tau=10;     % total time of simulation [s]

% Boundary conditions
un=1;       % north wall velocity [m/s]
us=0;       % south wall velocity [m/s]
ve=0;       % east wall velocity [m/s]
vw=0;       % west wall velocity [m/s]

% Parameters for SOR
max_iterations=10000;   % maximum number of iterations
beta=1.2;               % SOR coefficient
max_error=1e-5;         % error for convergence

% [OBST] Obstacle definition: rectangle with base xs:xe and height ys:ye
xs=(nx+2)*1/8; xe=(nx+2)*2/8;
ys=(ny+2)*2/8; ye=(ny+2)*6/8;

% ----------------------------------------------------------------------- %
% Data processing
% ----------------------------------------------------------------------- %

% Grid step
h=L/nx;                             % grid step (uniform grid) [m]

% Time step
umax=max(un,max(us,max(ve,vw)));            % [OBST] maximum velocity [m/s]
sigma = 0.5;                                % safety factor for time step (stability)
dt_diff=h^2/4/nu;                           % time step (diffusion stability) [s]
dt_conv=4*nu/umax^2;                        % [OBST] time step (convection stability) [s]
dt=sigma*min(dt_diff, dt_conv);             % time step (stability) [s]
nsteps=tau/dt;                              % number of steps
Re = umax*L/nu;                             % [OBST] Reynolds' number

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

% [OBST] Correction of gamma close to the obstacle
gamma(xs-1,ys:ye)=1/3;
gamma(xe+1,ys:ye)=1/3;
gamma(xs:xe,ys-1)=1/3;
gamma(xs:xe,ye+1)=1/3;

% [OBST] Obstacle pre-processing
flagu = zeros(nx+1,ny+2);   % u-cells corresponding to the obstacle
for i=xs-1:xe
    for j=ys:ye
        flagu(i,j)=1;
    end
end
flagv = zeros(nx+2,ny+1);   % v-cells corresponding to the obstacle
for i=xs:xe
    for j=ys-1:ye
        flagv(i,j)=1;
    end
end
flagp = zeros(nx+2,ny+2);   % p-cells corresponding to the obstacle
for i=xs:xe
    for j=ys:ye
        flagp(i,j)=1;
    end
end

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
    
    % [OBST] Normal velocities along the obstacle walls
    u(xs-1,ys:ye)=0;    % west
    u(xe+1,ys:ye)=0;    % east
    v(xs:xe,ys-1)=0;    % south
    v(xs:xe,ye+1)=0;    % north
    
    % [OBST] Parallel velocities along the obstacle walls
    v(xs,ys:ye-1)=-v(xs-1,ys:ye-1);     % west
    v(xe,ys:ye-1)=-v(xe+1,ys:ye-1);     % east
    u(xs:xe-1,ys)=-u(xs:xe-1,ys-1);     % south
    u(xs:xe-1,ye)=-u(xs:xe-1,ye+1);     % north
    
    % [OBST] Create a temporary copy of velocity fields
    ut = u;
    vt = v;
    
    % Temporary u-velocity
    for i=2:nx
        for j=2:ny+1 
            
            if (flagu(i,j)==0) %[OBST] Only outside the obstacle
                
                ue2 = 0.25*( u(i+1,j)+u(i,j) )^2;
                uw2 = 0.25*( u(i,j)+u(i-1,j) )^2;
                unv = 0.25*( u(i,j+1)+u(i,j) )*( v(i+1,j)+v(i,j) );
                usv = 0.25*( u(i,j)+u(i,j-1) )*( v(i+1,j-1)+v(i,j-1) );

                A = (ue2-uw2+unv-usv)/h;
                D = (nu/h^2)*(u(i+1,j)+u(i-1,j)+u(i,j+1)+u(i,j-1)-4*u(i,j));

                ut(i,j)=u(i,j)+dt*(-A+D);
            
            end
            
        end
    end
    
    % Temporary v-velocity
    for i=2:nx+1
        for j=2:ny 
       
            if (flagv(i,j)==0) %[OBST] Only outside the obstacle
            
                vn2 = 0.25*( v(i,j+1)+v(i,j) )^2;
                vs2 = 0.25*( v(i,j)+v(i,j-1) )^2;
                veu = 0.25*( u(i,j+1)+u(i,j) )*( v(i+1,j)+v(i,j) );
                vwu = 0.25*( u(i-1,j+1)+u(i-1,j) )*( v(i,j)+v(i-1,j) );
                A = (vn2 - vs2 + veu - vwu)/h;
                D = (nu/h^2)*(v(i+1,j)+v(i-1,j)+v(i,j+1)+v(i,j-1)-4*v(i,j));

                vt(i,j)=v(i,j)+dt*(-A+D);
            
            end
            
        end
    end
    
    % Pressure equation (Poisson)
    for it=1:max_iterations
        
        po=p;
        for i=2:nx+1
            for j=2:ny+1

                if (flagp(i,j)==0) %[OBST] Only outside the obstacle

                    delta = p(i+1,j)+p(i-1,j)+p(i,j+1)+p(i,j-1);
                    S = (h/dt)*(ut(i,j)-ut(i-1,j)+vt(i,j)-vt(i,j-1));
                    p(i,j)=beta*gamma(i,j)*( delta-S )+(1-beta)*p(i,j);

                end
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
    
    % [OBST] Correct the velocity (only outside the obstacle)
    for i=2:nx
        for j=2:ny+1
            if (flagu(i,j)==0)
                u(i,j)=ut(i,j)-(dt/h)*(p(i+1,j)-p(i,j));
            end
        end
    end
    for i=2:nx+1
        for j=2:ny
            if (flagv(i,j)==0)
                v(i,j)=vt(i,j)-(dt/h)*(p(i,j+1)-p(i,j));
            end
        end
    end
    
    % Print on the screen
    if (mod(is,25)==1)
        fprintf('Step: %d - Time: %f - Poisson iterations: %d\n', is, t, it);
    end
    
    % Advance time
    t=t+dt;
 
end

% ----------------------------------------------------------------------- %
% Final post-processing                                                   %
% ----------------------------------------------------------------------- %

% [OBST] u-field reconstruction
uu=zeros(nx+1,ny+1);
for i=1:nx+1
    for j=1:ny+1
        if (flagu(i,j)==0)
            uu(i,j)=0.50*(u(i,j+1)+u(i,j));
        end
    end
end

% [OBST] v-field reconstruction
vv=zeros(nx+1,ny+1);
for i=1:nx+1
    for j=1:ny+1
        if (flagv(i,j)==0)
            vv(i,j)=0.50*(v(i+1,j)+v(i,j));
        end
    end
end

% [OBST] p-field reconstruction
pp=zeros(nx+1,ny+1);
for i=1:nx+1
    for j=1:ny+1
        if (flagp(i,j)==0)
            pp(i,j)=0.25*(p(i,j)+p(i+1,j)+p(i,j+1)+p(i+1,j+1));
        end
    end
end              

% Surface map: u-velocity
subplot(231);
surface(X,Y,uu');
axis('square'); title('u'); xlabel('x'); ylabel('y'); shading interp;
rectangle('Position',[h*(xs-1),h*(ys-1),h*(xe-xs),h*(ye-ys)],...
          'FaceColor',[0.85 0.85 0.85]);
      
% Surface map: v-velocity
subplot(234);
surface(X,Y,vv');
axis('square'); title('v'); xlabel('x'); ylabel('y'); shading interp;
rectangle('Position',[h*(xs-1),h*(ys-1),h*(xe-xs),h*(ye-ys)],...
          'FaceColor',[0.85 0.85 0.85]);
      
% Surface map: pressure
% subplot(232);
% surface(X,Y,pp');
% axis('square'); title('pressure'); xlabel('x'); ylabel('y');
% rectangle('Position',[h*(xs-1),h*(ys-1),h*(xe-xs+1),h*(ye-ys+1)],...
%           'FaceColor',[0.85 0.85 0.85]);
      
% Streamlines
subplot(233);
sx = [0:2*h:1 0.1*(1:-2*h:0)];
sy = [0:2*h:1 0:2*h:1];
streamline(X,Y,uu',vv',sx,sy)
axis([0 1 0 1], 'square');
title('streamlines'); xlabel('x'); ylabel('y');
rectangle('Position',[h*(xs-1),h*(ys-1),h*(xe-xs),h*(ye-ys)],...
          'FaceColor',[0.85 0.85 0.85]);
      
% Surface map: velocity vectors
subplot(236);
quiver(X,Y,uu',vv');
axis([0 1 0 1], 'square');
title('velocity vector field'); xlabel('x'); ylabel('y');
rectangle('Position',[h*(xs-1),h*(ys-1),h*(xe-xs),h*(ye-ys)],...
          'FaceColor',[0.85 0.85 0.85]);

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
