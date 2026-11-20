function choice = thredds_availability_selection(listing,date,preferredHour)
%thredds_availability_selection Select a published time for date controls.
%   C = thredds_availability_selection(S,DATE,HOUR) filters S.Times by
%   date. Forecast dates outside the available days move to the nearest
%   available day. Nowcast dates remain unchanged. C.Time is the exact
%   selected UTC timestamp, or empty when there are no times for the day.
%
%   See also thredds_data_availability

date=datetime(year(date),month(date),day(date),'TimeZone','UTC');
times=listing.Times(:);
days=unique(dateshift(times,'start','day'));
choice=struct('Date',datetime(year(date),month(date),day(date)), ...
    'Limits',[datetime(1,1,1),datetime(9999,12,31)], ...
    'DisabledDates',datetime.empty(0,1),'Times',times([]), ...
    'Labels',strings(0,1),'Hours',zeros(0,1),'Hour',-1,'Time',[], ...
    'DateAdjusted',false);
if listing.Product=="Forecast" && ~isempty(days)
    if ~ismember(date,days)
        [~,nearest]=min(abs(days-date)); date=days(nearest);
        choice.DateAdjusted=true;
    end
    choice.Date=datetime(year(date),month(date),day(date));
    choice.Limits=datetime(year(days([1 end])),month(days([1 end])),day(days([1 end])))';
    missing=setdiff((days(1):caldays(1):days(end))',days);
    choice.DisabledDates=datetime(year(missing),month(missing),day(missing));
end
choice.Times=times(times>=date & times<date+caldays(1));
if isempty(choice.Times), return, end
choice.Hours=hours(choice.Times-date);
choice.Labels=string(choice.Times,'HH:mm');
if any(second(choice.Times)~=0), choice.Labels=string(choice.Times,'HH:mm:ss'); end
[~,index]=min(abs(choice.Hours-preferredHour));
choice.Hour=choice.Hours(index);
choice.Time=choice.Times(index);
end
