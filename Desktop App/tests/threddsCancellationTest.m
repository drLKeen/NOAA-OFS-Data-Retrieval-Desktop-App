classdef threddsCancellationTest < matlab.unittest.TestCase
    methods (Test)
        function multifieldCancelsBeforeClearingMap(testCase)
            fig=uifigure('Visible','off');
            testCase.addTeardown(@()delete(fig));
            ax=uiaxes(fig); existing=plot(ax,[0 1],[2 3]);
            callback=@(~)error('THREDDS:Cancelled','Request cancelled.');
            t=datetime(2026,10,20,'TimeZone','UTC');
            testCase.verifyError(@()plot_thredds_field_axesm( ...
                'https://example.invalid/thredds/dodsC/test',t,ax,callback,'Wind'), ...
                'THREDDS:Cancelled');
            testCase.verifyTrue(isgraphics(existing));
        end
        function forecastCancelsBeforeNetwork(testCase)
            t=datetime(2026,10,19,'TimeZone','UTC');
            callback=@(~)error('THREDDS:Cancelled','Request cancelled.');
            testCase.verifyError(@()resolve_thredds_dataset('CBOFS','Forecast',t,callback), ...
                'THREDDS:Cancelled');
        end
        function nowcastCancelsBeforeNetwork(testCase)
            t=datetime(2026,10,19,'TimeZone','UTC');
            callback=@(~)error('THREDDS:Cancelled','Request cancelled.');
            testCase.verifyError(@()resolve_thredds_dataset('CBOFS','Nowcast',t,callback), ...
                'THREDDS:Cancelled');
        end
        function readerCancelsBeforeClearingMap(testCase)
            fig=uifigure('Visible','off');
            testCase.addTeardown(@()delete(fig));
            ax=uiaxes(fig); existing=plot(ax,[0 1],[2 3]);
            callback=@(~)error('THREDDS:Cancelled','Request cancelled.');
            t=datetime(2026,10,19,'TimeZone','UTC');
            testCase.verifyError(@()plot_thredds_sst_axesm( ...
                'https://example.invalid/thredds/dodsC/test',t,ax,callback), ...
                'THREDDS:Cancelled');
            testCase.verifyTrue(isgraphics(existing));
            testCase.verifyEqual(existing.YData,[2 3],'AbsTol',0);
        end
    end
end
