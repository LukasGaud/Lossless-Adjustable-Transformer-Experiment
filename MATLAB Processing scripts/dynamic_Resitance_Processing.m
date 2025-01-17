close all
clear all
%% Office Mac
% Get the Raspberry Pi file
% [fileRP,pathRP] = uigetfile("*.csv")
fileRP = 'data.csv';
pathRP = '/Users/lg608/Dropbox (Cambridge University)/PhD/Experimental Work/Experimental Data/data/';
folder = '1116/1116 - Run9/';

offset = -0.015;
%% Good run

% Get Loadcell file
% [fileLC,pathLC] = uigetfile("*.csv")
fileLC = 'data_loadcell.csv'; %place loadcell data in the same folder as data.csv
%
%% Home Mac
% fileRP = 'data.csv';
% pathRP = '/Users/lg608/Documents/Armstrong/pos-control/';

% fileLC = 'data_loadcell.csv';
% pathLC = '/Users/lg608/Documents/Armstrong/pos-control/';
dataRP = readtable([pathRP, folder, fileRP], 'Delimiter', ',');
dataLC = readtable([pathRP, folder, fileLC]);
% data.RP.date = datetime(dataRPClock, 'InputFormat', 'eeeMMMddHH:mm:ssyyyy');
%
% dateBad = char(dataLC.Var1);
% dateMod1 = dateBad(:,[1:7, 10:end]);
% for i = 1:length(dateMod1)
%     data.LC.date(i, :) = datetime([dateMod1(i, 1:7), '20', dateMod1(i,8:end)]);
% end

data.RP.time = table2array(dataRP(:,1));
data.RP.targetP = table2array(dataRP(:,2));
data.RP.measP = table2array(dataRP(:,3));
% data.RP.torque = lowpass(dataRP(:,4), 10, 100);
data.RP.torque = table2array(dataRP(:,4));
% data.RP.torque = dataRP(:,5);
data.RP.current = table2array(dataRP(:,5));
data.RP.rotRaw = table2array(dataRP(:,6));
data.RP.pinionT = table2array(dataRP(:,7));
data.RP.pinionP = table2array(dataRP(:,8))/2048*2*pi;
data.RP.pinionCurrent = table2array(dataRP(:,9));
data.RP.torqueD = table2array(dataRP(:,10))/257*4.69;
data.RP.staticPos = table2array(dataRP(:,11))/2048*2*pi;
data.RP.moved = table2array(dataRP(:,15));
data.RP.direction = table2array(dataRP(:,12));
data.RP.coneID = table2array(dataRP(:,13));
data.RP.carriageID = table2array(dataRP(:,14));
data.RP.percentOutput = table2array(dataRP(:,16));
data.RP.posControl = table2array(dataRP(:,17));
data.RP.torqueStat = table2array(dataRP(:,18))*4.69/257;


data.LC.time = table2array(dataLC(:,2))/1000;
data.LC.torque =  table2array(dataLC(:,3)) - table2array(dataLC(1,3)) + offset;

syncData = fSyncData_v2(data.RP, data.LC);
procData.RP = fProcessData_v3(syncData.RP);
procData.LC = syncData.LC;
%% Calculating p value
x0 = 1;
options = optimoptions(@fmincon,'MaxFunctionEvaluations', 3e4);
x = fmincon(@(x)(fFindRatio_v4(x, procData)), x0, [], [], [], [], [], [], [], options);

p0 = x(1);
f = 6.689489472483746e-04;
% f = 5.810969921762468e-04;
% f = [0,1];
procData.RP.p1 = p0;
procData.RP.p= p0 + f(1)* procData.RP.pinionP*2048/2/pi;
%% Process stiction data
procData.RP.torqueSign = sign(procData.RP.percentOutput).*procData.RP.torque;
procData.RP.torqueSignLP = lowpass(procData.RP.torqueSign, 15, 100);
%% Match torques
x0 = 1;
c = fmincon(@(x)fMatchTorque(x, procData.RP.percentOutput, procData.RP.torqueSign), x0, [], [], [], [], [], [], []);

%% p value
p = procData.RP.p1 + f(1)* procData.RP.pinionP*2048/2/pi;
%% Averaged values
% Positive Velocity
f1 = figure;
subplot(3,1,1)
hold on
Ax1 = gca;
p1 = plot(procData.RP.time, procData.RP.torqueSign);
p2 = plot(procData.RP.time, -procData.LC.torque);
p3 = plot(procData.RP.time, procData.RP.posControl*max([max(abs(procData.RP.torqueSign)), max(abs(procData.LC.torque))]), 'k--');
% plot(procData.RP.time, -procData.LC.torqueLP)
ylabel('Torque, Nm')
title('Dynanic Resistance measurement')

