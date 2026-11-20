function [east,north] = thredds_rotate_vectors(u,v,angle,wet)
% Align staggered ROMS vectors at rho points and rotate to east/north.
if isequal(size(u),size(angle)-[1 0]) && ...
        isequal(size(v),size(angle)-[0 1])
    % Interior rho points average their two adjacent faces. Domain edges
    % use the nearest face; missing face values propagate without bridging.
    u=[u(1,:);(u(1:end-1,:)+u(2:end,:))/2;u(end,:)];
    v=[v(:,1),(v(:,1:end-1)+v(:,2:end))/2,v(:,end)];
end
assert(isequal(size(u),size(v),size(angle),size(wet)), ...
    'THREDDS:VectorGrid','Unsupported vector grid dimensions.');
east=u.*cos(angle)-v.*sin(angle);
north=u.*sin(angle)+v.*cos(angle);
east(~wet)=NaN; north(~wet)=NaN;
end
