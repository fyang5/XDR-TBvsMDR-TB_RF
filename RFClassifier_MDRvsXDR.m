%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This program is to analyze CT data based on NIAID data by Jan_2021
%
% Feng Yang, NLM, Feb 24, 2020.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all; clc; close all;
thre = 0.45;
%% to analyze x-ray and ct combined data:
filename1 = '1184Patients_XDRetMDR_balanced.csv';
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
Nodsensi = varmat;
Nodsensi(~strcmp(xtypeRS,'XDR'),:)=[];
% % table1 = array2table(Nodsensi,'VariableNames',featname);
% % writetable(table1,'1578patients_numCollapse_sensitive.xlsx');
lab0 = patlab;
lab0(~strcmp(xtypeRS,'XDR'),:)=[];

%NodDR = numNod;
%NodDR = numCav;
%%%%% 29 features%%%%%
NodDR = varmat;
%NodDR =[numCav];%[casemat,gend,age, numNod, numCav,numCollap, infil,abnper,effuper,biMediaNode,nonTBabnorm]; %[casemat,gend,age];
NodDR(strcmp(xtypeRS,'XDR'),:)=[];
% % table1 = array2table(NodDR,'VariableNames',featname);
% % writetable(table1,'1578patients_numCollapse_resistant.xlsx')
lab1 = patlab;
lab1(strcmp(xtypeRS,'XDR'),:)=[];
%% without data augmentation
% numNod_aug = [Nodsensi;NodDR];
% lab_aug = [lab0;lab1];
%% data augmentation
numx = NXdr-NMdr;
%% customized the k fold for test and training
numNod_aug = [Nodsensi;NodDR];
lab_aug = [lab0;lab1];
k=10;
fname4 = [sprintf('%dPatients',length(xtypeRS)),'_indices_XDRvsMDR_2021.mat'];
if exist(fname4)
    load(fname4)
else
    indices = crossvalind('Kfold',lab_aug,k);
    save(fname4,'indices');
end
c=lines(k);
%%  machine classifier
for i = 1:k
    testlab = lab_aug(indices == i);
    testNod = numNod_aug(find(indices == i),:);
    trainlab = lab_aug(indices ~= i);
    trainNod = numNod_aug(find(indices ~= i),:);
    countcats(categorical(testlab))
    countcats(categorical(trainlab))
    %%%%%%% RF classification
    rfModel = TreeBagger(100,trainNod,trainlab,'OOBPrediction','On','Method','classification','OOBPredictorImportance','On','MinLeafSize',5);
    [predictedLabels,scorePred] = predict(rfModel,testNod);
    predictedLabels = str2double(predictedLabels);
    testlab_aug = testlab;
    accuracy(i) = sum(predictedLabels==testlab_aug)/numel(testlab_aug);
    sensi(i) = sum(predictedLabels==testlab_aug & testlab_aug==1)/sum(testlab_aug==1);
    speci(i) = sum(predictedLabels==testlab_aug & testlab_aug==-1)/sum(testlab_aug==-1);
    preci(i) = sum(predictedLabels==testlab_aug & testlab_aug==1)/sum(predictedLabels==1);
    f_score(i) = 2*sensi(i)*preci(i)/(sensi(i)+preci(i));
    %Compute the posterior probabilities (scores).
    %     mdlSVM = fitPosterior(SVMModel);
    %     [~,score_svm] = resubPredict(mdlSVM);
    %    [X,Y,T,AUC(i)] = perfcurve(testlab_aug,score_svm(:,mdlSVM.ClassNames),'1') ;
    [X,Y,T,AUC(i)] = perfcurve(testlab_aug,scorePred(:,2),'1') ;
    figure(3);plot(X,Y,'r','LineWidth',2,'color',c(i,:));grid on;hold on;
    
end
xlabel('False positive rate');
ylabel('True positive rate');
legend({'Fold1','Fold2','Fold3','Fold4','Fold5','Fold6','Fold7','Fold8','Fold9','Fold10'})
fname5 = [sprintf('ROC_%dpatients_%d',size(part1,1),size(NodDR,2)),'features_RF.fig'];
savefig(fname5)

avgSensi = mean(sensi)
stdSensi = std(sensi)
avgSpeci = mean(speci)
stdSpeci = std(speci)
avgPreci = mean(preci)
stdPreci = std(preci)
avgF = mean(f_score);
stdF = std(f_score);
avgAccur = mean(accuracy)
stdAccur = std(accuracy)
avgAUC = mean(AUC)
stdAUC = std(AUC)