subplot(3,1,2)
hold on
Ax2 = gca;
p21 = plot(procData.RP.time, procData.RP.measVp);
p22 = plot(procData.RP.time, procData.RP.posControl*max(abs(procData.RP.measVp)), 'k--');
ylabel('Angular Velocity, rad/s')
xlabel('Time, s')

subplot(3,1,3)
hold on
Ax3 = gca;
p31 = plot(procData.RP.time, procData.RP.pinionP);
p32 = plot(procData.RP.time, procData.RP.posControl*max(abs(procData.RP.pinionP)), 'k--');
ylabel('Carriage Position, rad')
xlabel('Time, s')


% pinionP = pinionP(pinionP<2.5);
procData.data = data;
pinionP = uniquetol(data.RP.carriageID, 0.1);
% targetV = uniquetol(data.RP.targetP/2048*2*pi, 0.01);
targetV = uniquetol(data.RP.coneID, 0.01);
indexPlotP = zeros(length(procData.RP.time),1);
indexPlotN = zeros(length(procData.RP.time),1);
oneVec = ones(length(procData.RP.time),1);
vVecP = [];
TVecP = [];
pVec = [];
for i = 1:length(pinionP)
    for j = 1:length(targetV)
        %         index1 = abs(procData.RP.pinionP - pinionP(i)) <0.1;
        index1 = abs(procData.RP.carriageID - pinionP(i)) <0.1;
        %         index2 = abs(procData.RP.targetP - targetV(j)) <0.01;
        index2 = abs(procData.RP.coneID - targetV(j)) <0.01;
        index3 = procData.RP.measVp > 0;
        index4 = procData.RP.posControl == 0;
        indexAll = index1 & index2 & index3 & index4;
        indexP = find(indexAll);
        index = indexP(13:end-3);
        indexPlotP(index) = indexPlotP(index) + 1;
        measVP(j,i) = mean(procData.RP.measVp(index));
        measPinionP(j,i) = mean(procData.RP.pinionP(index));
        pInst = p0 + f(1)*measPinionP(j,i)*2048/2/pi;
        %         torqAv(j,i) = mean(abs(procData.RP.torqueSign(index)));
        torqAvMotP(j,i) = mean(procData.RP.torqueSign(index));
        torqAvLCP(j,i) = mean(-procData.LC.torque(index));
        if i == 1 %|| j == 2
%         if j == 1 || j == 2
        else
        vVecP = [vVecP; measVP(j, i)];
        TVecP = [TVecP; torqAvLCP(j,i)];
        pVec = [pVec; pInst];
        end
        plot(Ax1, procData.RP.time(index), -procData.LC.torque(index), 'r.')
        plot(Ax2, procData.RP.time(index), procData.RP.measVp(index), 'r.')
    end
    avCarriage(i) = mean(measPinionP(:,i));
end

legID = 1;
figure
AxP = gca;
hold on
colorRange = ['k', 'b', 'g', 'm', 'r', 'c'];
for i = 1:length(pinionP)
    c = colorRange(i);
    plot(AxP, measVP(:,i), torqAvMotP(:,i), [c, 'x'], 'MarkerSize', 8, 'LineWidth', 2)
    plot(AxP, measVP(:,i), torqAvLCP(:,i), [c, 'o'], 'MarkerSize', 8, 'LineWidth', 2)
    legEntry{legID} = sprintf('Motor Torque, Carriage Position: %.2f', mean(measPinionP(:,i)));
    avCarriageP(i) = mean(measPinionP(:,i));
    legID = legID + 1;
    legEntry{legID} = sprintf('Loadcell Torque, Carriage Position: %.2f', mean(measPinionP(:,i)));
    legID = legID + 1;
end
legend(legEntry)
xlabel('Cone Rotation Speed, rad/s'); ylabel('Dynamic Resistance, Nm'); title('Dynamic Resistance')
ylim([0, max([max(abs(torqAvMotP(:))),max(abs(torqAvLCP(:)))]) + 0.03])

pinionP = uniquetol(data.RP.carriageID, 0.1);
% targetV = uniquetol(data.RP.targetP/2048*2*pi, 0.01);
targetV = uniquetol(data.RP.coneID, 0.01);

