classdef resolveThreddsDatasetTest < matlab.unittest.TestCase
    % Live integration checks; NOAA catalog and OPeNDAP access are required.
    methods (TestClassSetup)
        function addFunctionsFolder(testCase)
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(fileparts(fileparts(mfilename('fullpath'))),'functions')));
        end
    end
    methods (Test)
        function rejectMissingTemperature(testCase)
            testCase.verifyError(@() resolve_thredds_dataset('NYOFS','Forecast', ...
                datetime('now',TimeZone='UTC')),'THREDDS:TemperatureUnavailable');
        end
        function rejectUnzonedTime(testCase)
            testCase.verifyError(@() resolve_thredds_dataset('CBOFS','Nowcast', ...
                datetime('now')),'THREDDS:InvalidTime');
        end
    end
    methods (Test, TestTags={'Integration'})
        function forecastUsesPublishedCatalog(testCase)
            source = resolve_thredds_dataset('DBOFS','Forecast',datetime('now',TimeZone='UTC'));
            testCase.verifyTrue(endsWith(source.DatasetURL, ...
                '/DBOFS/fmrc/Aggregated_7_day_DBOFS_Fields_Forecast_best.ncd'));
            info = ncinfo(source.DatasetURL,'temp');
            testCase.verifyTrue(ismember("s_rho",string({info.Dimensions.Name})));
        end
        function nowcastCrossesMidnight(testCase)
            requested = dateshift(datetime('now',TimeZone='UTC'),'start','day')-hours(1);
            source = resolve_thredds_dataset('CBOFS','Nowcast',requested);
            testCase.verifyEqual(source.SelectedTime,requested);
            testCase.verifyTrue(contains(source.DatasetURL,'.t00z.'));
            testCase.verifyTrue(endsWith(source.DatasetURL,'.fields.n005.nc'));
        end
        function nowcastKeepsRequestedTime(testCase)
            requested = dateshift(datetime('now',TimeZone='UTC'),'start','day')-minutes(30);
            source = resolve_thredds_dataset('CBOFS','Nowcast',requested);
            testCase.verifyEqual(source.RequestedTime,requested);
            testCase.verifyLessThanOrEqual(abs(source.SelectedTime-requested),hours(1));
            testCase.verifyFalse(contains(source.DatasetURL,'Forecast'));
        end
        function sparseNowcastRejectsMissingHour(testCase)
            requested = dateshift(datetime('now',TimeZone='UTC'),'start','day')-days(1)+hours(10.5);
            testCase.verifyError(@() resolve_thredds_dataset('GOMOFS','Nowcast',requested), ...
                'THREDDS:NowcastTimeUnavailable');
        end
    end
end
