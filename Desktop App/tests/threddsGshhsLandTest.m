classdef threddsGshhsLandTest < matlab.unittest.TestCase
    methods (Test)
        function continentAndOcean(testCase)
            land = thredds_gshhs_bin_land({},[],[],[],[1 1 1 1]);
            ocean = thredds_gshhs_bin_land({},[],[],[],[0 0 0 0]);
            testCase.verifyEqual(area(land),1,'AbsTol',1e-12);
            testCase.verifyEqual(area(ocean),0,'AbsTol',1e-12);
        end
        function boundaryCrossing(testCase)
            land = thredds_gshhs_bin_land({[0.5 0;0.5 1]},1,0,2,[1 0 0 1]);
            testCase.verifyEqual(area(land),0.5,'AbsTol',1e-12);
            testCase.verifyTrue(isinterior(land,0.25,0.5));
            testCase.verifyFalse(isinterior(land,0.75,0.5));
        end
        function nestedLakeAndIsland(testCase)
            lake = [0.2 0.2;0.2 0.8;0.8 0.8;0.8 0.2;0.2 0.2];
            island = [0.4 0.4;0.6 0.4;0.6 0.6;0.4 0.6;0.4 0.4];
            land = thredds_gshhs_bin_land({lake;island},[2;3],[4;4],[4;4],[1 1 1 1]);
            testCase.verifyEqual(area(land),0.68,'AbsTol',1e-12);
            testCase.verifyFalse(isinterior(land,0.3,0.3));
            testCase.verifyTrue(isinterior(land,0.5,0.5));
        end
        function lakeCrossingBoundary(testCase)
            land = thredds_gshhs_bin_land({[0.5 1;0.5 0]},2,2,0,[2 1 1 2]);
            testCase.verifyEqual(area(land),0.5,'AbsTol',1e-12);
            testCase.verifyFalse(isinterior(land,0.25,0.5));
            testCase.verifyTrue(isinterior(land,0.75,0.5));
        end
        function twoDisjointCoasts(testCase)
            land = thredds_gshhs_bin_land({[0.25 0;0.25 1];[0.75 1;0.75 0]}, ...
                [1;1],[0;2],[2;0],[1 1 1 1]);
            testCase.verifyEqual(area(land),0.5,'AbsTol',1e-12);
            testCase.verifyEqual(land.NumRegions,2);
            testCase.verifyFalse(isinterior(land,0.5,0.5));
        end
        function chesapeakeLandAndWater(testCase)
            projectRoot = fileparts(fileparts(mfilename('fullpath')));
            filename = fullfile(projectRoot,'gshhg-gmt-2.3.7','binned_GSHHS_h.nc');
            land = thredds_gshhs_land(filename,[36.8 39.8],[-77.4 -75.5]);
            testCase.verifyTrue(isinterior(land,-77.0369,38.9072));
            testCase.verifyFalse(isinterior(land,-76.3,38.3));
        end
        function touchingBoundaryEntries(testCase)
            upper = [1 0.75;0.5 0.625;1 0.5];
            lower = [1 0.5;0.5 0.375;1 0.25];
            land = thredds_gshhs_bin_land({upper;lower}, ...
                [1;1],[1;1],[1;1],[0 0 0 0]);
            reversed = thredds_gshhs_bin_land({lower;upper}, ...
                [1;1],[1;1],[1;1],[0 0 0 0]);
            testCase.verifyEqual(area(land),0.125,'AbsTol',1e-12);
            testCase.verifyEqual(area(xor(land,reversed)),0,'AbsTol',1e-12);
            testCase.verifyTrue(all(isinterior(land,[0.9 0.9],[0.625 0.375])));
            testCase.verifyFalse(isinterior(land,0.75,0.5));
        end
        function gulfOfMaineLandAndWater(testCase)
            appRoot = fileparts(fileparts(mfilename('fullpath')));
            filename = fullfile(appRoot,'gshhg-gmt-2.3.7','binned_GSHHS_h.nc');
            land = thredds_gshhs_land(filename,[40 46],[-72 -64]);
            testCase.verifyTrue(isinterior(land,-69.4455,44.3106));
            testCase.verifyFalse(isinterior(land,-70.5,42.5));
            testCase.verifyFalse(isinterior(land,-66.1,43));
        end
    end
end
