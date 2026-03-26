% SSD_Analysis.m
% Run after simulation completes to generate full analysis dashboard
% All plots work with or without simulation data

figure('Name','SSD Complete Analysis Dashboard',...
    'NumberTitle','off','Position',[50,50,1500,950],...
    'Color',[0.12 0.12 0.12]);

colors.rber    = [1.0, 0.4, 0.4];
colors.stage   = [0.4, 0.8, 0.4];
colors.health  = [0.4, 0.6, 1.0];
colors.journal = [1.0, 0.7, 0.2];
colors.btree   = [0.8, 0.4, 0.8];
colors.retired = [1.0, 0.3, 0.3];
colors.drvhlth = [0.3, 1.0, 0.5];
colors.iter    = [0.9, 0.9, 0.3];

t_dummy = linspace(0, 100, 1001)';

%--- Plot 1: RBER over time ---
subplot(3,3,1);
if exist('ws_rber','var')
    plot(ws_rber.time, ws_rber.signals.values,...
        'Color',colors.rber,'LineWidth',2);
else
    plot(t_dummy, 0.0001 + 0.0003*(t_dummy/100),...
        '--','Color',colors.rber,'LineWidth',2);
end
set(gca,'Color',[0.18 0.18 0.18],'XColor','w','YColor','w');
title('NAND RBER Over Time','Color','w','FontWeight','bold');
xlabel('Time (s)','Color','w'); ylabel('RBER','Color','w');
grid on; set(gca,'GridColor',[0.3 0.3 0.3]);

%--- Plot 2: Adaptive LDPC Wear Stage ---
subplot(3,3,2);
if exist('ws_stage','var')
    stairs(ws_stage.time, ws_stage.signals.values,...
        'Color',colors.stage,'LineWidth',2.5);
else
    pe = linspace(0,3000,1001);
    stg = ones(size(pe));
    stg(pe>=750)=2; stg(pe>=1500)=3; stg(pe>=2250)=4;
    stairs(t_dummy, stg,'--','Color',colors.stage,'LineWidth',2.5);
end
set(gca,'Color',[0.18 0.18 0.18],'XColor','w','YColor','w');
title('Adaptive LDPC Wear Stage','Color','w','FontWeight','bold');
xlabel('Time (s)','Color','w'); ylabel('Stage','Color','w');
yticks([1 2 3 4]);
yticklabels({'Stage 1 (Light)','Stage 2 (Mod)','Stage 3 (Heavy)','Stage 4 (EOL)'});
ylim([0.5 4.5]); grid on; set(gca,'GridColor',[0.3 0.3 0.3]);

%--- Plot 3: Health Score with thresholds ---
subplot(3,3,3);
if exist('ws_score','var')
    plot(ws_score.time, ws_score.signals.values,...
        'Color',colors.health,'LineWidth',2); hold on;
else
    plot(t_dummy, max(0,100-t_dummy*0.75),...
        '--','Color',colors.health,'LineWidth',2); hold on;
end
yline(70,'--','Color',[0.4 1.0 0.4],'LineWidth',1.5,'Label','Watchlist');
yline(50,'--','Color',[1.0 1.0 0.2],'LineWidth',1.5,'Label','Migrate');
yline(20,'--','Color',[1.0 0.3 0.3],'LineWidth',1.5,'Label','Retire');
set(gca,'Color',[0.18 0.18 0.18],'XColor','w','YColor','w');
title('Block Health Score','Color','w','FontWeight','bold');
xlabel('Time (s)','Color','w'); ylabel('Score','Color','w');
ylim([0 105]); grid on; set(gca,'GridColor',[0.3 0.3 0.3]);

%--- Plot 4: Three-Tier BBM ---
subplot(3,3,4);
if exist('ws_dram','var') && exist('ws_journal','var') && exist('ws_btree','var')
    yyaxis left
    plot(ws_dram.time, ws_dram.signals.values,...
        'Color',colors.health,'LineWidth',2); hold on;
    plot(ws_btree.time, ws_btree.signals.values,...
        'Color',colors.btree,'LineWidth',2);
    ylabel('Entry Count','Color','w');
    yyaxis right
    plot(ws_journal.time, ws_journal.signals.values,...
        'Color',colors.journal,'LineWidth',2);
    ylabel('Journal Fill %','Color','w');
else
    bad_sim = cumsum(rand(1001,1)*0.3);
    jfill   = mod(t_dummy*3, 100);
    btree_s = cumsum(rand(1001,1)*0.1);
    yyaxis left
    plot(t_dummy,bad_sim,'--','Color',colors.health,'LineWidth',2); hold on;
    plot(t_dummy,btree_s,'--','Color',colors.btree,'LineWidth',2);
    ylabel('Entry Count','Color','w');
    yyaxis right
    plot(t_dummy,jfill,'--','Color',colors.journal,'LineWidth',2);
    ylabel('Journal Fill %','Color','w');
end
set(gca,'Color',[0.18 0.18 0.18],'XColor','w','YColor','w');
title('Three-Tier Bad Block Manager','Color','w','FontWeight','bold');
xlabel('Time (s)','Color','w');
legend('DRAM Hash Table','B-Tree Size','Journal Fill %',...
    'TextColor','w','Color',[0.2 0.2 0.2],'Location','northwest');
grid on; set(gca,'GridColor',[0.3 0.3 0.3]);

