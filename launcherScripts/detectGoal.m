function goalDetected = detectGoal(cameraInput, time)
    % TODO Watch cameraInput for up to time seconds and return the result.
   % validateattributes(time, {'numeric'}, {'scalar', 'integer', 'nonnegative', 'finite'});

   % fprintf('[Goal] Detection placeholder for %d seconds returns false.\n', time);

   % CHECKTHIRDFIDUCIAL Waits waitTime seconds, then verifies whether a 3rd
   % fiducial has appeared on the target board. Returns logical true/false.
   % Uses multi-frame unanimous consensus + spatial gating to prevent false positives.

   if nargin < 2 || isempty(time)
       time = 5; % Default wait time in seconds
   end

   % Physical board constants (must match acquireTarget.m)
   Real_Spacing_Inches = 7.75;
   W_real_inches = 1;

   % Consensus parameters
   numFrames = 3;         % Number of consecutive frames to verify
   frameInterval = 0.25;  % Seconds between verification frames

   % Initialize camera first so exposure stabilizes during the wait period
   cam = cameraInput;
   fprintf('Waiting %.1f seconds for 3rd fiducial...\n', time);
   pause(time);

   confirmations = 0;

   for f = 1:numFrames
       Im = snapshot(cam);
       SortedTargets = detectFiducials(Im);

       if length(SortedTargets) >= 3
           % Spatial check: count how many detections belong to the target board
           PrimaryDot = SortedTargets(1);
           est_dot_diam_px = 2 * sqrt(PrimaryDot.Area / pi);
           max_allowed_px_spacing = (Real_Spacing_Inches / W_real_inches) * est_dot_diam_px * 2.5;

           validBoardDots = 1; % PrimaryDot itself
           for k = 2:length(SortedTargets)
               if norm(SortedTargets(k).Centroid - PrimaryDot.Centroid) <= max_allowed_px_spacing
                   validBoardDots = validBoardDots + 1;
               end
           end

           if validBoardDots >= 3
               confirmations = confirmations + 1;
           end
       end

       if f < numFrames
           pause(frameInterval);
       end
   end

   % Release camera immediately
   clear cam;

   % Require unanimous confirmation across all frames to prevent false positives
   goalDetected = (confirmations == numFrames);

   if goalDetected
       fprintf('Verification PASSED: 3rd fiducial confirmed (%d/%d frames).\n', confirmations, numFrames);
   else
       fprintf('Verification FAILED: 3rd fiducial not confirmed (%d/%d frames).\n', confirmations, numFrames);
   end
end
