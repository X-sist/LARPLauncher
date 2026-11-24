function goalDetected = detectGoal(cameraInput, time)
% DETECTGOAL Waits `time` seconds, then checks whether a 3rd fiducial has
% appeared on the target board using majority-vote consensus and cluster gating.

    if nargin < 2 || isempty(time)
        time = 5; % Default wait time in seconds
    end

    % Physical board constants (must match detectDistanceAngle.m)
    Real_Spacing_Inches = 7.75;
    W_real_inches = 1;

    % Consensus parameters: 3 out of 5 frames (tolerates brief flicker, blocks 1-frame glare)
    numFrames = 5;
    requiredConfirmations = 3;
    frameInterval = 0.25;

    cam = cameraInput;
    fprintf('Waiting %.1f seconds for 3rd fiducial...\n', time);
    pause(time);

    confirmations = 0;

    for f = 1:numFrames
        Im = snapshot(cam);
        SortedTargets = detectFiducials(Im);
        rawCount = length(SortedTargets);
        bestCluster = 0;

        if rawCount >= 3
            % Test each detected dot as a potential board anchor so a single
            % bright background reflection cannot invalidate the real board
            for anchor = 1:rawCount
                AnchorDot = SortedTargets(anchor);
                est_dot_diam_px = 2 * sqrt(AnchorDot.Area / pi);

                % Slightly wider 3.0x margin to absorb threshold erosion on smaller dots
                max_allowed_px_spacing = (Real_Spacing_Inches / W_real_inches) * est_dot_diam_px * 3.0;

                clusterCount = 0;
                for k = 1:rawCount
                    if norm(SortedTargets(k).Centroid - AnchorDot.Centroid) <= max_allowed_px_spacing
                        clusterCount = clusterCount + 1;
                    end
                end

                if clusterCount > bestCluster
                    bestCluster = clusterCount;
                end
            end

            if bestCluster >= 3
                confirmations = confirmations + 1;
            end
        end

        fprintf('  Frame %d/%d -> Raw dots: %d | Max board cluster: %d\n', ...
            f, numFrames, rawCount, bestCluster);

        % Early exit once consensus is reached
        if confirmations >= requiredConfirmations
            break;
        end

        if f < numFrames
            pause(frameInterval);
        end
    end

    goalDetected = (confirmations >= requiredConfirmations);

    if goalDetected
        fprintf('Verification PASSED: 3rd fiducial confirmed (%d/%d required).\n', ...
            confirmations, requiredConfirmations);
    else
        fprintf('Verification FAILED: 3rd fiducial not confirmed (%d/%d required).\n', ...
            confirmations, requiredConfirmations);
    end
end