%--- Plot 5: LDPC Parity Overhead per Stage ---
subplot(3,3,5);
stages   = [1 2 3 4];
parity   = [10 20 40 100];
overhead = parity/512*100;
b = bar(stages, overhead, 'FaceColor','flat');
b.CData = [0.4 0.8 0.4; 0.9 0.8 0.2; 1.0 0.5 0.1; 0.9 0.2 0.2];
set(gca,'Color',[0.18 0.18 0.18],'XColor','w','YColor','w');
title('LDPC Parity Overhead per Wear Stage','Color','w','FontWeight','bold');
xlabel('Wear Stage','Color','w'); ylabel('Overhead (%)','Color','w');
xticklabels({'Stage 1\newline(Light)','Stage 2\newline(Mod)',...
             'Stage 3\newline(Heavy)','Stage 4\newline(EOL)'});
for i=1:4
    text(i,overhead(i)+0.3,sprintf('%.1f%%',overhead(i)),...
        'HorizontalAlignment','center','Color','w','FontWeight','bold');
end
grid on; set(gca,'GridColor',[0.3 0.3 0.3]);

%--- Plot 6: Drive Health % ---
subplot(3,3,6);
if exist('ws_drv_health','var')
    plot(ws_drv_health.time, ws_drv_health.signals.values,...
        'Color',colors.drvhlth,'LineWidth',2.5);
else
    plot(t_dummy, max(0,100-t_dummy*0.25),...
        '--','Color',colors.drvhlth,'LineWidth',2.5);
end
set(gca,'Color',[0.18 0.18 0.18],'XColor','w','YColor','w');
title('Overall Drive Health %','Color','w','FontWeight','bold');
xlabel('Time (s)','Color','w'); ylabel('Health (%)','Color','w');
ylim([0 105]); grid on; set(gca,'GridColor',[0.3 0.3 0.3]);
yline(80,'--','Color',[1.0 0.8 0.2],'LineWidth',1.5,'Label','Warning');
yline(50,'--','Color',[1.0 0.3 0.3],'LineWidth',1.5,'Label','Critical');

%--- Plot 7: LDPC Max Iterations per Stage ---
subplot(3,3,7);
max_iters = [10 20 50 100];
b2 = bar(stages, max_iters, 'FaceColor','flat');
b2.CData = [0.3 0.6 1.0; 0.3 0.6 1.0; 1.0 0.6 0.2; 1.0 0.2 0.2];
set(gca,'Color',[0.18 0.18 0.18],'XColor','w','YColor','w');
title('Min-Sum BP Max Iterations per Stage','Color','w','FontWeight','bold');
xlabel('Wear Stage','Color','w'); ylabel('Max Iterations','Color','w');
xticklabels({'Stage 1','Stage 2','Stage 3','Stage 4'});
for i=1:4
    text(i,max_iters(i)+1,num2str(max_iters(i)),...
        'HorizontalAlignment','center','Color','w','FontWeight','bold');
end
grid on; set(gca,'GridColor',[0.3 0.3 0.3]);

%--- Plot 8: Circular Journal Flush Behavior ---
subplot(3,3,8);
t_j = linspace(0,100,2000);
jfill_demo = mod(t_j*4, 100);
plot(t_j, jfill_demo,'Color',colors.journal,'LineWidth',1.8); hold on;
yline(75,'--','Color',[1.0 0.3 0.3],'LineWidth',2,'Label','Flush @ 75%');
yline(95,'--','Color',[1.0 0.1 0.7],'LineWidth',1.5,'Label','Emergency @ 95%');
fill([0 100 100 0],[0 0 75 75],[0.2 0.6 0.2],'FaceAlpha',0.07,'EdgeColor','none');
fill([0 100 100 0],[75 75 100 100],[1.0 0.3 0.3],'FaceAlpha',0.07,'EdgeColor','none');
set(gca,'Color',[0.18 0.18 0.18],'XColor','w','YColor','w');
title('Circular Journal Fill & Flush Cycles','Color','w','FontWeight','bold');
xlabel('Time (s)','Color','w'); ylabel('Fill Level (%)','Color','w');
ylim([0 110]); grid on; set(gca,'GridColor',[0.3 0.3 0.3]);

%--- Plot 9: Retirement Pipeline Summary ---
subplot(3,3,9);
categories  = {'Healthy','Watchlist','Migrate','Retire'};
thresholds  = [100 70 50 20];
clrs        = [0.2 0.8 0.3; 0.8 0.8 0.1; 1.0 0.5 0.1; 0.9 0.2 0.2];
for i=1:4
    b3 = bar(i, thresholds(i)); hold on;
    b3.FaceColor = clrs(i,:);
    text(i, thresholds(i)+2, ...
        sprintf('%s\n< %d', categories{i}, thresholds(i)),...
        'HorizontalAlignment','center','Color','w',...
        'FontSize',8,'FontWeight','bold');
end
set(gca,'Color',[0.18 0.18 0.18],'XColor','w','YColor','w');
title('Predictive Retirement Stage Thresholds','Color','w','FontWeight','bold');
xlabel('Stage','Color','w'); ylabel('Health Score Threshold','Color','w');
xticks(1:4); xticklabels(categories);
ylim([0 115]); grid on; set(gca,'GridColor',[0.3 0.3 0.3]);

% Main title
sgtitle('SSD Adaptive LDPC + Three-Tier Bad Block Management — Full Analysis',...
    'Color','w','FontSize',14,'FontWeight','bold');
set(gcf,'Color',[0.10 0.10 0.10]);

fprintf('\n=================================================================\n');
fprintf('  SSD Analysis Dashboard generated successfully.\n');
fprintf('  9 plots covering all system components.\n');
fprintf('  Dashed lines = sample data. Run simulation for real data.\n');
fprintf('=================================================================\n');