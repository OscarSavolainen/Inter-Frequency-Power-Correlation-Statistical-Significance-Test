% Script for plotting and statistically testing the normality of the
% WN-ISCM distributions.
% Firstly, a grid of histograms is plotted that graphically shows the
% normality of the null distributions. 
% Secondly, 10 statistical tests for normality are run on the null
% distributions to determine whether they are normal or not.

% Initialise
clearvars -except f
close all
Inter_Scale_Stat_Sig_Sabes_Parameters;

sessions_vector = 1:15;
channels_vector = 1:96;

use_IAAFT_or_FT_phase_ran_nulls  = 'FT'; % FT or IAAFT
nb_plots = 10; % how many channel-session pairs to test the normality of. The subset of pairs is random.

% Which figures to plot
plot_figures.norm_histograms = false; % shows histograms of different ISCs, can verify normality
plot_figures.individual_norm_tests = false; % shows stat-sig maps for 10 different normality tests (bue = normal, red = non-normal, FDR of 0.05 for each test)
plot_figures.summed_norm_tests = true; % shows stat-sig map for all normality tests (blue = at least 8/10 tests found it to be normal, red = atleast 2/10 tests found it to be non-normal, green = all tests found it to be normal, FDR at 0.05 individually for each test)

% channel_session_pair = [1 1; ...
%                        2 3; ...
%                        4 6; ...
%                        6 1; ...
%                        10 8; ...
%                        96 2; ...
%                        93 1];
channel_session_pair(:,1) = randi([min(sessions_vector) max(sessions_vector)],nb_plots,1); % selects random subset of sessions
channel_session_pair(:,2) = randi([min(channels_vector) max(channels_vector)],nb_plots,1); % selects random subset of channels
                   

%% Iterate through chosen channel-session pairs
% chan_sess = 0;
for chan_sess = 1:length(channel_session_pair(:,1))
    clearvars -except plot_figures channel_session_pair chan_sess proportion counter_MC stored_threshold f use_IAAFT_or_FT_phase_ran_nulls
    
    Inter_Scale_Stat_Sig_Sabes_Parameters;
    return_test_summary = false; % if true, returns summary of statistical testing for each null distribution.
