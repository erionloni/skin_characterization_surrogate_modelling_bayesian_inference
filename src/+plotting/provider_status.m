function label = provider_status(status)
%PROVIDER_STATUS The status of a loaded posterior provider, for figure titles.
%   LABEL = plotting.provider_status(STATUS) is 'certified' when STATUS (as
%   recovery.load_posterior_provider returns it) says the provider is
%   certified, else 'healthy fallback' (a selected provider that is not
%   certified; a per-case figure states its cell's status in its title).
%   Side effects: none.
    if logical(status.certified)
        label = 'certified';
    else
        label = 'healthy fallback';
    end
end
