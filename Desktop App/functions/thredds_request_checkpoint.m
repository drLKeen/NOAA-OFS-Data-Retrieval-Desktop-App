function thredds_request_checkpoint(callback,phase)
%thredds_request_checkpoint Invoke an optional request progress callback.
%   thredds_request_checkpoint(CALLBACK,PHASE) calls CALLBACK(PHASE).
%   An empty callback does nothing. Cancellation exceptions propagate.
%
%   See also drawnow

if ~isempty(callback)
    callback(string(phase));
end
end