%     chan_sess = chan_sess + 1;
    
    %% Phase-ran ISCMs
    if strcmp(use_IAAFT_or_FT_phase_ran_nulls,'FT')
        load([save_FT_phase_ran_ISCMs,'\Session_',num2str(channel_session_pair(chan_sess,1)),'\Channel_',num2str(channel_session_pair(chan_sess,2)),'.mat'])
    elseif strcmp(use_IAAFT_or_FT_phase_ran_nulls,'IAAFT')
        load([save_IAAFT_phase_ran_ISCMs,'\Session_',num2str(channel_session_pair(chan_sess,1)),'\Channel_',num2str(channel_session_pair(chan_sess,2)),'.mat'])
    else
        error('"use_IAAFT_or_FT_phase_ran_nulls" variable should equl "FT" or "IAAFT"')
    end
    nb_MCs = length(compressed_r_phase(1,:));
    
    for mc_iteration = 1:nb_MCs
        C_noises(:,:,mc_iteration) = reshape_1D_vector_to_2D_symmetric_matrix(compressed_r_phase(:,mc_iteration));
    end

    %% Plot Histograms
    % Visually observe the null distributions for various inter-scale
    % correlations
    if plot_figures.norm_histograms
        counter = 0;
        fig = figure;
        selected_scale = 30; % arbitrary scale
        for i = 5:15:length(f)-15 % random choice of histograms to plot, it gives 9 values that fit a 3x3 grrid

            counter = counter +1;
            if i == selected_scale
                continue
            end
            if counter > 9
                continue
            end

            squeezed_C_list = [squeeze(C_noises(selected_scale,i,1:nb_MCs))]; % C(selected_scale,i);  % vector of [C(k,kk) and all C_noise(k,kk)]. squeezed_C_list(1) is C(k,kk).

            % 3x3 subplot grid of histograms of null distributions
            subplot(3,3,counter)
            histogram(squeezed_C_list)
            title(['Histogram of \it{\bf{\rho}_{',num2str(selected_scale),',',num2str(i),'}}'])%
            xlabel('')
            ylabel('')

        end

        % Figure labels and title
        han=axes(fig,'visible','off'); 
        han.Title.Visible='on';
        han.XLabel.Visible='on';
        han.YLabel.Visible='on';
        ylabel(han,'Count');
        xlabel(han,'Correlation');
        title(['Sess. ',num2str(channel_session_pair(chan_sess,1)),' - Chann. ',num2str(channel_session_pair(chan_sess,2)),'  {\itn}: ',num2str(nb_MCs),'; Histogram of MC processes \it{\bf{\rho}_{',num2str(selected_scale),',',num2str(i),'}}'])
    end

    %% Test normality of C_noises, obtain marginal p-values for each normality test
    if length(C_noises(1,1,:))> 899 % (the function normalitytest requires fewer than 900 elements).
        indices = datasample(1:nb_MCs,899,'Replace',false); % randomly sample 899 elements from each null distributions
        not_indices = setdiff(1:nb_MCs,indices);
        C_noises(:,:,not_indices) = [];
        nb_MCs = 899;
    end

    clear p_stored map_sig
    p_stored = ones(length(f),length(f),10);
    for i = 1:p
        fprintf(['Testing, curently at row ',num2str(i),' of ',num2str(p),'\n'])        
        for j =1:i-1
            if i == j
                continue
            end
            squeezed_C_noises = squeeze(C_noises(i,j,:)); % vector of all C_noise(k,kk)
            norm_C_noises(i,j,:) = (squeezed_C_noises-mean(squeezed_C_noises))/std(squeezed_C_noises);

            % Test the normality of the null distributions, based on 10
            % statistical tests
            Results = normalitytest(squeeze(norm_C_noises(i,j,:))',return_test_summary);

            % Store the marginal p-values from each test for each
            % inter-scale correlation nulll distribution
            p_stored(i,j,:) = Results(:,2);
        end
    end


    %% Plot map of statistically non-normal distributions for each of the 10 tests
        
    fig = figure('Renderer', 'painters', 'Position', [50 50 1200 600]);
    % Iterate through normality statistical tests
    for test_stat = 1:length(Results)

        % Create matrix with indices of tested hypotheses
        counter = 0;
        for k1 = 1:p
            for kk = 1:k1-1
                counter = counter + 1;
                map(k1,kk) = counter;
            end
        end
        map(:,p) = 0;

        % Access stored p-values for the current normality test
        tt = squeeze(p_stored(:,:,test_stat));
        pp = reshape(tt,numel(tt),1);
        map2 = map;
        map2 = reshape(map2,numel(map2),1); % reshape into 1D vector
        map2(pp==1) = []; % there were lots of empty values, since only the bottom triangle of the matrix was tested
        pp(pp==1) = [];

        % When controlling the FDR under dependency at a value of
        % 0.05, what null distibutions are rejected as non-normal
        [h, crit_p, adj_ci_cvrg, adj_p] = fdr_bh(pp,0.05,'dep','yes');

        % Plot map of null distibutions rejected as non-normal for the
        % current statistical test
        subplot(2,5,test_stat)
        if sum(h)~= 0 % if some null distributions were rejected as non-null
            map_sig(:,:,test_stat) = return_FDR_stat_map(h,map2,f,test_stat,true); % transforms 1D vector into a 2D map appropriate for plotting
            title(num2str(test_stat))
            xlabel(''); ylabel('')
        else % if no null distributions were rejected as non-null, plot empty square
            ztemp = zeros(length(f));
            ztemp(1,1) = 1;
            plot_2D_colormap(ztemp,f,f,'log')
            title(num2str(test_stat))
        end      

        % Figure labels and title
        hp4 = get(subplot(2,5,10),'Position');
        hcb=colorbar('Position', [hp4(1)+hp4(3)+0.01  hp4(2)  0.02  hp4(2)+hp4(3)*5.6]);
            % title(hcb,'Correlation')
    %         if ~plot_abs_corr
    %             set(get(hcb,'label'),'string','Correlation');
    %         else
    %             set(get(hcb,'label'),'string','| Correlation |');
    %         end
        caxis([0 1])
        
        han=axes(fig,'visible','off'); 
        han.Title.Visible='on';
        han.XLabel.Visible='on';
        han.YLabel.Visible='on';
        ylabel(han,'Frequency (Hz)');
        xlabel(han,'Frequency (Hz)');
        title(['Sess. ',num2str(channel_session_pair(chan_sess,1)),' - Chann. ',num2str(channel_session_pair(chan_sess,2)),' ; {\itn}: ',num2str(nb_MCs),'; Binary map of statistically non-normal ',use_IAAFT_or_FT_phase_ran_nulls,' null ISCs, according',newline,'to at least 2 normality tests (FDR: 0.05 for each test, 1 = atleast 2 tests found it to be non-normal)',newline])    
%         title(['Sess. ',num2str(channel_session_pair(chan_sess,1)),' - Chann. ',num2str(channel_session_pair(chan_sess,2)),'  {\itn}: ',num2str(nb_MCs),'; Map of null distributions rejected as non-normal for each of the 10 tests',newline,'(Blue indicates that atleast 8 tests indicated normaity, Red indicates that at least 2 tests found non-normality,',newline,'Green found that 0 ISCs were non-normal for atleast 2 tests)',newline])

    end
    if ~plot_figures.individual_norm_tests
        close
    end
    
    %% Plot map of double rejected null distributions
    if plot_figures.summed_norm_tests
        % It shows which null distributions were rejected as non-normal by atleast
        % 2 statistical normality tests. The FDR was controlled at 0.05 for 
        % each test individually under dependency described in "Benjamini &
        % Yekutieli (2001) that is guaranteed to be accurate for any test 
        % dependency structure (e.g., Gaussian variables with any covariance
        % matrix) is used." (quote taken from fdr_bh function)

        tt = sum(map_sig,3); % sum of maps of rejected null distributions, shows how many tests rejected that null distribution as non-normal
        figure, plot_2D_colormap(single(tt>1),f,f,'log')
%         title(['Sess. ',num2str(channel_session_pair(chan_sess,1)),' - Chann. ',num2str(channel_session_pair(chan_sess,2)),' ; {\itn}: ',num2str(nb_MCs),'; Map of statistically',newline,'non-normal ',use_IAAFT_or_FT_phase_ran_nulls,' null ISCs,',newline,'(Blue = at least 8/10 tests indicate normality,',newline,'Red = atleast 2/10 tests indicate non-normality,',newline,'Green = all tests indicate normality, FDR at 0.05 individually for each test)'])
        title(['Sess. ',num2str(channel_session_pair(chan_sess,1)),' - Chann. ',num2str(channel_session_pair(chan_sess,2)),' ; {\itn}: ',num2str(nb_MCs),'; Binary map of statistically non-normal',newline,use_IAAFT_or_FT_phase_ran_nulls,' null ISCs, according to at least 2 normality tests',newline,'(FDR: 0.05 for each test, 1 = atleast 2 tests found it to be non-normal)'])    
        xlabel('Frequency (Hz)')
        ylabel('Frequency (Hz)')
        colorbar

        % Calculate how many doubly-rejected null distributions there are in a
        % given subset of the all null distributions. We draw a square
        % containing all of the lower frequencies, and make it smaller until
        % only 95% of the rejected null distributions are in the square. At an
        % FDR alpha of 0.05, this gives us a rough estimate of where the
        % non-normal null distributions are. The test statistics involving
        % these non-normal null distributions are automatically taken to be not
        % statistically significant.
        for f_counter = 1:numel(f)
            threshold = f(f_counter);

            temp_prop(f_counter,1) = 100*sum(sum(tt(f_counter:end,f_counter:end)>1))/sum(sum(tt>1));
            if temp_prop(f_counter,1) < 95
                f_counter = f_counter - 1;
                threshold = f(f_counter);
                break
            end
        end
        proportion(chan_sess,1) = 100*sum(sum(tt(f_counter:end,f_counter:end)>1))/sum(sum(tt>1));
        stored_threshold(chan_sess,1) =  threshold; % the frequency value X for which sub-X frequency inter-scale correlations are taken to be not significant because of the non-normality of the null distribution.

        % Draw white square showing sub-X inter-scale correlations that have
        % non-normal null distributions
        line([min(f) threshold],[threshold threshold],[1.1 1.1],'Color','white','LineWidth',2)
        line([threshold threshold],[min(f) threshold],[1.1 1.1],'Color','white','LineWidth',2)

        fprintf(['\n', num2str(proportion(chan_sess,1)),' %% of the null distributions that were ',...
                'rejected by atleast 2 normality tests were within \nthe white box in Figure "Map',...
                ' of statistically non-normal ',use_IAAFT_or_FT_phase_ran_nulls,' null inter-scale distributions,',newline,'according',...
                ' to at least 2 tests" \n'])
    end
end
