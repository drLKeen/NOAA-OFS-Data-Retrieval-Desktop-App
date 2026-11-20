classdef threddsVectorTest < matlab.unittest.TestCase
    methods (Test)
        function rotatedGrid(testCase)
            [east,north]=thredds_rotate_vectors(ones(3),zeros(3), ...
                repmat(pi/2,3),true(3));
            testCase.verifyEqual(east,zeros(3),'AbsTol',1e-14);
            testCase.verifyEqual(north,ones(3),'AbsTol',1e-14);
        end
        function staggeredLinearFlow(testCase)
            [east,north]=thredds_rotate_vectors(repmat([1;3;5],1,3), ...
                repmat([2 6],4,1),zeros(4,3),true(4,3));
            testCase.verifyEqual(east,repmat([1;2;4;5],1,3),'AbsTol',1e-14);
            testCase.verifyEqual(north,repmat([2 4 6],4,1),'AbsTol',1e-14);
        end
        function missingFacesAreNotBridged(testCase)
            u=ones(3,3); u(2,2)=NaN;
            [east,north]=thredds_rotate_vectors(u,ones(4,2),zeros(4,3),true(4,3));
            testCase.verifyTrue(all(isnan(east(2:3,2))));
            testCase.verifyTrue(all(isnan(north(2:3,2))));
        end
        function dryCellsMasked(testCase)
            wet=true(3); wet(2,2)=false;
            [east,north]=thredds_rotate_vectors(ones(3),ones(3),zeros(3),wet);
            testCase.verifyTrue(isnan(east(2,2)));
            testCase.verifyTrue(isnan(north(2,2)));
        end
        function gridMismatchRejected(testCase)
            testCase.verifyError(@()thredds_rotate_vectors(ones(2),ones(4), ...
                zeros(3),true(3)),'THREDDS:VectorGrid');
        end
    end
end
