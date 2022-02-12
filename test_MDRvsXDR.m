%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This program is to analyze CT data based on NIAID data by Jan_2021
%
% Feng Yang, NLM, Feb 24, 2020.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all; clc; close all;
thre = 0.45;
load('rfmodel_XDRvsMDR.mat')
%% to analyze x-ray and ct combined data:
filename1 = 'test.csv';
part1 = readtable(filename1,'FileType','spreadsheet','PreserveVariableNames',1,'Sheet',1);
xtypeRS = part1.type_of_resistance;
%%
NXdr = length(find(strcmp(xtypeRS,'XDR')))
NMdr = length(find(contains(xtypeRS,'MDR non XDR')))
%% %%for radiological features from CT annotations
nvar = part1.Properties.VariableNames;
varmat = [];
varname = [];
for k = 5:15
    if k~=13 && k~=14 && k~=7 %%k~=7 remove the country as feature;&&k~=12 removes patient type
        namev = nvar(k);
        var1 = part1.(k);
        if isnumeric(var1)==1
            if contains(namev,'age')==1
                age = var1;
                age(age<15)=0;%%added by feng Jan 2021
                age(age>14&age<25)=1;
                age(age>24&age<35)=2;
                age(age>34&age<45)=3;
                age(age>44&age<55)=4;
                age(age>54&age<65)=5;
                age(age>64)=6;
                var1 = age;
            end
            var2 = var1;
            var2=unique(var2);
            var1cat = 1000*ones(size(var1,1),size(var1,2));
            for l = 1:length(var2)
                if isnan(var2(l))==1
                    var1cat(find(isnan(var1)))=100;
                else
                    var1cat(find(var1==var2(l)))=l;
                end
            end
        else
            var2 = var1;
            var2=unique(var2);
            var1cat = 1000*ones(size(var1,1),size(var1,2));
            for l = 1:length(var2)
                if strcmp(var2{l},'Not Reported')~=1
                    var1cat(strcmp(var1,var2{l}))=l;
                else
                    var1cat(strcmp(var1,'Not Reported'))=100;
                end
            end
        end
        num_nan = length(find(var1cat==100))
        if num_nan< size(part1,1)*thre
            var1cat1 = var1cat;
            var1cat1(var1cat1==100)=[];
            a1=round(mean(var1cat1));
            var1cat(var1cat==100)=a1;
            varmat = [varmat,var1cat];
            varname = [varname,namev];
        end
    end
end
%% for radiological findings from CT images

for i = 40:65%%46:65 for 25 radiological features; 40:65 if just 20 radiological features; these columns are for X-ray annotations
    if i~=45
        namev = nvar(i);
        var1 = part1.(i);
        var2 = var1;
        var2=unique(var2);
        var1cat = 1000*ones(size(var1,1),size(var1,2));
        for j = 1:length(var2)
            if strcmp(var2{j},'Not Reported')~=1
                var1cat(strcmp(var1,var2{j}))=j;
            else
                var1cat(strcmp(var1,'Not Reported'))=100;
            end
        end
        var1cat1 = var1cat; var1cat1(var1cat1==100)=[];a1=round(mean(var1cat1));
        var1cat(var1cat==100)=a1;
        %%
        varmat = [varmat,var1cat];
        varname = [varname,namev];
    end
end
%% using smote
patlab = xtypeRS;
patlab(strcmp(xtypeRS,'XDR')) = {'XDR'};
patlab(contains(xtypeRS,'MDR non XDR')) = {'MDR'};
%%for smote
patlab1 = 1000*ones(size(patlab,1),size(patlab,2));
patlab1(strcmp(xtypeRS,'XDR')) = -1;
patlab1(~strcmp(xtypeRS,'XDR')) = 1;
patlab = patlab1;
%%%%%29 featureas%%%%
testNod = varmat;
testlab =  patlab;
[predictedLabels,scorePred] = predict(rfModel,testNod);
predictedLabels = str2double(predictedLabels);
testlab_aug = testlab;
accuracy = sum(predictedLabels==testlab_aug)/numel(testlab_aug);
sensi = sum(predictedLabels==testlab_aug & testlab_aug==1)/sum(testlab_aug==1);
speci = sum(predictedLabels==testlab_aug & testlab_aug==-1)/sum(testlab_aug==-1);
preci = sum(predictedLabels==testlab_aug & testlab_aug==1)/sum(predictedLabels==1);

[X,Y,T,AUC] = perfcurve(testlab_aug,scorePred(:,2),'1') ;
figure(3);plot(X,Y,'r','LineWidth',2);grid on;

xlabel('False positive rate');
ylabel('True positive rate');
