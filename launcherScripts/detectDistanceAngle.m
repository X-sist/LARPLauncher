function [distance, angle] = detectDistanceAngle(cameraInput)
% ACQUIRETARGET Captures a frame, locates the target fiducials, and returns:
%   midAngle        - Center angle of the target in degrees (+ Left, - Right)
%   Distance_meters - Calculated distance to the target in meters
% Returns [NaN, NaN] if no valid target is found.

% ====================================================================
% HARDWARE & SETUP CONSTANTS
% ====================================================================
f_x = 670.0;                 % Calibrated focal length (pixels)
Real_Spacing_Inches = 7.75;  % Known physical diagonal between fiducials
W_real_inches = 1;        % Single fiducial diameter (~1.57 in)
Max_Expected_Dots = 2;
Center_X = 640 / 2;
% ====================================================================

% Capture live frame and release camera immediately
cam = cameraInput;
pause(2);
Im = snapshot(cam);
% clear cam;

% Run shared vision pipeline
SortedTargets = detectFiducials(Im);

if isempty(SortedTargets)
    warning('acquireTarget:NoTarget', 'No targets detected in frame.');
    angle = NaN;
    distance = NaN;
    return;
end

% Cap to maximum expected fiducials
if length(SortedTargets) > Max_Expected_Dots
    SortedTargets = SortedTargets(1:Max_Expected_Dots);
end

% Spatial Outlier Filter: Only keep dots within a physically plausible
% distance of the strongest green fiducial (blocks distant room glare)
PrimaryDot = SortedTargets(1);
est_dot_diam_px = 2 * sqrt(PrimaryDot.Area / pi);
max_allowed_px_spacing = (Real_Spacing_Inches / W_real_inches) * est_dot_diam_px * 2.5;

keep_mask = true(1, length(SortedTargets));
for k = 2:length(SortedTargets)
    d = norm(SortedTargets(k).Centroid - PrimaryDot.Centroid);
    if d > max_allowed_px_spacing
        keep_mask(k) = false;
    end
end
ValidTargets = SortedTargets(keep_mask);
NumTargets = length(ValidTargets);

% --- 1. DISTANCE CALCULATION ---
max_pixel_spacing = 0;
if NumTargets >= 2
    for i = 1:NumTargets
        for j = (i+1):NumTargets
            dist = norm(ValidTargets(j).Centroid - ValidTargets(i).Centroid);
            if dist > max_pixel_spacing
                max_pixel_spacing = dist;
            end
        end
    end
end

if max_pixel_spacing > 0
    Real_Spacing_Meters = Real_Spacing_Inches * 0.0254;
    distance = (Real_Spacing_Meters * f_x) / max_pixel_spacing;
else
    W_real_meters = W_real_inches * 0.0254;
    distance = (W_real_meters * f_x) / est_dot_diam_px;
end

% --- 2. MIDPOINT ANGLE CALCULATION (+ Left, - Right) ---
centroids = vertcat(ValidTargets.Centroid);
xs = centroids(:, 1);

% Compute angle of each valid fiducial, then take the exact midpoint
fiducial_angles = atand((Center_X - xs) / f_x);
angle = (min(fiducial_angles) + max(fiducial_angles)) / 2;

fprintf('Target Acquired (%d dots) -> Midpoint Angle: %+.2f deg | Distance: %.3f m (%.2f in)\n', ...
    NumTargets, angle, distance, distance / 0.0254);
end
