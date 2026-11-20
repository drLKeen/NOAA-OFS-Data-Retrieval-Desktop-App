classdef threddsExportTest < matlab.unittest.TestCase
    properties
        Folder
        Axes
        Result
    end
    methods (TestMethodSetup)
        function setupMap(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            testCase.Folder=fixture.Folder;
            fig=uifigure('Visible','off');
            testCase.addTeardown(@()delete(fig));
            ax=uiaxes(fig); testCase.Axes=ax;
            context=thredds_axesm_context(ax); %#ok<NASGU>
            axesm('mercator','MapLatLimit',[37 39],'MapLonLimit',[-77 -75]);
            [lon,lat]=meshgrid(-77:-75,37:39);
            temperature=single(reshape(1:9,3,3)); temperature(1)=NaN;
            surface=pcolorm(lat,lon,temperature,'EdgeColor','none');
            axis(ax,'off'); tightmap;
            title(ax,'Export verification'); colorbar(ax);
            t=datetime(2026,10,19,12,0,0,'TimeZone','UTC');
            testCase.Result=struct('TemperatureC',temperature,'Latitude',lat, ...
                'Longitude',lon,'WetMask',isfinite(temperature),'Surface',surface, ...
                'System',"CBOFS",'Product',"Forecast",'DatasetURL',"https://example.invalid/test", ...
                'RequestedTime',t,'SelectedTime',t,'SurfaceIndex',20,'SurfaceSigma',-0.025, ...
                'TimeIndex',1,'ReadStart',[1 1 20 1],'ReadCount',[3 3 1 1], ...
                'LatitudeLimits',[37 39],'LongitudeLimits',[-77 -75]);
        end
    end
    methods (Test)
        function vectorRoundtripPreservesNativeComponents(testCase)
            result=testCase.vectorResult();
            folder=export_thredds_result(result,testCase.Axes, ...
                testCase.Folder,'wind_export','Data only',150);
            saved=load(fullfile(folder,'wind_export.mat'));
            testCase.verifyEqual(saved.data.Native.Uwind,result.Native.Uwind,'AbsTol',single(0));
            testCase.verifyEqual(saved.data.Eastward,result.Eastward,'AbsTol',single(0));
            testCase.verifyEqual(saved.data.Northward,result.Northward,'AbsTol',single(0));
            testCase.verifyEqual(saved.data.DataType,"Wind");
            testCase.verifyFalse(isfield(saved.data,'TemperatureC'));
            testCase.verifyFalse(isfield(saved.data,'Arrows'));
        end
        function modifiedVectorIsRejected(testCase)
            result=testCase.vectorResult();
            result.Arrows(1).XData=result.Arrows(1).XData+1;
            testCase.verifyError(@()export_thredds_result(result,testCase.Axes, ...
                testCase.Folder,'modified_wind','Data only',150),'THREDDS:ExportMismatch');
        end
        function dataOnlyPreservesNativeArrays(testCase)
            folder=export_thredds_result(testCase.Result,testCase.Axes, ...
                testCase.Folder,'data_export','Data only',300);
            saved=load(fullfile(folder,'data_export.mat'));
            testCase.verifyEqual(saved.data.TemperatureC,testCase.Result.TemperatureC,'AbsTol',single(0));
            testCase.verifyClass(saved.data.TemperatureC,'single');
            testCase.verifyEqual(saved.data.WetMask,testCase.Result.WetMask);
            testCase.verifyEqual(saved.data.Latitude,testCase.Result.Latitude,'AbsTol',0);
            testCase.verifyEqual(saved.data.Longitude,testCase.Result.Longitude,'AbsTol',0);
            testCase.verifyEqual(saved.data.SelectedTime,testCase.Result.SelectedTime);
            testCase.verifyFalse(isfield(saved.data,'Surface'));
            testCase.verifyFalse(isfield(saved.data,'Axes'));
            testCase.verifyFalse(isfile(fullfile(folder,'data_export.png')));
            testCase.verifyTrue(isfile(fullfile(folder,'metadata.json')));
        end
        function mapOnlyPreservesView(testCase)
            testCase.Axes.XLim=testCase.Axes.XLim+[0.002 -0.002];
            before=testCase.Axes.XLim;
            folder=export_thredds_result(testCase.Result,testCase.Axes, ...
                testCase.Folder,'map_export','Map only',150);
            metadata=readstruct(fullfile(folder,'metadata.json'));
            testCase.verifyTrue(isfile(fullfile(folder,'map_export.png')));
            testCase.verifyFalse(isfile(fullfile(folder,'map_export.mat')));
            testCase.verifyEqual(testCase.Axes.XLim,before,'AbsTol',0);
            testCase.verifyEqual(metadata.Map.XLim(:),before(:),'AbsTol',1e-14);
        end
        function combinedExportAndCollision(testCase)
            first=export_thredds_result(testCase.Result,testCase.Axes, ...
                testCase.Folder,'combined','Map + data',150);
            second=export_thredds_result(testCase.Result,testCase.Axes, ...
                testCase.Folder,'combined','Data only',150);
            testCase.verifyNotEqual(first,second);
            testCase.verifyTrue(endsWith(second,'combined_002'));
            testCase.verifyTrue(isfile(fullfile(first,'combined.png')));
            testCase.verifyTrue(isfile(fullfile(first,'combined.mat')));
            testCase.verifyTrue(isfile(fullfile(second,'combined.mat')));
        end
        function invalidNameWritesNothing(testCase)
            testCase.verifyError(@()export_thredds_result(testCase.Result, ...
                testCase.Axes,testCase.Folder,'../outside','Data only',300), ...
                'THREDDS:ExportName');
            testCase.verifyNumElements(dir(testCase.Folder),2);
        end
        function modifiedSurfaceIsRejected(testCase)
            testCase.Result.Surface.CData=zeros(3,3,'single');
            testCase.verifyError(@()export_thredds_result(testCase.Result, ...
                testCase.Axes,testCase.Folder,'changed','Map + data',300), ...
                'THREDDS:ExportMismatch');
        end
    end
    methods (Access=private)
        function result=vectorResult(testCase)
            result=testCase.Result;
            delete(result.Surface); result.Surface=gobjects(0);
            result=rmfield(result,'TemperatureC');
            result.DataType="Wind"; result.Spec=thredds_field_spec('Wind');
            result.Eastward=single(ones(3)); result.Northward=single(zeros(3));
            result.Values=hypot(result.Eastward,result.Northward);
            result.Native=struct('Uwind',result.Eastward,'Vwind',result.Northward);
            result.GridAngle=zeros(3); result.VariableAttributes=struct;
            [result.Arrows,result.VectorDisplay]=thredds_draw_vectors(testCase.Axes,result,1);
        end
    end
end
