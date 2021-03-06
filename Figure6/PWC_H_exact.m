function [Y] = PWC_H_exact(t, Ifunc, Area, Na_mask,K_mask,NaNoise1,KNoise1)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% EM_HH.m
% Written by Shusen Pu and Peter Thomas
% Oct, 2018

%%% Inputs
% t is vector of time values (ms)
% Ifunc is a function @(t)f(t) that returns stimulus value as a function of time (in ms)
% Area: Membrane Area (mu m^2)

% Noise Model (String), possible values: 
%   None: 'ODE'
%   EM: 'Euler Maruyama', must also have value for Area

%%% Outputs
% Y(:,1) : t
% Y(:,2) : V
% Y(:,3:10) : fractions in Na states m00-m13 
% Y(:,11:15) : fraction in K states n0-n4


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Initialize quantities needed to run solver 

% time step size
dt = t(2)-t(1);

% Number of time steps
nt = length(t);  % total
nt1 = nt-1;  % at which to solve

P=cell(nt,1);
L=cell(nt,1);
Q=cell(nt,1);

% Initial Values
% from XPP code on the limit cycle
t0 = t(1);
V0 = -61.897274; 
V1=V0;
m00=0.4329406;m01=0.10034765;m02=0.0077529117;m03=0.00019966466;
m10=0.36696321;m11=0.085055299;m12=0.0065714167;
% m13=0.00016923703;
m13=1-m00-m01-m02-m03-m10-m11-m12; %normalize to 1
n0=0.13761529;n1=0.35331318;n2=0.34016079;n3=0.14555468;
%n4=0.023356047;
n4=1-n0-n1-n2-n3; %normalize to 1

 
% Initialize Output
Y = zeros(nt,29); 
Y(1,:) = [t0,V0,m00,m01,m02,m03,m10,m11,m12,m13,n0,n1,n2,n3,n4,V0,m00,m01,m02,m03,m10,m11,m12,m13,n0,n1,n2,n3,n4];

Na_gates =[m00;m01;m02;m03;m10;m11;m12;m13];
Na_gates1=[m00;m01;m02;m03;m10;m11;m12;m13];

K_gates=[n0,n1,n2,n3,n4]';
K_gates1=K_gates;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Parameter Values

% Number of Channels
NNa = round(Area*60); % Na
NK = round(Area*18); % K

% Capacitance
C = 1; % muF /cm^2

% Na Current
gNa = 120; % mS/cm^2
ENa = 50; % mV

% K Current
gK = 36; % mS/cm^2
EK = -77; % mV

% Passive Leak
gL = 0.3; % mS / cm^2
EL = -54.4; % mV



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Determine Which Noise Model and Do Some Necessary Setup


