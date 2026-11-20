function land = thredds_gshhs_bin_land(segments,levels,entry,exitSide,corners)
%thredds_gshhs_bin_land Assemble land in one normalized GSHHS bin.
%   LAND = thredds_gshhs_bin_land(SEGMENTS,LEVELS,ENTRY,EXIT,CORNERS)
%   returns a polyshape in [0,1] coordinates. SEGMENTS contains N-by-2
%   coordinate matrices; levels 1 through 4 alternate land and water.
%   Sides 0 through 3 run counterclockwise from south; side 4 is interior.
%   CORNERS gives southwest, southeast, northeast, northwest node levels.
%
%   See also polyshape, thredds_gshhs_land

land = polyshape;
for level = 1:4
    selected = find(levels==level);
    open = selected(entry(selected)<4);
    rings = cell(0,1);
    if isempty(open) && all(corners>=level)
        rings{end+1} = [0 0;1 0;1 1;0 1;0 0]; %#ok<AGROW>
    end
    paths = segments(open);
    inSide = entry(open);
    outSide = exitSide(open);
    % GSHHS has land on the left: reverse water boundaries for lake area.
    if mod(level,2)==0
        paths = cellfun(@flipud,paths,'UniformOutput',false);
        [inSide,outSide] = deal(outSide,inSide);
    end
    starts = zeros(numel(open),1);
    ends = starts;
    for k = 1:numel(open)
        starts(k) = perimeterPosition(paths{k}(1,:),inSide(k));
        ends(k) = perimeterPosition(paths{k}(end,:),outSide(k));
    end
    used = false(numel(open),1);
    for first = 1:numel(open)
        if used(first), continue, end
        pieces = cell(0,1);
        k = first;
        while ~used(k)
            used(k) = true;
            pieces{end+1} = paths{k}; %#ok<AGROW>
            % Quantized GSHHS endpoints can coincide on a bin edge.
            % Consume each entry once, retaining the first entry only
            % to close this ring. Independent nearest-entry lookups can
            % otherwise assign the same entry to multiple exits.
            candidates = find(~used | (1:numel(open))'==first);
            [distance,index] = min(mod(starts(candidates)-ends(k),4));
            next = candidates(index);
            stop = ends(k)+distance;
            turns = (floor(ends(k))+1):ceil(stop)-1;
            cornerXY = [0 0;1 0;1 1;0 1];
            pieces{end+1} = cornerXY(mod(turns,4)+1,:); %#ok<AGROW>
            k = next;
        end
        assert(k==first,'GSHHS boundary did not close.');
        ring = vertcat(pieces{:});
        rings{end+1} = [ring;ring(1,:)]; %#ok<AGROW>
    end
    for k = selected(entry(selected)==4)'
        rings{end+1} = segments{k}; %#ok<AGROW>
    end
    if isempty(rings), continue, end
    % Adjacent segments can share identical endpoints and bin corners.
    rings = cellfun(@(p)p([true;any(diff(p,1,1)~=0,2)],:), ...
        rings,'UniformOutput',false);
    x = cellfun(@(p)p(:,1),rings,'UniformOutput',false);
    y = cellfun(@(p)p(:,2),rings,'UniformOutput',false);
    region = polyshape(x,y,'KeepCollinearPoints',true);
    if mod(level,2)==1
        land = union(land,region,'KeepCollinearPoints',true);
    else
        land = subtract(land,region,'KeepCollinearPoints',true);
    end
end
end

function t = perimeterPosition(point,side)
switch side
    case 0, t = point(1);
    case 1, t = 1+point(2);
    case 2, t = 3-point(1);
    case 3, t = 4-point(2);
    otherwise, error('Invalid bin side.');
end
end
