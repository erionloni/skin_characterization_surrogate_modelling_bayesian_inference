function cleanup = checkpoint_lock(pathValue)
%CHECKPOINT_LOCK Hold an exclusive lock on a model checkpoint while it is being fitted.
%   CLEANUP = surrogates.checkpoint_lock(PATH) creates PATH.lock exclusively,
%   so that two processes fitting the same output (for example parallel
%   cluster jobs of the generalized refit) do not write the same checkpoint;
%   the second one stops with 'surrogates:checkpoint_lock:Busy'. The lock is
%   released when CLEANUP is cleared. A lock older than 24 hours is taken to
%   be left over from a stopped process: it is renamed (kept) and a new lock
%   is created. Side effects: writes and deletes PATH.lock.

    lockPath = [pathValue '.lock'];
    folder = fileparts(lockPath);
    if ~isfolder(folder), mkdir(folder); end
    if isfile(lockPath)
        info=dir(lockPath);
        modified=datetime(info.datenum,'ConvertFrom','datenum');
        ageSeconds=seconds(datetime('now')-modified);
        if ageSeconds>24*3600
            preserved=[lockPath '.stale.' ...
                char(datetime('now','Format','yyyyMMdd''T''HHmmss')) '.' ...
                char(javaMethod('randomUUID','java.util.UUID'))];
            [ok,message]=movefile(lockPath,preserved);
            assert(ok,'surrogates:checkpoint_lock:StalePreserveFailed', ...
                'Could not preserve stale lock: %s',message);
        end
    end
    token = char(javaMethod('randomUUID','java.util.UUID'));
    file = javaObject('java.io.File',lockPath);
    assert(file.createNewFile(), ...
        'surrogates:checkpoint_lock:Busy', ...
        ['Another process is fitting this model checkpoint (lock %s); wait for ' ...
         'it, or delete the lock if no process is running.'],lockPath);

    % Guard every operation after exclusive creation, so that a failure
    % here cannot leave the lock behind.
    try
        owner=struct('token',token, ...
            'pid',feature('getpid'),'createdUTC',char(datetime('now', ...
            'TimeZone','UTC')));
        fid = fopen(lockPath,'w');
        assert(fid >= 0,'surrogates:checkpoint_lock:OpenFailed', ...
            'Cannot write lock: %s',lockPath);
        fileCleanup=onCleanup(@()fclose(fid));
        count=fprintf(fid,'%s\n',jsonencode(owner));
        assert(count>0,'surrogates:checkpoint_lock:WriteFailed', ...
            'Cannot write lock owner metadata: %s',lockPath);
        clear fileCleanup
    catch ME
        cleanup_created_claim(lockPath,ME);
        rethrow(ME);
    end
    cleanup = onCleanup(@() release(lockPath,token));
end

function cleanup_created_claim(pathValue,originalError)
    if ~isfile(pathValue), return; end
    try
        delete(pathValue);
    catch cleanupError
        combined=MException( ...
            'surrogates:checkpoint_lock:ClaimCleanupFailed', ...
            ['Model-checkpoint lock setup failed and the newly created ' ...
             'claim could not be removed: %s'],pathValue);
        combined=addCause(combined,originalError);
        combined=addCause(combined,cleanupError);
        throwAsCaller(combined);
    end
end

function release(pathValue, token)
    if ~isfile(pathValue), return; end
    try
        owner=jsondecode(fileread(pathValue));
        if isfield(owner,'token') && strcmp(owner.token,token)
            delete(pathValue);
        end
    catch
        % Fail closed by preserving an unreadable lock.
    end
end