% Conductance Noise Model using Euler Maruyama (Thomas and Pu)
    
    % Drift Na
    ANa = @(V) ...
         [ -3*alpham(V)-alphah(V)       , betam(V)                , 0              , 0                      ,  betah(V)                 , 0                       , 0          , 0 ;
            3*alpham(V)               ,-2*alpham(V)-betam(V)-alphah(V), 2*betam(V)        , 0                      ,  0                     , betah(V)                   , 0          , 0 ;
            0                      , 2*alpham(V)             , -alpham(V)-2*betam(V)-alphah(V),  3*betam(V)        ,  0                     ,  0                      , betah(V)      , 0 ;
            0                      , 0                    , alpham(V)         , -3*betam(V)-alphah(V)        ,  0                     ,  0                      , 0          , betah(V)    ;
            alphah(V)                 , 0                    , 0              , 0                      ,  -3*alpham(V) - betah(V)     , betam(V)                   , 0          , 0 ;
            0                      , alphah(V)               , 0              , 0                      ,  3*alpham(V)              ,  -2*alpham(V)-betam(V)-betah(V)  ,   2*betam(V)  , 0 ;
            0                      , 0                    , alphah(V)         , 0                      ,  0                     ,  2*alpham(V)               ,   -alpham(V)-2*betam(V)-betah(V) , 3*betam(V)  ;
            0                      , 0                    , 0              , alphah(V)                 ,           0            ,  0                      ,  alpham(V)    , -3*betam(V)-betah(V)];

    % Drift K
    AK = @(V) ...
        [-4*alphan(V), betan(V)             , 0                , 0                  , 0
          4*alphan(V), -3*alphan(V)-betan(V),  2*betan(V)               , 0,                   0;
          0,        3*alphan(V),        -2*alphan(V)-2*betan(V), 3*betan(V),          0;
          0,        0,               2*alphan(V),          -alphan(V)-3*betan(V), 4*betan(V);
          0,        0,               0,                 alphan(V),          -4*betan(V)];
    
    
    % Diffusion Na : Defined in a afunction below
    
    
    % Diffusion K
    DK = @(V,X) (1/(NK)) * ...
        [   (4*alphan(V)*X(1) + betan(V)*X(2)) ,  -(4*alphan(V)*X(1) + betan(V)*X(2))                                    ,   0                                                                  , 0                                                                , 0 ;
           -(4*alphan(V)*X(1) + betan(V)*X(2)),  (4.*alphan(V)*X(1) + (3*alphan(V)+ betan(V))*X(2) + 2.*betan(V)*X(3))  ,  -(2*betan(V)*X(3) + 3*alphan(V)*X(2) )                               , 0                                                                , 0 ; 
           0                                  ,  -(2*betan(V)*X(3) + 3*alphan(V)*X(2))                                   , (3*alphan(V)*X(2) + (2*alphan(V)+2*betan(V))*X(3) + 3*betan(V)*X(4)) , -(3*betan(V)*X(4) + 2*alphan(V)*X(3))                            , 0 ;
           0                                  ,  0                                                                      , -(3*betan(V)*X(4) + 2*alphan(V)*X(3))                                , (2*alphan(V)*X(3) + (alphan(V)+3*betan(V))*X(4) +4*betan(V)*X(5)), -(4*betan(V)*X(5) + alphan(V)*X(4)) ;
           0                                  ,  0                                                                      , 0                                                                    , -(4*betan(V)*X(5) + alphan(V)*X(4))                              , (alphan(V)*X(4) + 4*betan(V)*X(5)) ];


    % Take Matrix square roots numerically using SVD
    SNa = @(V,Y,NNa) mysqrtm(DNa(V,Y,NNa));
    %SNa = @(V,Y,NNa) sqrtm(DNa(V,Y,NNa));
    
    %SNa=sqrtm(DNa(V0,Na_gates,NNa));
    %SK = @(V,X) mysqrtm(DK(V,X)); 
    
    %14-D full G, GG^T=DNa
    
    G = DNa20(V0,Na_gates,NNa,Na_mask);
    [P_t,L_t,Q_t] = svd(G);
    i=1;
    P{i}=P_t;
    L{i}=L_t;
    Q{i}=Q_t;
    %NaNoise1(:,i-1)
    
    %Noise Term: adding white noise to each transaction
    %defined in two functions namely, DNafull and DKfull 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% HERE IS THE SOLVER            %%%%%%%%%%%%%%%%%%%%%%%
%%%%%% USING EULER FOR ODEs,         %%%%%%%%%%%%%%%%%%%%%%%
%%%%%% Milstein FOR SDEs,            %%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i=2:nt

  % Input Current
  I = Ifunc(t(i-1));
  % update the gates
 if sum(Na_mask~=0)==0
       Na_gates = Na_gates + dt*ANa(V0)*Na_gates;
       K_gates =  K_gates + dt*AK(V0) *K_gates + sqrt(dt)*DKfull(V0,K_gates,NK,KNoise1(:,i-1),K_mask) ;
       
    elseif sum(K_mask~=0)==0