vVecN = [];
TVecN = [];
for i = 1:length(pinionP)
    for j = 1:length(targetV)
        %           index1 = abs(procData.RP.pinionP - pinionP(i)) <0.1;
        index1 = abs(procData.RP.carriageID - pinionP(i)) <0.1;
        %         index2 = abs(procData.RP.targetP - targetV(j)) <0.01;
        index2 = abs(procData.RP.coneID - targetV(j)) <0.01;
        index3 = procData.RP.measVp < 0;
        index4 = procData.RP.posControl == 0;
        indexAll = index1 & index2 & index3 & index4;
        indexN = find(indexAll);
        index = indexN(13:end-3);
        indexPlotN(index) = indexPlotN(index) + 1;
        measVN(j,i) = mean(procData.RP.measVp(index));
        measPinionP(j,i) = mean(procData.RP.pinionP(index));
        torqAvMotN(j,i) = mean(procData.RP.torqueSign(index));
        torqAvLCN(j,i) = mean(-procData.LC.torque(index));
        if i == 1 %|| i == 2    
%         if j == 1 || j == 2
        else
        vVecN = [vVecN; measVN(j, i)];
        TVecN = [TVecN; torqAvLCN(j,i)];
        end
        p4 = plot(Ax1, procData.RP.time(index), -procData.LC.torque(index), 'r.');
        p5 = plot(Ax2, procData.RP.time(index), procData.RP.measVp(index), 'r.');
    end
end
legend(Ax1,[p1, p2, p3, p4],{'Motor Torque', 'Loadcell Torque', 'Position / Velocity control switch', 'Values used for averaging'})
legend(Ax2, [p21, p22, p5], {'Velocity', 'Position / Velocity control switch', 'Values used for averaging'})

linkaxes ([Ax1, Ax2], 'x');

legID = 1;
figure
AxN = gca;
hold on
colorRange = ['k', 'b', 'g', 'm', 'r', 'c'];
for i = 1:length(pinionP)
    c = colorRange(i);
    plot(AxN, measVN(:,i), -torqAvMotN(:,i), [c, 'x'], 'MarkerSize', 8, 'LineWidth', 2)
    plot(AxN, measVN(:,i), -torqAvLCN(:,i), [c, 'o'], 'MarkerSize', 8, 'LineWidth', 2)
    legEntry{legID} = sprintf('Motor Torque, Carriage Position: %.2f', mean(measPinionP(:,i)));
    legID = legID + 1;
    legEntry{legID} = sprintf('Loadcell Torque, Carriage Position: %.2f', mean(measPinionP(:,i)));
    legID = legID + 1;
end
legend(legEntry)
xlabel('Cone Rotation Speed, rad/s'); ylabel('Dynamic Resistance, Nm'); title('Dynamic Resistance')
ylim([0, max([max(abs(torqAvMotN(:))),max(abs(torqAvLCN(:)))]) + 0.03])

%% INdex for latex
indexPlot = indexPlotP + indexPlotN;

%% Fitting a custom model
% Fitting a custom model
model = fittype(@(p1, p2, p3, p4, p, x) p1*x + p2 + p3*p.*x + p4*p, 'problem', 'p', 'independent', 'x', 'dependent' ,'y');
% model = fittype(@( p2, p3, p4, p, x) p2 + p3*p.*x + p4*p, 'problem', 'p', 'independent', 'x', 'dependent' ,'y');


fCustP = fit(vVecP, TVecP, model, 'problem', pVec, 'StartPoint', [0.6, 0.15, -0.3, -0.05]);
fCustN = fit(vVecN, TVecN, model, 'problem', pVec, 'StartPoint', [0.6, 0.15, -0.3, -0.05]);

p = p0 + f(1)* avCarriage*2048/2/pi;

fitP = fCustP.p1*measVP + fCustP.p2 +p.*measVP*fCustP.p3 +  p*(fCustP.p4);
fitN = fCustN.p1*measVN + fCustN.p2 +p.*measVN*fCustN.p3 +  p*(fCustN.p4);

pRange = linspace(0.65, 1.35, 4);
offsetP = fCustP.p2 + pRange*(fCustP.p4);
offsetN = fCustN.p2 + pRange*(fCustN.p4);

vRange = linspace(0, 5, 8);
slopeP = (fCustP.p1 + pRange'*(fCustP.p3)).*vRange;
slopeN = (-fCustN.p1 - pRange'*(fCustN.p3)).*vRange;
for i = 1:length(pinionP)
    c = colorRange(i);
    plot(AxP, measVP(:,i), fitP(:,i), c, 'MarkerSize', 8, 'LineWidth', 1)
    plot(AxN, measVN(:,i), -fitN(:,i), c, 'MarkerSize', 8, 'LineWidth', 1)
end

%% Plotting the offset
figure
hold on
plot(pRange, offsetP, 'k --x', 'LineWidth', 2)
plot(pRange, offsetN, 'b --x', 'LineWidth', 2)
ylim([0, 0.2])

figure
hold on
plot(vRange, slopeP', 'k --x', 'LineWidth', 2)
plot(vRange, slopeN', 'b --x', 'LineWidth', 2)
ylim([-0.1, 0.1])


