function [EM,NEM,E,d] = EMMImpedance(a,M)
%DESCRIPTION: Solving electromagnetic scattering problem in 3D with M
%impedance particles
%SYNTAX     : EMMImpedance(a,M)
%INPUT      : a   : The radius of particles 
%             M   : Number of particles (Number of equations and unknows)
%OUTPUT     : S   : The solution to the scattering problem in vector form (x,y,z)
%AUTHOR     : NHAN TRAN - nhantran@math.ksu.edu

global b kappa tau w cS alpha ES mu PI4 k zeta

% INITIALIZING SOME CONSTS:
% Speed of light in optics
c = 3*10^10;
% Frequency in optics
w = 5*10^14;
% Wave number k = 2pi/lambda
k = 2*pi*w/c;
ik = 1i*k;
k2 = k^2;
% characteristic constant of surface area of a ball: S=4*pi*R^2
cS = 4*pi;
% Volume of the domain that contains all particles
VolQ = 1;
% Power const with respect to the radius of particles: kappa in [0,1]
kappa = 0.9;
% alpha is a unit vector that indicates the direction of plane wave
alpha = [1,0,0];
% ES is E_0(0), ES \dot alpha = 0
ES = [0,1,0];

PI4 = 4*pi;
% Magnetic permebility:
mu = 1;
% Continuous distribution function of particles
N = M*(a^(2-kappa));
%Continuous function with Re(h) >= 0
h = 1;
% Boundary impedance
zeta = h/a^kappa;
% tau matrix
tau = 2/3;
% Number of particles on a side of a cube of size 1
b = floor(M^(1/3));
% Distance between two particles: d = O(1/M^(1/3))
%d = 1/M^(1/3);
d = 1/(b-1);
M2 = 2*M;
M3 = 3*M;

printInputs();

fprintf('\nSOLVING ELECTROMAGNETIC SCATTERING PROBLEM BY %d IMPEDANCE SMALL PARTICLES:\n',M);

tic
% [x,y,z] = DistributeParticles();
Pos = ParticlePosition();

%SOLVING THE PROBLEM:
A0 = SetupRHS(M3);
A = SetupMatrix(M3)
% ConditionA = cond(A)
% normA = norm(A)
X = A\A0;
%X = gmres(A,A0);
toc

fprintf('\nSOLUTIONS IN (x,y,z) FOR ALL PARTICLES:\n');
sx = X(1:M,:);
sy = X(M+1:M2,:);
sz = X(M2+1:M3,:);
AM = [sx,sy,sz];
tic
EM = Em(AM);
toc
NEM = norm(EM);
E = Error();
fprintf('\nNorm of the solution: %0.2E',NEM);
fprintf('\nError of the solution: %0.2E\n',E);
%disp(S);

Visualize(EM,Pos);