%         Na_gates1 = Na_gates1 + dt*ANa(V1)*Na_gates1 +sqrt(dt)*(P_t*L_t*Q_t')*NaNoise1(:,i-1);
        %Na_gates1 = Na_gates1 + dt*ANa(V1)*Na_gates1 +sqrt(dt)*(real(SNa(V1,Na_gates1,NNa)))*NaNoise1(:,i-1);
        Fox=P_t*((L_t*transpose(L_t))^(1/2))*transpose(P_t);
        Na_gates1 = Na_gates1 + dt*ANa(V1)*Na_gates1 +sqrt(dt)*Fox*NaNoise1(:,i-1);
%         Na_gates1 = Na_gates1 + dt*ANa(V1)*Na_gates1 +sqrt(dt)*(real(SNa(V1,Na_gates1,NNa)))*NaNoise1(:,i-1);
        K_gates1 =  K_gates1 + dt*AK(V1) *K_gates1;
        
        
        H_noise=sqrt(dt)*Q_t*(pinv(L_t))*((L_t*transpose(L_t))^(1/2))*transpose(P_t);
        
        %Na_gates = Na_gates + dt*ANa(V0)*Na_gates+ G*H_noise*NaNoise1(:,i-1);
        %Na_gates = Na_gates + dt*ANa(V0)*Na_gates+sqrt(dt)*P_t*L_t*transpose(Q_t)*Q_t*(pinv(L_t))*((L_t*transpose(L_t))^(1/2))*transpose(P_t)*NaNoise1(:,i-1);
        Na_gates = Na_gates + dt*ANa(V0)*Na_gates+G*H_noise*NaNoise1(:,i-1);
        %Na_gates = Na_gates + dt*ANa(V0)*Na_gates+ sqrt(dt)*G*NaNoise1(:,i-1);
        
        K_gates =  K_gates + dt*AK(V0) *K_gates;
        
        %R_noise=sqrt(dt)*P_t*(pinv((L_t*transpose(L_t))^(1/2)))*L_t*Q_t*NaNoise1(:,i-1);
        
        %R_noise=sqrt(dt)*P_t*(pinv((L_t*transpose(L_t))^(1/2)))*L_t*transpose(Q_t)*NaNoise1(:,i-1);
        %pinv((L_t*transpose(L_t))^(1/2))*(L_t*transpose(L_t))^(1/2)
        %pause
        %Fox=P_t*((L_t*transpose(L_t))^(1/2))*transpose(P_t);
%         GS=SNa(V1,Na_gates1,NNa);
%         DiffMatrix=Fox-GS;
%         DiffMatrixNum=sum(sum(DiffMatrix))
        %pause
    else    

       Na_gates = Na_gates + dt*ANa(V0)*Na_gates+ sqrt(dt)*DNafull(V0,Na_gates,NNa,NaNoise1(:,i-1),Na_mask);
       K_gates =  K_gates + dt*AK(V0) *K_gates + sqrt(dt)*DKfull(V0,K_gates,NK,KNoise1(:,i-1),K_mask) ;
 end
   

 
  % Compute Fraction of open channels
  NaFraction= Na_gates(8);
  KFraction=K_gates(5);
      
  NaFraction1= Na_gates1(8);
  KFraction1=K_gates1(5);
  
  
  % Update Voltage
  Vrhs = (-gNa*(NaFraction)*(V0 - ENa)-gK*(KFraction)*(V0 - EK) - gL*(V0-EL) + I)/C;
  V = V0 + dt*Vrhs ;   % VNoise is non-zero for Current Noise Model
  
  Vrhs1 = (-gNa*(NaFraction1)*(V1 - ENa)-gK*(KFraction1)*(V1 - EK) - gL*(V1-EL) + I)/C;
  V1 = V1 + dt*Vrhs1 ;   % VNoise is non-zero for Current Noise Model
  
    % find SVD of G
    G = DNa20(V,Na_gates,NNa,Na_mask);
    [P_t,L_t,Q_t] = svd(G);
    P{i}=P_t;
    L{i}=L_t;
    Q{i}=Q_t;
  
  % Save Outputs    
  Y(i,1) = t(i);
  Y(i,2) = V;
  Y(i,3:10) = Na_gates';
  Y(i,11:15) = K_gates';
  Y(i,16)=V1;
  Y(i,17:24)= Na_gates1';
  Y(i,25:29)= K_gates1';
  
  % Keep "old values" to use in next Euler time step
  V0 = V;
% pause
  %disp(i/nt)
end  % End loop over time for SDE solver


end % End Function Definition
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%% END OF SOLVER                 %%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Define functions used above

% subunit kinetics (Hodgkin and Huxley parameters, modified from XPP code by PJT OCt, 2018)
function out = alpham(V)
  out =  .1*(V+40)/(1-exp(-(V+40)/10));
  %0.1 * (25-V)/ (exp((25-V)/10)-1);
end

function out = betam(V)
  out = 4*exp(-(V+65)/18);
  %4 * exp(-V/18);
end

function out = alphah(V)
  out =  .07*exp(-(V+65)/20);
  %0.07 * exp(-V/20);
end

function out = betah(V)
  out = 1/(1+exp(-(V+35)/10));
  %1/ (exp((30-V)/10)+1);
end

function out = alphan(V)
  out = .01*(V+55)/(1-exp(-(V+55)/10));
  %0.01 * (10-V) / (exp((10-V)/10)-1);
end

function out = betan(V)
  out = .125*exp(-(V+65)/80);
  %0.125 * exp(-V/80);
end

% Computing matrix square roots with SVD
function S = mysqrtm(D)
 [u,s,v] = svd(D);
 S = u*sqrt(s)*v';
 %S = u*sqrt(s)*u';
%  [V,D1] = eig(D);
%  S=V*sqrt(D1*transpose(D1))*transpose(V);
end

%=================================================================
% Diffusion matrix for Na
function   D = DNa(V,Y,N)
D = zeros(8,8);
y00 = Y(1);
y10 = Y(2);
y20 = Y(3);
y30 = Y(4);
y01 = Y(5);
y11 = Y(6);
y21 = Y(7);
y31 = Y(8);

D(1,1) = (  (3*alpham(V) + alphah(V))*y00 + betam(V)*y10 + betah(V)*y01 )  ;
D(1,2) = (-3*alpham(V)*y00 - betam(V)*y10); 
D(1,3) = 0;
D(1,4) = 0;
D(1,5) = - (alphah(V)*y00 + betah(V)*y01);
D(1,6) = 0;
D(1,7) = 0;
D(1,8) = 0;

D(2,1) = D(1,2);
D(2,2) = ((betam(V)+2*alpham(V))*y10 + 2*betam(V)*y20 + 3*alpham(V)*y00 + alphah(V)*y10 + betah(V)*y11) ;
D(2,3) = -(2*alpham(V)*y10 + 2*betam(V)*y20); 
D(2,4) = 0;
D(2,5) = 0;
D(2,6) = -(alphah(V)*y10 + betah(V)*y11);
D(2,7) = 0;
D(2,8) = 0;

D(3,1) = D(1,3);
D(3,2) = D(2,3);
D(3,3) = ((2*betam(V)+alpham(V))*y20 + 3*betam(V)*y30 + 2*alpham(V)*y10 + alphah(V)*y20 + betah(V)*y21) ;
D(3,4) = -(alpham(V)*y20+3*betam(V)*y30); 
D(3,5) = 0;
D(3,6) = 0;
D(3,7) = -(alphah(V)*y20+betah(V)*y21);
D(3,8) = 0;

D(4,1) = D(1,4);
D(4,2) = D(2,4);
D(4,3) = D(3,4);
D(4,4) = (3*betam(V)*y30 + alpham(V)*y20 + alphah(V)*y30 + betah(V)*y31); 
D(4,5) = 0;
D(4,6) = 0;
D(4,7) = 0;
D(4,8) = -(alphah(V)*y30 + betah(V)*y31); 

D(5,1) = D(1,5);
D(5,2) = D(2,5);
D(5,3) = D(3,5);
D(5,4) = D(4,5);
D(5,5) = (3*alpham(V)*y01 + betam(V)*y11 + betah(V)*y01 + alphah(V)*y00) ;
D(5,6) = -(3*alpham(V)*y01 + betam(V)*y11) ;
D(5,7) = 0;
D(5,8) = 0;

D(6,1) = D(1,6);
D(6,2) = D(2,6);
D(6,3) = D(3,6);
D(6,4) = D(4,6);
D(6,5) = D(5,6);
D(6,6) = ((betam(V)+2*alpham(V))*y11 + 2*betam(V)*y21 + 3*alpham(V)*y01 + betah(V)*y11 + alphah(V)*y10);
D(6,7) = -(2*alpham(V)*y11+2*betam(V)*y21);
D(6,8) = 0;

D(7,1) = D(1,7);
D(7,2) = D(2,7);
D(7,3) = D(3,7);
D(7,4) = D(4,7);
D(7,5) = D(5,7);
D(7,6) = D(6,7);
D(7,7) = ((2*betam(V)+alpham(V))*y21+3*betam(V)*y31+2*alpham(V)*y11+betah(V)*y21+alphah(V)*y20);
D(7,8) = -(alpham(V)*y21+3*betam(V)*y31);

D(8,1) = D(1,8);
D(8,2) = D(2,8);
D(8,3) = D(3,8);
D(8,4) = D(4,8);
D(8,5) = D(5,8);
D(8,6) = D(6,8);
D(8,7) = D(7,8);
D(8,8) = (3*betam(V)*y31 + alpham(V)*y21 + betah(V)*y31 + alphah(V)*y30);

D = D/(N);
end

%=================================================================
%SVD decompostion for 14-D HH model (Shusen Pu 04-09-2019)

% Diffusion matrix for Na (Thomas and Pu)
function   G = DNa20(V,Y,N,Na_mask) 
%V is voltage, Y stands for probablity at each state (we use Y-Ybar)
%N is the dimension or number of Na Channels, M is randn 20 by 1
%D = zeros(8,1);
G=zeros(8,20);
Y=Y.*(Y>0); %to exclude negative numbers added by SP&PJT 10/08/2018
y00 = Y(1);
y10 = Y(2);
y20 = Y(3);
y30 = Y(4);
y01 = Y(5);
y11 = Y(6);
y21 = Y(7);
y31 = Y(8);

% intensity for these 20 transactions
N20=zeros(20,1);
%save all these alpha and beta values for computational efficiency
ah=alphah(V);
bh=betah(V);
am=alpham(V);
bm=betam(V);
% N20(1)=Na_mask(1)*sqrt(ah*y00)*M(1); %00--01
% N20(2)=Na_mask(2)*sqrt(bh*y01)*M(2); %01--00
% N20(3)=Na_mask(3)*sqrt(3*am*y00)*M(3); %00--10
% N20(4)=Na_mask(4)*sqrt(bm*y10)*M(4); %10--00
% N20(5)=Na_mask(5)*sqrt(ah*y10)*M(5);  %10--11
% N20(6)=Na_mask(6)*sqrt(bh*y11)*M(6);  %11--10
% N20(7)=Na_mask(7)*sqrt(2*am*y10)*M(7);%10--20
% N20(8)=Na_mask(8)*sqrt(2*bm*y20)*M(8); %20--10
% N20(9)=Na_mask(9)*sqrt(ah*y20)*M(9); %20--21
% N20(10)=Na_mask(10)*sqrt(bh*y21)*M(10); %21--20
% N20(11)=Na_mask(11)*sqrt(am*y20)*M(11); %20--30
% N20(12)=Na_mask(12)*sqrt(3*bm*y30)*M(12);%30--20
% N20(13)=Na_mask(13)*sqrt(ah*y30)*M(13); %30--31
% N20(14)=Na_mask(14)*sqrt(bh*y31)*M(14); %31--30
% N20(15)=Na_mask(15)*sqrt(3*am*y01)*M(15);%01--11
% N20(16)=Na_mask(16)*sqrt(bm*y11)*M(16); %11--01
% N20(17)=Na_mask(17)*sqrt(2*am*y11)*M(17);%11--21
% N20(18)=Na_mask(18)*sqrt(2*bm*y21)*M(18);%21--11
% N20(19)=Na_mask(19)*sqrt(am*y21)*M(19);%21--31
% N20(20)=Na_mask(20)*sqrt(3*bm*y31)*M(20);%31--21

N20(1)=Na_mask(1)*sqrt(ah*y00); %00--01
G(1,1)=-N20(1);
G(5,1)=N20(1);

N20(2)=Na_mask(2)*sqrt(bh*y01); %01--00
G(1,2)=N20(2);
G(5,2)=-N20(2);

N20(3)=Na_mask(3)*sqrt(3*am*y00); %00--10
G(1,3)=-N20(3);
G(2,3)=N20(3);

N20(4)=Na_mask(4)*sqrt(bm*y10); %10--00
G(1,4)=N20(4);
G(2,4)=-N20(4);

N20(5)=Na_mask(5)*sqrt(ah*y10);  %10--11
N20(6)=Na_mask(6)*sqrt(bh*y11);  %11--10
G(2,5)=-N20(5);
G(6,5)=N20(5);
G(2,6)=N20(6);
G(6,6)=-N20(6);


N20(7)=Na_mask(7)*sqrt(2*am*y10);%10--20
N20(8)=Na_mask(8)*sqrt(2*bm*y20); %20--10
G(2,7)=-N20(7);
G(3,7)=N20(7);
G(2,8)=N20(8);
G(3,8)=-N20(8);


N20(9)=Na_mask(9)*sqrt(ah*y20); %20--21
N20(10)=Na_mask(10)*sqrt(bh*y21); %21--20
G(2,9)=-N20(9);
G(6,9)=N20(9);
G(2,10)=N20(10);
G(6,10)=-N20(10);


N20(11)=Na_mask(11)*sqrt(am*y20); %20--30
N20(12)=Na_mask(12)*sqrt(3*bm*y30);%30--20
G(3,11)=-N20(11);
G(4,11)=N20(11);
G(3,12)=N20(12);
G(4,12)=-N20(12);

N20(13)=Na_mask(13)*sqrt(ah*y30); %30--31
N20(14)=Na_mask(14)*sqrt(bh*y31); %31--30
G(4,13)=-N20(13);
G(8,13)=N20(13);
G(4,14)=N20(14);
G(8,14)=-N20(14);

N20(15)=Na_mask(15)*sqrt(3*am*y01);%01--11
N20(16)=Na_mask(16)*sqrt(bm*y11); %11--01
G(5,15)=-N20(15);
G(6,15)=N20(15);
G(5,16)=N20(16);
G(6,16)=-N20(16);

N20(17)=Na_mask(17)*sqrt(2*am*y11);%11--21
N20(18)=Na_mask(18)*sqrt(2*bm*y21);%21--11
G(6,17)=-N20(17);
G(7,17)=N20(17);
G(6,18)=N20(18);
G(7,18)=-N20(18);

N20(19)=Na_mask(19)*sqrt(am*y21);%21--31
N20(20)=Na_mask(20)*sqrt(3*bm*y31);%31--21
G(7,19)=-N20(19);
G(8,19)=N20(19);
G(7,20)=N20(20);
G(8,20)=-N20(20);



% D(1) = -N20(1)-N20(3)+N20(2)+N20(4) ;
% D(2) = -N20(4)-N20(5)-N20(7)+N20(3)+N20(6)+N20(8);
% D(3) = -N20(8)-N20(9)-N20(11)+N20(7)+N20(10)+N20(12);
% D(4) = -N20(12)-N20(13)+N20(11)+N20(14);
% D(5) = -N20(2)-N20(15)+N20(1)+N20(16);
% D(6) = -N20(6)-N20(16)-N20(17)+N20(5)+N20(15)+N20(18);
% D(7) = -N20(10)-N20(18)-N20(19)+N20(9)+N20(17)+N20(20);
% D(8) = -N20(14)-N20(20)+N20(13)+N20(19);

G = G/sqrt(N);
end

%=================================================================
% Diffusion matrix for K (Thomas and Pu)
function   D = DKfull(V,Y,N,M,K_mask) 
%V is voltage, Y stands for probablity at each state (we use Y-Ybar)
%N is the dimension or number of K Channels, M is randn 8 by 1
D = zeros(5,1);

% noise for these 8 transactions
N8=zeros(8,1);
%save all these alpha and beta values for computational efficiency
an=alphan(V);
bn=betan(V);
Y=Y.*(Y>0); %to exclude negative numbers added by SP&PJT 10/08/2018
N8(1)=K_mask(1)*sqrt(4*an*Y(1))*M(1); %0--1
N8(2)=K_mask(2)*sqrt(bn*Y(2))*M(2); %1--0
N8(3)=K_mask(3)*sqrt(3*an*Y(2))*M(3); %1--2
N8(4)=K_mask(4)*sqrt(2*bn*Y(3))*M(4); %2--1
N8(5)=K_mask(5)*sqrt(2*an*Y(3))*M(5); %2--3
N8(6)=K_mask(6)*sqrt(3*bn*Y(4))*M(6); %3--2
N8(7)=K_mask(7)*sqrt(an*Y(4))*M(7); %3--4
N8(8)=K_mask(8)*sqrt(4*bn*Y(5))*M(8); %4--3


D(1) = -N8(1)+N8(2);
D(2) = -N8(2)-N8(3)+N8(1)+N8(4);
D(3) = -N8(4)-N8(5)+N8(3)+N8(6);
D(4) = -N8(6)-N8(7)+N8(5)+N8(8);
D(5) = -N8(8)+N8(7);

D = D/sqrt(N);
end



% Diffusion matrix for Na (Thomas and Pu)
function   D = DNafull(V,Y,N,M,Na_mask) 
%V is voltage, Y stands for probablity at each state (we use Y-Ybar)
%N is the dimension or number of Na Channels, M is randn 20 by 1
D = zeros(8,1);
Y=Y.*(Y>0); %to exclude negative numbers added by SP&PJT 10/08/2018
y00 = Y(1);
y10 = Y(2);
y20 = Y(3);
y30 = Y(4);
y01 = Y(5);
y11 = Y(6);
y21 = Y(7);
y31 = Y(8);

% noise for these 20 transactions
N20=zeros(20,1);
%save all these alpha and beta values for computational efficiency
ah=alphah(V);
bh=betah(V);
am=alpham(V);
bm=betam(V);
N20(1)=Na_mask(1)*sqrt(ah*y00)*M(1); %00--01
N20(2)=Na_mask(2)*sqrt(bh*y01)*M(2); %01--00
N20(3)=Na_mask(3)*sqrt(3*am*y00)*M(3); %00--10
N20(4)=Na_mask(4)*sqrt(bm*y10)*M(4); %10--00
N20(5)=Na_mask(5)*sqrt(ah*y10)*M(5);  %10--11
N20(6)=Na_mask(6)*sqrt(bh*y11)*M(6);  %11--10
N20(7)=Na_mask(7)*sqrt(2*am*y10)*M(7);%10--20
N20(8)=Na_mask(8)*sqrt(2*bm*y20)*M(8); %20--10
N20(9)=Na_mask(9)*sqrt(ah*y20)*M(9); %20--21
N20(10)=Na_mask(10)*sqrt(bh*y21)*M(10); %21--20
N20(11)=Na_mask(11)*sqrt(am*y20)*M(11); %20--30
N20(12)=Na_mask(12)*sqrt(3*bm*y30)*M(12);%30--20
N20(13)=Na_mask(13)*sqrt(ah*y30)*M(13); %30--31
N20(14)=Na_mask(14)*sqrt(bh*y31)*M(14); %31--30
N20(15)=Na_mask(15)*sqrt(3*am*y01)*M(15);%01--11
N20(16)=Na_mask(16)*sqrt(bm*y11)*M(16); %11--01
N20(17)=Na_mask(17)*sqrt(2*am*y11)*M(17);%11--21
N20(18)=Na_mask(18)*sqrt(2*bm*y21)*M(18);%21--11
N20(19)=Na_mask(19)*sqrt(am*y21)*M(19);%21--31
N20(20)=Na_mask(20)*sqrt(3*bm*y31)*M(20);%31--21

D(1) = -N20(1)-N20(3)+N20(2)+N20(4) ;
D(2) = -N20(4)-N20(5)-N20(7)+N20(3)+N20(6)+N20(8);
D(3) = -N20(8)-N20(9)-N20(11)+N20(7)+N20(10)+N20(12);
D(4) = -N20(12)-N20(13)+N20(11)+N20(14);
D(5) = -N20(2)-N20(15)+N20(1)+N20(16);
D(6) = -N20(6)-N20(16)-N20(17)+N20(5)+N20(15)+N20(18);
D(7) = -N20(10)-N20(18)-N20(19)+N20(9)+N20(17)+N20(20);
D(8) = -N20(14)-N20(20)+N20(13)+N20(19);

D = D/sqrt(N);
end

