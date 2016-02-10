function displ = multiscale(source, target, params, opts, varargin)
% MULTISCALE run a full patch-based registration.
%
% displ = multiscale(source, target, params, opts)
%   params: struct with: patchSize, searchSize, gridSpacing, nScales, nInnerReps
%   opts: struct with: inferMethod, warpDir, warpReg, verbose, distMethod, <savefile>
%
% displ = multiscale(source, target, params, opts, varargin) see singlescale(...)
%
% inferMethod offers the possibility to choose inference methods: LoopyBP, MeanField, Fast PD
%
% TODO: better documentation :)

    mastertic = tic;

    % pre-compute the source and target sizes at each scale.
    % e.g. 2.^linspace(log2(32), log2(256), 4)
    minSize = 16; % usually good to use 16.
    minScale = min(minSize, min([size(source), size(target)])/2);
    if strcmp(opts.scaleMethod, 'load')
        srcSizes = cellfunc(@(x) size(x), source);
        trgSizes = cellfunc(@(x) size(x), target);
        firstSize = size(source{1, 1});
        sourceOrig = source{1, params.nScales};
        sourceMaskOrig = params.sourceMask{1, params.nScales};
    else
        srcSizes = arrayfunc(@(x) round(2 .^ linspace(log2(minScale), log2(x), params.nScales)), size(source));
        trgSizes = arrayfunc(@(x) round(2 .^ linspace(log2(minScale), log2(x), params.nScales)), size(target));
        firstSize = cellfun(@(x) round(x(1)), srcSizes);
        sourceOrig = source;
        sourceMaskOrig = params.sourceMask;
    end
    
    % initiate a zero displacement
    displ = repmat({zeros(firstSize)}, [1, ndims(sourceOrig)]); 
    
    % all sizes are allowed to be nScales sized.
    rfn = @(p) repmat(p, [params.nScales, 1]);
    if size(params.patchSize, 1) == 1, params.patchSize = rfn(params.patchSize); end
    if size(params.gridSpacing, 1) == 1, params.gridSpacing = rfn(params.gridSpacing); end
    if size(params.searchSize, 1) == 1, params.searchSize = rfn(params.searchSize); end
    
    % go through the multiple scales
    for s = 1:params.nScales        
        
        % resizing the original source and target images to s
        if iscell(source)
            scSrcSize = srcSizes{s};
            scTargetSize = trgSizes{s};
            scSource = source{1, s};
            scTarget = target{1, s};
        else
            scSrcSize = cellfun(@(x) x(s), srcSizes);
            scTargetSize = cellfun(@(x) x(s), trgSizes);
            scSource = volresize(source, scSrcSize);
            scTarget = volresize(target, scTargetSize);
        end
        
        % resize the original source mask and target mask images to s
        if strcmp(opts.distance, 'sparse')
            if iscell(source)
                scSourceMask = params.sourceMask{1, s};
                scTargetMask = params.targetMask{1, s};
            else
                scSourceMask = volresize(params.sourceMask, scSrcSize);
                scTargetMask = volresize(params.targetMask, scTargetSize);
            end
        end
        
        % resize the warp distances to the current scale size
        displ = resizeWarp(displ, scSrcSize);
        
        % warp several times
        for t = 1:params.nInnerReps 
            
            % if verbose, print a bit of information
            if opts.verbose
               fprintf('multiscale: running scale %d iteration %d with size %s\n', s, t, ...
                   sprintf('%d ', scSrcSize));
            end
            
            % warp the source to match the size of the current displacement
            if strcmp(opts.warpRes, 'atscale')
                scSourceWarped = volwarp(scSource, displ, opts.warpDir);
                if strcmp(opts.distance, 'sparse')
                    scSourceMaskWarped = volwarp(scSourceMask, displ, opts.warpDir);
                end
                
            else
                assert(strcmp(opts.warpRes, 'full'));
                sys.warnif(strcmp(opts.warpDir, 'forward'), ...
                    'Warning: forward full volwarp at each iteration is costly');
                
                wd = resizeWarp(displ, size(sourceOrig));
                sourceWarped = volwarp(sourceOrig, wd, opts.warpDir);
                scSourceWarped = volresize(sourceWarped, scSrcSize);
                if strcmp(opts.distance, 'sparse')
                    sourceMaskWarped = volwarp(sourceMaskOrig, wd, opts.warpDir);
                    scSourceMaskWarped = volresize(sourceMaskWarped, scSrcSize);, 'params', 'runTime'
                end
            end

            % prepare the parameters for this scale run.
            sstic = tic();
            locparams = params;
            locparams.patchSize = locparams.patchSize(s, :);
            locparams.gridSpacing = locparams.gridSpacing(s, :);
            locparams.searchSize = locparams.searchSize(s, :);
            if strcmp(opts.distance, 'sparse')
                locparams.sourceMask = scSourceMaskWarped;
                locparams.targetMask = scTargetMask;
            end
            
            % find the new warp (displacements)
            localDispl = patchreg.singlescale(scSourceWarped, scTarget, locparams, opts, ...
                'currentdispl', displ, varargin{:});
            sstime = toc(sstic);

            % compose previous warp with newfound warp
            cdispl = composeWarps(displ, localDispl, opts.warpDir, opts.warpDir);
            
            % if save mode is on, save relevant teration information
            if isfield(opts, 'savefile') && ~isempty(opts.savefile)
                state = struct('scale', s, 'iter', t, 'scSrcSize', scSrcSize, ...
                    'scTargetSize', scTargetSize, 'runTime', sstime); %#ok<NASGU>
                displVolumes = struct('prevdispl', {displ}, 'localDispl', {localDispl}, ...
                    'cdispl', {cdispl}); %#ok<NASGU>
                volumes = struct('scSource', scSource, 'scTarget', scTarget, ... 
                    'scSourceWarped', scSourceWarped, 'scSourceMaskWarped', scSourceMaskWarped); %#ok<NASGU>
                filename = sprintf(opts.savefile, s, t);
                save(filename, 'params', 'opts', 'state', 'displVolumes', 'volumes');
            end 
            
            % final warp for this iteration is the composed warp
            displ = cdispl;
        end
    end
    
    if isfield(opts, 'savefile') && ~isempty(opts.savefile)
        mastertoc = toc(mastertic);
        state = struct('runTime', mastertoc); %#ok<NASGU>
        volumes = struct('source', source, 'target', target); %#ok<NASGU>
        displVolumes = struct('displ', displ); %#ok<NASGU>
        filename = sprintf(opts.savefile, 0, 0);
        save(filename, 'params', 'opts', 'displVolumes', 'volumes', 'state');
    end    
end
