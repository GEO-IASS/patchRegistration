function displ2niftis(varargin)
% meant as a post-displacement processing script
%
% TODO: should separate warping displacement. only do seg if they are in the paths file.
% TODO: instead of inverting the warp and applying the inverse warp, just apply the warp backwards.

    %% preamble
    if iscell(varargin{1})
        [displ, source, target, paths, params, opts] = varargin{:};
        
    else % assuming same inputs as above
        [source, target, paths, params, opts] = parseInputs(varargin{:});
        displName = sprintf('%s-2-%s-warp', paths.sourceName, paths.targetName);
        displFile = sprintf('%s.nii.gz', displName);
        displNii = loadNii([paths.savepathfinal, displFile]);
        displ = dimsplit(5, displNii.img);
    end

    % prepare "original" volumes to warp 
    if strcmp(opts.scaleMethod, 'load')
        source = source{end};
        target = target{end};
    end

    
    
    %% prepare necessary volumes and warps
    % get inverse displacement
    displInv = invertwarp(displ, @volwarpForwardApprox);    
    
    % crop volumes
    cfn = @(v) cropVolume(v, params.volPad + 1, size(v) - params.volPad);
    source = cfn(source);
    target = cfn(target);
    displ = cellfunc(@(w) cfn(w), displ);
    displInv = cellfunc(@(w) cfn(w), displInv);
    
    % prepare segmentations, non-padded
    % TODO: make sure we're looking at the right files in load and non-load options
    sourceSeg = nii2vol(paths.sourceSegFile);
    targetSeg = nii2vol(paths.targetSegFile);
    
    % compose the final images using the resulting displacements
    sourceWarped = volwarp(source, displ, opts.warpDir);
    targetWarped = volwarp(target, displInv, opts.warpDir);

    % warp segmentations
    sourceWarpedSeg = volwarp(sourceSeg, displ, opts.warpDir, 'interpMethod', 'nearest');
    targetWarpedSeg = volwarp(targetSeg, displInv, opts.warpDir, 'interpMethod', 'nearest');


    
    %% save niftis
        
    % prepare nifti file names
    srcName = paths.sourceName;
    tgtName = paths.targetName;
    displName = sprintf('%s-2-%s-warp', srcName, tgtName);
    displInvName = sprintf('%s-2-%s-invWarp', srcName, tgtName);
    displFile = sprintf('%s.nii.gz', displName);
    displInvFile = sprintf('%s.nii.gz', displInvName);
    sourceWarpedFile = sprintf('%s-in-%s_via_%s.nii.gz', srcName, tgtName, displName);
    targetWarpedFile = sprintf('%s-in-%s_via_%s.nii.gz', tgtName, srcName, displInvName);
    sourceWarpedSegFile = sprintf('%s-seg-in-%s_via_%s.nii.gz', srcName, tgtName, displName);
    targetWarpedSegFile = sprintf('%s-seg-in-%s_via_%s.nii.gz', tgtName, srcName, displInvName);
    
    % make niftis 
    warning('displ2niftis: Making niftis while ignoring original meta-data. Uhoh, fixme!')
    displNii = make_nii(cat(5, displ{:}));
    displInvNii = make_nii(cat(5, displInv{:}));
    sourceWarpedNii = make_nii(sourceWarped);
    targetWarpedNii = make_nii(targetWarped);
    sourceWarpedSegNii = make_nii(sourceWarpedSeg);
    targetWarpedSegNii = make_nii(targetWarpedSeg);
    
    % save niftis
    saveNii(displNii, [paths.savepathfinal displFile]);
    saveNii(displInvNii, [paths.savepathfinal displInvFile]);
    saveNii(sourceWarpedNii, [paths.savepathfinal sourceWarpedFile]);
    saveNii(targetWarpedNii, [paths.savepathfinal targetWarpedFile]);
    saveNii(sourceWarpedSegNii, [paths.savepathfinal sourceWarpedSegFile]);
    saveNii(targetWarpedSegNii, [paths.savepathfinal targetWarpedSegFile]);

end