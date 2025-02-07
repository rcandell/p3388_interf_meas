% ANALYZE_MEASUREMENTS top level script to process measurements
%
% Author: Rick Candell
% Organization: National Institute of Standards and Technology
% Email: rick.candell@nist.gov

clear;
close all;
fclose all;

% meta data path
meta_path = './metadata.xlsx';
report_path = './report.tex';

% output files
path_to_plots = 'figs';

% open the meta data file
meta_data_tbl = intfmeas.importMeta(meta_path);

% scaling factors
tscale = 1;    % time dilation
fscale = 1e6;  % frequencies presented in MHz

% reporting 
R = latexreport(report_path);
R.open();

% what to enable
PMAP_ON = false;
PSPEC_ON = false;
PUTIL_ON = false;
PREGIONS_ON = false;
DBSCAN_ON = true;
SAVEWS_ON = false;

% loop through each row of the meta table
% for jj = 1:height(meta_data_tbl)
for jj = 5
    % construct an analysis object
    A = intfmeas(meta_data_tbl, jj, path_to_plots);

    % load the measurement data for analysis
    A.loadMeasData();
    R.addAnalysisObjectRef(A);
    disp('Processing ' + A.meas_name)
    R.addSubSection(A.meas_name);

    % scale power data to be at nominal distance in meters assuming FSPL
    A.scalePowerToReferenceDistance();

    % plot the data as intensities to vizualize the power levels over time
    % and frequency
    if PMAP_ON
        figure()
        A.plotIntensityMap(tscale,fscale);
        title('Power Spectrum Color Map for ' + A.meas_name)
        intfmeas.addWifiChannelToPlot(xlim*1e6, fscale, 'white', 0.1, 'k', '--');    
        [~, pngPathFull] = intfmeas.savePlotTo(gcf, path_to_plots, A.meas_name, 'pmap');   
        R.addSubSubSection('Power Spectral Density Vs. Time');
        R.addPngFigure(latexreport.FIG_FLOAT, pngPathFull, 'Power intensity in dBm versus time');
    end

    % gross power spectrum
    if PSPEC_ON
        figure()
        A.plotPowerSpectrum(fscale);
        title('Power Spectrum for ' + A.meas_name)
        intfmeas.addWifiChannelToPlot(xlim*1e6, fscale, 'white', 0.1, 'k', '--');
        [~, pngPathFull] = intfmeas.savePlotTo(gcf, path_to_plots, A.meas_name, 'powerspec');
        R.addSubSubSection('Gross Power Spectrum');
        R.addPngFigure(latexreport.FIG_FLOAT, pngPathFull, 'Power intensity in dBm versus time.');
    end

    % plot utilization above thresholds 
    % this will give a picture of amount of channel blocking power
    if PUTIL_ON
        figure()
        A.plotUtilizationAboveThresholds(fscale)
        title('Channel Utilization for ' + A.meas_name)
        intfmeas.addWifiChannelToPlot(xlim*1e6, fscale, 'white', 0.1, 'k', '--');
        [~, pngPathFull] = intfmeas.savePlotTo(gcf, path_to_plots, A.meas_name, 'chanutil');
        R.addSubSubSection('Channel Utilization');
        R.addPngFigure(latexreport.FIG_FLOAT, pngPathFull, ...
            'Channel utilization as probablity of channel activity.');
    end

    % Using IMAGE Processing Clustering
    % determine bandwidths and durations above thresholds
    % Typical CCA Threshold Values: For many Wi-Fi devices, the CCA
    % threshold is set around -82 dBm to -65 dBm.  We use the average here.
    %  The P3388 should be set for the technology at hand.
    if PREGIONS_ON
        figure()
        A.computeBandwidthDurationsAboveThresholds(mean(intfmeas.UtilizationThresholds), 1, 1, tscale, fscale);
        title('All Interference Regions for ' + A.meas_name + ' above thresh')
        [~, pngPathFull] = intfmeas.savePlotTo(gcf, path_to_plots, A.meas_name, 'allregions');
        R.addSubSubSection('Clustering by Interference Regions');
        R.addPngFigure(latexreport.FIG_FLOAT, pngPathFull, ...
            'All interference regions found without deselection applied.');
    end

    % Filtered for large regions only
    if PUTIL_ON
        figure()
        A.computeBandwidthDurationsAboveThresholds(mean(intfmeas.UtilizationThresholds), 25, 0.999, tscale, fscale);
        title('Large Interference Regions for ' + A.meas_name + ' above thresh')
        intfmeas.addWifiChannelToPlot(xlim*1e6, fscale, 'yellow', 0.1, 'y', '--');
        [~, pngPathFull] = intfmeas.savePlotTo(gcf, path_to_plots, A.meas_name, 'filteredregions');
        R.addPngFigure(latexreport.FIG_FLOAT, pngPathFull, 'Large interference regions only.');
    end

    % Using DBSCAN Clustering
    % In Wi-Fi networks, backoff typically begins when the energy
    % detect (ED) threshold of about -71 dBm is exceeded. For 802.11
    % preamble detection, the signal detect (SD) threshold is generally
    % lower, around -91 dBm.   What we care about is interference that
    % can cause degradation of performance for, e.g., a Wi-Fi network.
    % For this reason, we will select levels above the minimum level
    % unreliable level of -90 dBm which is considered a very weak
    % signal level (RSSI).
    if DBSCAN_ON
        figure()
        clusterThreshold = mean(intfmeas.UtilizationThresholds);
        A.computeClustersDBScan(clusterThreshold, 2, 4, fscale);
        title('DBSCAN Clusters for ' + A.meas_name);    
        [~, pngPathFull] = intfmeas.savePlotTo(gcf, path_to_plots, A.meas_name, 'dbscan');
        R.addSubSubSection('DBSCAN Clustering');
        R.addPngFigure(latexreport.FIG_FLOAT, pngPathFull, ...
            'All interference regions found without deselection applied.');    
    end

    % Save workspace file to data directory
    if SAVEWS_ON
        sPathToWs = './mat/' + A.meas_filename + '.mat';
        save(sPathToWs);
    end

    % close all plots
    close all

end

R.close();







