classdef threddsAvailabilityTest < matlab.unittest.TestCase
    methods (Test)
        function partialForecastDay(testCase)
            t=datetime(2026,10,19,'TimeZone','UTC');
            listing=struct('Product',"Forecast",'Times',t+hours((20:27)'));
            choice=thredds_availability_selection(listing,datetime(2026,10,20),14);
            testCase.verifyEqual(choice.Hours,(0:3)','AbsTol',0);
            testCase.verifyEqual(choice.Hour,3,'AbsTol',0);
            testCase.verifyEqual(choice.Time,t+hours(27));
        end
        function forecastDateAndGaps(testCase)
            t=datetime(2026,10,19,'TimeZone','UTC');
            listing=struct('Product',"Forecast",'Times',[t;t+days(2)]);
            choice=thredds_availability_selection(listing,datetime(2026,10,25),0);
            testCase.verifyEqual(choice.Date,datetime(2026,10,21));
            testCase.verifyEqual(choice.DisabledDates,datetime(2026,10,20));
            testCase.verifyTrue(choice.DateAdjusted);
        end
        function unavailableNowcastDoesNotChangeDate(testCase)
            t=datetime(2026,10,19,'TimeZone','UTC');
            listing=struct('Product',"Nowcast",'Times',t+hours((0:3:6)'));
            choice=thredds_availability_selection(listing,datetime(2026,10,20),0);
            testCase.verifyEmpty(choice.Time);
            testCase.verifyEmpty(choice.Hours);
            testCase.verifyEqual(choice.Date,datetime(2026,10,20));
        end
        function fractionalTimesStayExact(testCase)
            t=datetime(2026,10,19,'TimeZone','UTC')+minutes(30)+seconds(15);
            listing=struct('Product',"Forecast",'Times',t);
            choice=thredds_availability_selection(listing,datetime(2026,10,19),1);
            testCase.verifyEqual(choice.Time,t);
            testCase.verifyEqual(choice.Labels,"00:30:15");
        end
        function nowcastMidnightNaming(testCase)
            times=thredds_nowcast_times(["cbofs.t00z.20261019.fields.n005.nc"; ...
                "gomofs.t06z.20261019.fields.n003.nc";"unknown.nc"]);
            t=datetime(2026,10,19,'TimeZone','UTC');
            testCase.verifyEqual(times(1),t-hours(1));
            testCase.verifyEqual(times(2),t+hours(3));
            testCase.verifyTrue(isnat(times(3)));
        end
        function cancelledQueryDoesNotReadNetwork(testCase)
            callback=@(~)error('THREDDS:Cancelled','Request cancelled.');
            t=datetime(2026,10,19,'TimeZone','UTC');
            testCase.verifyError(@()thredds_data_availability('CBOFS','Forecast',t,callback), ...
                'THREDDS:Cancelled');
            testCase.verifyError(@()thredds_data_availability('CBOFS','Nowcast',t,callback), ...
                'THREDDS:Cancelled');
        end
    end
end
