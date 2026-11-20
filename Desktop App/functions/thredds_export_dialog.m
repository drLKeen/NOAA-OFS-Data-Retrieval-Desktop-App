function dialog = thredds_export_dialog(parent,result,ax,lastFolder,onExported)
%thredds_export_dialog Choose export options for a loaded THREDDS field.
%   D = thredds_export_dialog(PARENT,R,AX,FOLDER,CALLBACK) opens a modal
%   export dialog. CALLBACK receives the destination and new package folder
%   after success. Closing or cancelling the dialog writes nothing.
%
%   See also export_thredds_result, uigridlayout, uigetdir

if isempty(lastFolder) || ~isfolder(lastFolder), lastFolder=pwd; end
t=result.SelectedTime; t.TimeZone='UTC';
dataType="Temperature";
if isfield(result,'DataType'), dataType=result.DataType; end
defaultName=string(result.System)+"_"+lower(string(result.Product))+ ...
    "_"+replace(lower(dataType)," ","_")+"_"+string(t,'yyyyMMdd''T''HHmmss''Z''');
dialog=uifigure('Name','Export THREDDS result','WindowStyle','modal', ...
    'Position',[parent.Position(1)+80 parent.Position(2)+80 570 430], ...
    'Tag','THREDDSExportDialog','Resize','off');
grid=uigridlayout(dialog,[9 3],'ColumnWidth',{100,'1x',88}, ...
    'RowHeight',{44,30,30,30,30,54,'1x',40,32},'Padding',[16 16 16 16]);
summary=uilabel(grid,'Text',sprintf('%s %s | %s UTC',result.System, ...
    lower(string(result.Product)),string(t,'yyyy-MM-dd HH:mm')),'WordWrap','on');
summary.Layout.Row=1; summary.Layout.Column=[1 3];
label=uilabel(grid,'Text','Export'); label.Layout.Row=2; label.Layout.Column=1;
mode=uidropdown(grid,'Items',{'Map + data','Map only','Data only'}, ...
    'Value','Map + data','Tag','ExportMode');
mode.Layout.Row=2; mode.Layout.Column=[2 3];
label=uilabel(grid,'Text','Destination'); label.Layout.Row=3; label.Layout.Column=1;
destination=uieditfield(grid,'Value',char(lastFolder),'Tag','ExportDestination');
destination.Layout.Row=3; destination.Layout.Column=2;
browse=uibutton(grid,'Text','Browse…','ButtonPushedFcn',@browseFolder);
browse.Layout.Row=3; browse.Layout.Column=3;
label=uilabel(grid,'Text','Folder name'); label.Layout.Row=4; label.Layout.Column=1;
name=uieditfield(grid,'Value',char(defaultName),'Tag','ExportName');
name.Layout.Row=4; name.Layout.Column=[2 3];
label=uilabel(grid,'Text','PNG dpi'); label.Layout.Row=5; label.Layout.Column=1;
dpi=uispinner(grid,'Value',300,'Limits',[72 1200],'Step',50,'Tag','ExportDPI');
dpi.Layout.Row=5; dpi.Layout.Column=2;
scope=uilabel(grid,'Text', ...
    'Map: current view as PNG, including title and colorbar. Data: entire loaded native grid as a MAT-file. Source and settings included as JSON.', ...
    'WordWrap','on');
scope.Layout.Row=6; scope.Layout.Column=[1 3];
status=uilabel(grid,'Text','Existing exports are preserved with a numbered folder name.', ...
    'WordWrap','on','Tag','ExportStatus');
status.Layout.Row=8; status.Layout.Column=[1 3];
cancel=uibutton(grid,'Text','Cancel','ButtonPushedFcn',@(~,~)delete(dialog),'Tag','ExportCancel');
cancel.Layout.Row=9; cancel.Layout.Column=2;
saveButton=uibutton(grid,'Text','Export','ButtonPushedFcn',@exportFiles, ...
    'Tag','ExportSave','Interruptible','off','BusyAction','cancel');
saveButton.Layout.Row=9; saveButton.Layout.Column=3;
mode.ValueChangedFcn=@changeMode;

    function browseFolder(~,~)
        startFolder=destination.Value;
        if ~isfolder(startFolder), startFolder=pwd; end
        selected=uigetdir(startFolder,'Choose export destination');
        if ~isequal(selected,0), destination.Value=selected; end
    end

    function changeMode(~,~)
        dpi.Enable=matlab.lang.OnOffSwitchState(~strcmp(mode.Value,'Data only'));
    end

    function exportFiles(~,~)
        saveButton.Enable='off'; cancel.Enable='off';
        dialog.CloseRequestFcn=@(~,~)[];
        status.Text='Exporting the loaded result…'; drawnow;
        try
            folder=export_thredds_result(result,ax,destination.Value, ...
                name.Value,mode.Value,dpi.Value);
        catch exception
            status.Text=exception.message;
            saveButton.Enable='on'; cancel.Enable='on';
            dialog.CloseRequestFcn=@(~,~)delete(dialog);
            return
        end
        onExported(fileparts(folder),folder);
        delete(dialog);
    end
end
