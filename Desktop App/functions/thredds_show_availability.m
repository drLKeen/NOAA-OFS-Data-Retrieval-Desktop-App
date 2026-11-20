function selectedTime = thredds_show_availability(app,listing,preferredHour)
%thredds_show_availability Populate date/time controls from a listing.
%   T = thredds_show_availability(APP,S,HOUR) updates public controls and
%   returns the exact selected UTC timestamp, or empty for an empty day.
%
%   See also thredds_availability_selection

choice=thredds_availability_selection(listing,app.DatePicker.Value,preferredHour);
app.DatePicker.DisabledDates=datetime.empty(0,1);
app.DatePicker.Limits=[datetime(1,1,1),datetime(9999,12,31)];
app.DatePicker.Value=choice.Date;
app.DatePicker.Limits=choice.Limits;
app.DatePicker.DisabledDates=choice.DisabledDates;
app.TimeDropDown.ItemsData=[];
if isempty(choice.Times)
    app.TimeDropDown.Items={'No times'};
    app.TimeDropDown.ItemsData=-1;
    app.TimeDropDown.Value=-1;
    app.AvailabilityLabel.Text=sprintf('No published times on %s.\nChecked %s UTC — try Refresh or another date.', ...
        string(choice.Date,'yyyy-MM-dd'),string(listing.CheckedAt,'HH:mm:ss'));
    app.MapStatus.Text='No published times for the selected day. The displayed map is unchanged.';
else
    app.TimeDropDown.Items=cellstr(choice.Labels');
    app.TimeDropDown.ItemsData=choice.Hours';
    app.TimeDropDown.Value=choice.Hour;
    app.AvailabilityLabel.Text=sprintf('%d times | %s–%s UTC\nChecked %s UTC', ...
        numel(choice.Times),choice.Labels(1),choice.Labels(end), ...
        string(listing.CheckedAt,'HH:mm:ss'));
    if choice.DateAdjusted
        app.MapStatus.Text='Date adjusted to the published range. Click Load map to update the display.';
    else
        app.MapStatus.Text='Published times ready. Click Load map to update the display.';
    end
end
if listing.Product=="Forecast"
    app.URLEditField.Value=char(listing.DatasetURL);
    app.AvailabilityLabel.Tooltip=sprintf('Forecast time coordinate: %s to %s UTC. Refresh checks for newly published runs.', ...
        string(min(listing.Times),'yyyy-MM-dd HH:mm'),string(max(listing.Times),'yyyy-MM-dd HH:mm'));
else
    app.AvailabilityLabel.Tooltip='Times advertised in the daily catalogs. The selected file timestamp is verified on Load.';
end
selectedTime=choice.Time;
end