disp('DONE!');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function E0 = E0(PointI)
        XX = Pos(PointI,:);
        %E0 = ES*exp(ik*dot(alpha,XX));        
        E0 = ES*exp(ik*(alpha(1)*XX(1)+alpha(2)*XX(2)+alpha(3)*XX(3)));
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function Em = Em(Am)
    %Compute the solution E(x) with Am found from solving the linear system
        Em = zeros(M,3);
        C = zeta*tau*cS*(a^2)/(1i*w*mu);
        for i=1:M
            sum = zeros(1,3);
            for j=1:M
                if(i==j)
                    continue;
                end  
                %sum = sum + cross(GradGreen(i,j),Am(j,:))*C;   %VERY SLOW
                GG = GradGreen(i,j);                
                sum = sum + [GG(2)*Am(j,3)-GG(3)*Am(j,2),-GG(1)*Am(j,3)+GG(3)*Am(j,1),GG(1)*Am(j,2)-GG(2)*Am(j,1)]*C;                
            end
            Em(i,:) = E0(i)-sum;           
        end
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function A = SetupMatrix(MMatrixSizeM)
        A = zeros(MMatrixSizeM);
        C = zeta*tau*cS*(a^2)/(1i*w*mu)               
        
        %Run from particle 1 -> particle M:
        for j=1:M    
            row = (j-1)*3+1;
            for s=1:M
                if(s==j)
                    continue;
                end
                rv = Pos(j,:)-Pos(s,:);
                r = norm(rv,2);
                r2 = r*r;
                G = exp(ik*r)/(PI4*r);
                PGG1 = PartialGradGreen(1,r,r2,rv,G);
                PGG2 = PartialGradGreen(2,r,r2,rv,G);
                PGG3 = PartialGradGreen(3,r,r2,rv,G);
                
                %A(j,s) = (x,y,z)
                %First component x:                
                A(row,s)=C*(k2*G + PGG1(1));%For x
                A(row,s+M)=C*PGG2(1);%For y
                A(row,s+M2)=C*PGG3(1);%For z
                
                %Second component y:                
                A(row+1,s)=C*PGG1(2);
                A(row+1,s+M)=C*(k2*G + PGG2(2));
                A(row+1,s+M2)=C*PGG3(2);
                
                %Third component z:                
                A(row+2,s)=C*PGG1(3);
                A(row+2,s+M)=C*PGG2(3);
                A(row+2,s+M2)=C*(k2*G + PGG3(3));
            end            
            %Set the diagonal when j==s:           
            A(row,j) = 1;
            A(row+1,j+M) = 1;            
            A(row+2,j+M2) = 1;             
        end
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function RHS = SetupRHS(MMatrixSize)
        RHS = zeros(MMatrixSize,1);                
        for s=1:M            
            e = ik*exp(ik*dot(alpha,Pos(s,:)));
            RHS(s) = e*(ES(3)*alpha(2)-ES(2)*alpha(3));
            RHS(s+M) = e*(ES(3)*alpha(1)-ES(1)*alpha(3));
            RHS(s+M2) = e*(ES(2)*alpha(1)-ES(1)*alpha(2));
        end
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function Q = Qm(m)
        Q = -zeta*((cS*a^2)/(1i*w*mu))*(tau)*AM(m,:);        
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function Err = Error()
        %0.2Err = (1/PI4)*max([a/d^3 a*k2/d a*k/d^2],[],2);
        Err = (1/PI4)*(1/d^3 + k2/d + k/d^2)*a;
        sum = 0;
        for s=1:M
            sum = sum + norm(Qm(s));
        end
        
        Err = Err*sum;
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function m = Index2Order(m1,m2,m3)
        m = (m1-1)+(m2-1)*b+(m3-1)*b^2+1;
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function [m1,m2,m3] = Order2Index(m)
        m3 = floor((m-1)/b^2)+1;
        red1 = mod(m-1,b^2);
        m2 = floor(red1/b)+1;
        m1 = mod(red1,b)+1;
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function [x,y,z] = Particle2Position(m)
        % Set the position for each particle (uniformly distributed)
        % The first particle [x1,y1,z1] is at the left end bottom corner of the
        % cube and is called particle number 1.
        % The cube is in the first octant and the origin is one of its
        % vertex
        [m1,m2,m3] = Order2Index(m);
        x = (m1-1)*d;
        y = (m2-1)*d;
        z = (m3-1)*d;
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function pos = ParticlePosition()
        % Return the position in the 3D cube of particles
        
        pos = zeros(M,3);
        for s=1:M
            [pos(s,1),pos(s,2),pos(s,3)] = Particle2Position(s);
        end
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function G = Green(r)
        % Create a Green function in 3D
        
        % Distance from particle s to particle t in 3D
        %r = norm(Pos(s,:)-Pos(t,:),2);
        G = exp(ik*r)/(PI4*r);
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function GG = GradGreen(PointI,PointJ)
        rv = Pos(PointI,:)-Pos(PointJ,:);
        r = norm(rv,2);
        G = exp(ik*r)/(PI4*r);%Green function        
        GG = ((ik*G-G/r)/r)*rv;
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function PGG = PartialGradGreen(PartialIndex,r,r2,rv,G)
        % Create a Partial derivative of Grad of Green function in 3D       
        
        % Distance from particle s to particle t in 3D                
        %rv = Pos(s,:)-Pos(t,:);
        %r = norm(rv,2);     
        %G = exp(ik*r)/(PI4*r);%Green function
        
        F = G*ik-G/r;        
        PartialF = (-k2 - 2*ik/r + 2/(r2))*G*rv(PartialIndex)/r;        

        r0 = rv/r;
        
        Partialr0 = zeros(1,3);
        for DimIndex=1:3
            if(PartialIndex == DimIndex)
                Partialr0(DimIndex) = 1/r - (rv(PartialIndex)^2)/(r2*r);
            else
                Partialr0(DimIndex) = -(rv(DimIndex)/(r2*r))*2*rv(PartialIndex);
            end
        end
        
        PGG = PartialF*r0+F*Partialr0;
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function printInputs()
        % Display the inputs arguments of wave scattering problem
        
        str = 'INPUT PARAMETERS:';
        str = strcat(str, sprintf('\nSpeed of light, c: %0.2E cm/sec',c));
        str = strcat(str, sprintf('\nFrequency, f: %0.2E Hz',w));
        str = strcat(str, sprintf('\nWave number, k = 2pi/lambda: %0.2E cm^-1',k));  
        str = strcat(str, sprintf('\nWave length, lambda: %0.2E cm',2*pi/k));
        str = strcat(str, sprintf('\nVolume of the domain that contains all particles: %f cm^3',VolQ));                            
        str = strcat(str, sprintf('\nDirection of plane wave, alpha: (%s)',num2str(alpha)));
        str = strcat(str, sprintf('\nIncident field vector E_0: (%s)',num2str(ES)));
        str = strcat(str, sprintf('\nContinuous distribution function of particles: %s',num2str(N)));
        str = strcat(str, sprintf('\nMagnetic permebility: mu(x)= %s',num2str(mu)));
        str = strcat(str, sprintf('\nConstant, kappa: %d',kappa));  
        str = strcat(str, sprintf('\nFunction h in the impedance zeta=h/a^kappa, h(x)= %s',num2str(h)));
        str = strcat(str, sprintf('\nBoundary impedance zeta(x)= %s',num2str(zeta)));
        str = strcat(str, sprintf('\nNumber of particles, M: %d',M));  
        str = strcat(str, sprintf('\nThe smallest distance between two neighboring particles, d: %0.2E cm',d));
        str = strcat(str, sprintf('\nRadius of one particle, a: %0.2E cm',a));
        if(nargin > 10)
            %str = strcat(str, sprintf('\nDesired refraction coefficient: %s',num2str(n)));
            %str = strcat(str, sprintf('\nOriginal refraction coefficient: %s',num2str(n0)));
            %str = strcat(str, sprintf('\nInitial field satisfies Helmholtz equation in R^3: %s',num2str(u0)));
            %str = strcat(str, sprintf('\nFunction p(x): %s',num2str(p)));
        end
        
        disp(str);
        
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function Visualize(EM, Pos)
       figure
        % [x, y, z] = sphere;
        % h = surfl(x, y, z); 
        % set(h, 'FaceAlpha', 0.1)
        quiver3(Pos(:,1),Pos(:,2),Pos(:,3),EM(:,1),EM(:,2),EM(:,3)); 
        hold on;
        colormap hsv;
        view(-35,45);
        % sd = (Domain^(1/3))/2;
        % axis([-sd sd -sd sd -sd sd]);
        axis([0 1 0 1 0 1]);
        xlabel('x-axis');
        ylabel('y-axis');
        zlabel('z-axis');
        box on;
        axis tight;
        grid on;
        hold off;         
    end

end