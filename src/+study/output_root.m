function root = output_root(s)
%OUTPUT_ROOT The folder a call writes its results into.
%   ROOT = study.output_root(S) is the run folder S.paths.run, or, for a
%   maintainers' render of the shipped results in place (S.run.inPlace,
%   reproduce mode), thesis_results/ (S.paths.results). The run folder keeps
%   the run record and the renderers' bookkeeping in both cases, so nothing
%   but results is written into thesis_results/.
%   Side effects: none.
    root = s.paths.run;
    if isfield(s.run, 'inPlace') && s.run.inPlace
        root = s.paths.results;
    end
end
