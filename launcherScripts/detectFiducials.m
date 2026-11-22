function SortedTargets = detectFiducials(Im)
% DETECTFIDUCIALS Isolates green circular fiducials using HSV, ExG, Top-Hat,
% and shape/solidity gating. Returns a struct array sorted by greenness.

% Crop to 640x480
rect = [0, 0, 640, 480];
ImC = imcrop(Im, rect);

% Pre-Processing & Reflection-Resistant Color Gating
ImD = im2double(ImC);
I_Red   = ImD(:,:,1);
I_Green = ImD(:,:,2);
I_Blue  = ImD(:,:,3);

ExG = 2*I_Green - I_Red - I_Blue;

hsv = rgb2hsv(ImD);
H = hsv(:,:,1);
S = hsv(:,:,2);
V = hsv(:,:,3);

hue_min = 0.22;
hue_max = 0.45;
sat_min = 0.30;
val_min = 0.20;
val_max = 0.97;

green_dominance = I_Green > (1.25 * I_Red);

green_mask = (H >= hue_min) & (H <= hue_max) & ...
    (S >= sat_min) & (V >= val_min) & (V <= val_max) & ...
    green_dominance & ...
    (ExG > 0.20);

% PASS 1: Dynamic Strel Sizing
rough_clean = bwareafilt(green_mask, [3, 15000]);
rough_stats = regionprops(rough_clean, 'Area');

if ~isempty(rough_stats)
    max_rough_area = max([rough_stats.Area]);
    dynamic_radius = max(10, round(sqrt(max_rough_area / pi) * 1.5));
else
    dynamic_radius = 10;
end

% PASS 2: Contrast Boost (Top-Hat Filtering)
se = strel('disk', dynamic_radius);
ExG_normalized = mat2gray(ExG);
tophat_peaks = imtophat(ExG_normalized, se);

combined_metric = tophat_peaks .* double(green_mask);
BW = combined_metric > 0.22;

BW = imclose(BW, strel('disk', 1));
BW = imfill(BW, 'holes');

% Size & Shape Filtering
BW_clean = bwareafilt(BW, [4, 15000]);

stats = regionprops(BW_clean, ExG, ...
    'BoundingBox', 'Centroid', 'Area', 'Eccentricity', 'Solidity', 'MeanIntensity');

if isempty(stats)
    SortedTargets = [];
    return;
end

valid_idx = ([stats.Eccentricity] < 0.78) & ([stats.Solidity] > 0.75);
TargetDots = stats(valid_idx);

if isempty(TargetDots)
    SortedTargets = [];
    return;
end

% Sort by strongest green peak descending
[~, sortIdx] = sort([TargetDots.MeanIntensity], 'descend');
SortedTargets = TargetDots(sortIdx);
end