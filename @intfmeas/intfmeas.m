classdef intfmeas < handle
    %tigwelding Summary of this class goes here
    %   Detailed explanation goes here

    properties

        % meta data 
        meta_data_tbl = [];
        meta_row_index = 0;
        meas_name = [];
        meas_dir = [];
        meas_filename = [];
        data_file_path = [];
        distance = nan;
        antenna_gain = nan;

        % the data and properties
        meas_data_tbl = [];     % raw measured data as matrix
        tt = [];               % durations from beginning in seconds
        meas_pwr_dBm = [];      % measured powers
        ff = [];                % the frequencies
        max_meas_pwrs = [];     % measured peak powers across freq
        avg_meas_pwrs = [];     % measured avg powers across freq
        channelUtilization = []; % channel utilization above thresholds
        bandwidthDurations = []; % array of bandwidths and durations above thresholds
        connectedRegions = [];   % contains connected regions
        connectedRegionStats = [];  % contains bounded box information on regions
        connectedRegionBoxesScaled = []; % contains all of the spectral activity events
        dbscanClusters  = [];  % results from dbscan clustering

        % output file information
        path_to_plots = '';

        % resampler filter
        Fs = 625e6;

    end

    properties (Constant)
        C = 299792458;  % speed of light m/s
        % Fc = 2450e6;    % Hz
        % FreqLimit = 50e6; % Hz
        % Rload = 50; % Load in Ohms
        ReferenceDistance = 5; % in meters

        % In Wi-Fi networks, backoff typically begins when the energy
        % detect (ED) threshold of about -71 dBm is exceeded. For 802.11
        % preamble detection, the signal detect (SD) threshold is generally
        % lower, around -91 dBm.   What we care about is interference that
        % can cause degradation of performance for, e.g., a Wi-Fi network.
        % For this reason, we will select levels above the minimum level
        % unreliable level of -90 dBm which is considered a very weak
        % signal level (RSSI).
        UtilizationThresholds = [-79 -85 -91];  % for utilization metrics based on backoff
        UtilizationThresholdsStrings = {'Above -79 dBm at 5 m';'Above -85 dBm at 5 m';'Above -91 dBm at 5 m'};

        % wifi channel map
        PsuedoWiFiChannelBounds = [ ...
            2412-10, 2412+10;
            2437-10, 2437+10;
            2462-10, 2462+10
            ];

        % parameters for DBSCAN clustering
        % TODO: DELETE LINE powerThreholdDBSCAN_dBm = -71.5;
        maxDistanceDBSCAN_Hz = 20e6;
        dbscanEpsilon_dB = 1.5; % +/- 1.5 dB neighborhood
    end


    methods(Static)

        metadata = importMeta(obj, workbookFile)
        X = importDataFile(obj, workbookFile)
        L = freeSpaceGain(dist, fc)

        function tt = formatTimeStamps(tt)
            %tt=strrep(tt,"-05","");
            tt=regexprep(tt,"-0.","");
            tt=strrep(tt,'T',' ');
            tt = datetime(tt,"InputFormat","yyyy/MM/dd HH:mm:ss.SSS");
            tt = diff(tt);
            tt = [0; (seconds(cumsum(tt)))];  % in seconds from the beginning
        end

        function [figPathFull, pngPathFull] = savePlotTo(hFig, sPathToFolder, sRootName, sPlotTypeName)
            fpath = strcat(sPathToFolder, '/', sRootName, ' - ', sPlotTypeName);
            figPathFull = strcat(fpath, '.fig');
            savefig(hFig, figPathFull);
            pngPathFull = strcat(fpath, '.png');
            print(hFig, pngPathFull, '-dpng', '-r300');
        end

        function addWifiChannelToPlot(fRangeMeas, f_scale, color, FaceAlpha, EdgeColor, LineStyle)

            hold on

            % Determine if the wifi freqs in the range of measurements
            Yscale = ylim();
            Ybottom = Yscale(1);
            Ytop = Yscale(2);
            for ii = 1:size(intfmeas.PsuedoWiFiChannelBounds,1)
                clow = intfmeas.PsuedoWiFiChannelBounds(ii,1);
                chigh = intfmeas.PsuedoWiFiChannelBounds(ii,2);
                if (clow >= fRangeMeas(1)/f_scale) && (chigh <= fRangeMeas(2)/f_scale)
                    X = [ ...
                        intfmeas.PsuedoWiFiChannelBounds(ii, 1) ...
                        intfmeas.PsuedoWiFiChannelBounds(ii, 2) ...
                        intfmeas.PsuedoWiFiChannelBounds(ii, 2) ...
                        intfmeas.PsuedoWiFiChannelBounds(ii, 1)];
                    Y = [Ytop Ytop Ybottom Ybottom];
                    fill(X, Y, color, 'FaceAlpha', FaceAlpha, ...
                        'LineStyle', LineStyle, 'EdgeColor', EdgeColor);
                end
            end

            hold off

        end

        function dist = dbscan_Distance(ZI, ZJ)
            % first column is frequency (Hz)
            % second is time (secs)

            % by power
            % assuming the out of power range already set to -Inf
            dist = abs(ZI(3) - ZJ(:,3));  

            % now by distance in frequency
            indsFar = abs(ZJ(:,1)-ZI(1)) > intfmeas.maxDistanceDBSCAN_Hz;
            dist(indsFar) = nan;

        end

    end

    methods
        function obj = intfmeas(meta_data_tbl, meta_row_index, path_to_plots)
            obj.meta_data_tbl = meta_data_tbl;
            obj.meta_row_index = meta_row_index;
            obj.path_to_plots = path_to_plots;
            obj.antenna_gain = table2array(meta_data_tbl(meta_row_index,"NominalAntennaGain"));
            obj.distance = table2array(meta_data_tbl(meta_row_index,"Distance"));
        end

        function loadMeasData(obj)
            % import the data file
            jj = obj.meta_row_index;
            obj.meas_name = table2array(obj.meta_data_tbl(jj, 1));
            obj.meas_dir = table2array(obj.meta_data_tbl(jj, 2));
            obj.meas_filename = table2array(obj.meta_data_tbl(jj, 3));
            obj.data_file_path = strcat(obj.meas_dir, '/', obj.meas_filename);
            obj.meas_data_tbl = intfmeas.importDataFile(obj.data_file_path);

            % clean the data rows
            obj.meas_data_tbl = rmmissing(obj.meas_data_tbl);            
        
            % get measurement times and frequencies
            obj.ff = double(table2array(obj.meas_data_tbl(1,2:end)));
            obj.ff = obj.ff*1e3;  % reported frequency in KHz
            t = table2array(obj.meas_data_tbl(2:end,1));
            obj.tt = intfmeas.formatTimeStamps(t);  % durations from beginning in seconds
        
            % now extract the measurements
            obj.meas_pwr_dBm = table2array(obj.meas_data_tbl(2:end,2:end));    

            % compute some basic interference metrics
            obj.max_meas_pwrs = max(obj.meas_pwr_dBm,[],1);
            obj.avg_meas_pwrs = mean(obj.meas_pwr_dBm,1);

            % compute the utilization metrics
            obj.computeUtilizationAboveThresholds()
        end

        function scalePowerToReferenceDistance(obj)
            measGain = intfmeas.freeSpaceGain(obj.distance, mean(obj.ff));
            refGain = intfmeas.freeSpaceGain(intfmeas.ReferenceDistance, mean(obj.ff));
            obj.meas_pwr_dBm = obj.meas_pwr_dBm + (refGain-measGain);
        end

        function computeUtilizationAboveThresholds(obj)
            utilization = zeros(length(obj.UtilizationThresholds),size(obj.meas_pwr_dBm,2));
            for utii = 1:length(obj.UtilizationThresholds)
                ut = obj.UtilizationThresholds(utii);
                derUtilization = obj.meas_pwr_dBm > ut;
                derUtilization = sum(derUtilization)/size(derUtilization,1);
                utilization(utii,:) = derUtilization;
            end
            obj.channelUtilization = utilization;
        end

        function plotIntensityMap(obj, t_scale, f_scale)
            s=pcolor(obj.ff/f_scale,obj.tt/t_scale,obj.meas_pwr_dBm);
            xlabel('frequency (MHz)');
            ylabel('time (s)');
            set(s, 'EdgeColor', 'none');
            s.FaceColor = 'interp';
            colormap turbo
            colorbar
        end

        function plotPowerSpectrum(obj, f_scale)
            % plot max and average power vs frequency
            plot(obj.ff/f_scale, [obj.max_meas_pwrs(:), obj.avg_meas_pwrs(:)]);
            xlabel('frequency (MHz)');
            ylabel('Power (dBm)');
            legend(['max';'avg'],'AutoUpdate','off')
        end

        function plotUtilizationAboveThresholds(obj, f_scale)
            % plot channel utilization above the thresholds
            plot(obj.ff/f_scale, obj.channelUtilization);
            xlabel('frequency (MHz)');
            ylabel('Pr. Channel Utilization');
            legend(obj.UtilizationThresholdsStrings,'AutoUpdate','off');
        end

        function computeBandwidthDurationsAboveThresholds(obj, pwrthresh, eventarea, solidity, t_scale, f_scale)

            connectivity = 1;
            X = obj.meas_pwr_dBm;
            filter = ones(connectivity,1)/connectivity;
            % X = conv2(X,filter,'same');
            X = conv2(X,filter);
            above = X > pwrthresh;
            imagesc(obj.ff/f_scale,obj.tt/t_scale,above);
            set(gca,'YDir','normal')
            xlabel('frequency (MHz)');
            ylabel('time (s)');            
            colormap gray

            obj.connectedRegions = bwconncomp(above, 8);
            obj.connectedRegionStats = regionprops(obj.connectedRegions,'BoundingBox','Area','Solidity');    

            % created table for properties of connected regions
            connectedRegionBoxesScaledColumnNames = {'Start Freq (MHz)', 'Start Time (s)', 'Bandwidth (MHz)', 'Duration'};
            BoxesScaled = [];

            % overlay bounding boxes
            hold on;
            dt = obj.tt(end)/size(above,1);
            df = (obj.ff(end)-obj.ff(1))/size(above,2);
            ffs = obj.ff(1);
            tts = obj.tt(1);
            
            % Loop through each connected component and plot the bounding boxes
            kk = 1;
            for ii = 1:length(obj.connectedRegionStats)
                % Get the bounding box for the current component
                bb = obj.connectedRegionStats(ii).BoundingBox;

                % ignore small and unfilled events
                % basically want to keep events connected in frequency and
                % time that are significant in impact
                if obj.connectedRegionStats(ii).Area < eventarea || ...
                    obj.connectedRegionStats(ii).Solidity > solidity
                    continue
                end

                % scale and bias each bounding box
                bb(1) = bb(1) - 0.5;
                bb(2) = bb(2) - 0.5;
                bbs = [ ...
                    (bb(1)*df+ffs)/f_scale, ...
                    (bb(2)*dt+tts)/t_scale, ...
                    bb(3)*df/f_scale, ...
                    bb(4)*dt/t_scale];

                BoxesScaled = [BoxesScaled; bbs];
                kk = kk + 1;
                
                % Plot the bounding box
                rectangle('Position', bbs, 'EdgeColor', 'r', 'LineWidth', 2);
            end
            hold off

            % Add data to table for connected regions
            if ~isempty(BoxesScaled)
                obj.connectedRegionBoxesScaled = array2table(BoxesScaled);
                obj.connectedRegionBoxesScaled.Properties.VariableNames = ...
                    connectedRegionBoxesScaledColumnNames;
            end
        end        

        function plotTimeSeries(obj, titlestr)
            x = 20*log10(abs(obj.cData));
            t = 1000*(0:length(x)-1)/obj.Fs;
            plot(t,x)
            xlabel('time (ms)')
            ylabel('Measured Interference Amplitude (dB-V)')
            title(titlestr);
            drawnow
            sroot = table2array(obj.meta_data_tbl(obj.meta_row_index, 'Directory'));
            tigwelding.savePlotTo(gcf, obj.path_to_plots, sroot, 'timeseries');
            close(gcf)
        end

        function computeClustersDBScan(obj, pwrthresh, minpts, decrate, f_scale)
            powers = obj.meas_pwr_dBm;
            % imagesc(powers);

            if size(powers,1) > 800
                % Define a Gaussian smoothing filter
                % filter = fspecial('gaussian', [3, 3], 0.5);
                filter = fspecial('gaussian', decrate, 1/decrate);
                % filter = filter/sum(filter(:));
                
                % Smooth the matrix using 2D convolution
                powers2 = conv2(powers, filter, 'same');
                
                % Downsample the matrix (though it's already small, we'll use 'imresize')
                powers2 = imresize(powers2, 1/decrate, 'bilinear');

                % Downsample the freq and time coordinates
                ff2 = obj.ff(1:decrate:end, 1:decrate:end);
                tt2 = obj.tt(1:decrate:end, 1:decrate:end);
                
                imagesc(ff2/f_scale,tt2,powers2);
                set(gca,'YDir','normal')
                colorbar
            else
                powers2 = powers;
                % Downsample the freq and time coordinates
                ff2 = obj.ff;
                tt2 = obj.tt;
                imagesc(ff2/f_scale,tt2,powers2);
                set(gca,'YDir','normal')
                colorbar
            end

            % form the matrix used for dbscan
            [row, col] = size(powers2);
            [X, Y] = meshgrid(obj.ff(1:col), obj.tt(1:row));
            data = [X(:), Y(:), powers2(:)];

            % clean out out of range measurements
            rowsUnder = data(:,3)<pwrthresh;
            data(rowsUnder, 3) = -Inf;  % will cause nan distance

            % Apply DBSCAN clustering
            [idx, ~] = dbscan(data, intfmeas.dbscanEpsilon_dB, minpts, 'Distance', @intfmeas.dbscan_Distance);
            
            % Reshape the cluster indices back into the original matrix shape
            clusters = reshape(idx, row, col);
            obj.dbscanClusters = clusters;
            figure()
            imagesc(ff2/f_scale, tt2, clusters);
            set(gca,'YDir','normal')
            xlabel('Frequency (MHz)');
            ylabel('Time (s)');
            % grid on;         
        end
    end
end






