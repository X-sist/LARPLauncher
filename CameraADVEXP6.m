% Close range targeting needs the top hat filter to be adjusted, as well as
% the focal length. 

%% MAIN VISION & TARGETING SCRIPT
close all; clear; clc;

% ====================================================================
% 1. HARDWARE & SETUP CONSTANTS (Set these once during setup)
% ====================================================================
% Calculate once: f_x = (Known_Distance_Inches * Pixel_Spacing) / Real_Spacing_Inches
f_x = 696.0; 

% The physical diagonal distance between the fiducials on your board
Real_Spacing_Inches = 10.0; % Adjust to match your real board

% Single fiducial physical diameter
W_real_inches = (pi/4); 
% ====================================================================



% read in the image (Change between your close and far test images)
% Im = imread('im100in.jpeg');

% %% Read Image / Live Capture
% % --- MODULAR LIVE CAMERA CAPTURE ---
% % Uncomment this block to use live video instead of a static image
cam = webcamlist;        % Display available cameras in command window
cam = webcam(1);         % Adjust index based on your connected cameras
pause(2);                % Allow camera sensor to adjust to lighting/exposure
Im = snapshot(cam);      % Capture live frame
clear cam;               % Release camera immediately to free memory
% % -------------------------------------

%% Crop The Image
x1 = 0; y1 = 0; 
x2 = 640; y2 = 480; 
rect = [x1, y1, x2 - x1, y2 - y1];
ImC = imcrop(Im, rect);

%% Pre-Processing: Noise Reduction and Lighting Normalization
ImD = im2double(ImC);

% Convert to HSV and apply CLAHE to the Value (brightness) channel 
% to normalize shadows and harsh lighting gradients.
hsv = rgb2hsv(ImD);
H = hsv(:,:,1); 
S = hsv(:,:,2); 
V = adapthisteq(hsv(:,:,3), 'NumTiles', [8 8], 'ClipLimit', 0.01); 

% Reconstruct normalized RGB for Excess Green calculation
ImD_Norm = hsv2rgb(cat(3, H, S, V));
I_Red = ImD_Norm(:,:,1);
I_Green = ImD_Norm(:,:,2);
I_Blue = ImD_Norm(:,:,3);

% Excess Green
ExG = 2*I_Green - I_Red - I_Blue;

% Refined HSV color space gating based on normalized lighting
hue_min = 0.22; 
hue_max = 0.45; 
sat_min = 0.15; 
val_min = 0.15; 

green_mask = (H >= hue_min) & (H <= hue_max) & ...
             (S >= sat_min) & (V >= val_min) & ...
             (ExG > 0.15); % Slightly lowered ExG threshold due to CLAHE

%% PASS 1: Dynamic Strel Sizing
% Find the rough area of the largest green blob without top-hat filtering
rough_clean = bwareafilt(green_mask, [3, 15000]);
rough_stats = regionprops(rough_clean, 'Area');

if ~isempty(rough_stats)
    max_rough_area = max([rough_stats.Area]);
    % Calculate estimated radius and scale by 1.5x to ensure the top-hat 
    % clears the entire fiducial. Enforce a minimum radius of 10.
    dynamic_radius = max(10, round(sqrt(max_rough_area / pi) * 1.5));
else
    dynamic_radius = 10; % Fallback
end

fprintf('Dynamic Strel Radius Set To: %d px\n', dynamic_radius);

%% PASS 2: Contrast Boost for Small Distant Points (Top-Hat Filtering)
se = strel('disk', dynamic_radius); 
ExG_normalized = mat2gray(ExG);
tophat_peaks = imtophat(ExG_normalized, se);

combined_metric = tophat_peaks .* double(green_mask);
BW = combined_metric > 0.20; 

% Morphological closing to snap blurry/broken edges together
BW = imclose(BW, strel('disk', 2));
BW = imfill(BW, 'holes');

%% Size & Shape Filtering
min_pixel_size = 3;
max_pixel_size = 15000;
BW_clean = bwareafilt(BW, [min_pixel_size, max_pixel_size]);

%% Extract Candidates & Bounding Boxes
stats = regionprops(BW_clean, 'BoundingBox', 'Centroid', 'Area', 'Eccentricity');
valid_idx = [stats.Eccentricity] < 0.90;
TargetDots = stats(valid_idx);

%% Target Sorting and Grouping
NumTargets = length(TargetDots);
TargetFound = NumTargets > 0;

if TargetFound
    % Sort targets by Area descending to prioritize the clearest fiducials
    [~, sortIdx] = sort([TargetDots.Area], 'descend');
    SortedTargets = TargetDots(sortIdx);
    
    % Primary target for panning/targeting logic (Largest dot)
    PrimaryDot = SortedTargets(1);
    BoxInfo = PrimaryDot.BoundingBox;
    Spotx = PrimaryDot.Centroid(1);
    Spoty = PrimaryDot.Centroid(2);
else
    disp('CRITICAL: No targets detected in frame.');
end

%% Visualization
figure('Position', [100, 100, 1000, 500]);
subplot(1, 2, 1);
imshow(combined_metric, []);
title('Filtered Response Map');

subplot(1, 2, 2);
imshow(ImC);
hold on;
if TargetFound
    for k = 1:NumTargets
        bb = SortedTargets(k).BoundingBox;
        rectangle('Position', bb, 'EdgeColor', 'r', 'LineWidth', 1.5);
        plot(SortedTargets(k).Centroid(1), SortedTargets(k).Centroid(2), 'g+', 'MarkerSize', 8, 'LineWidth', 2);
    end
    title(sprintf('Detections: %d Target(s) Acquired', NumTargets));
else
    title('Detections: 0');
end
hold off;

tableOfProp = regionprops('table',BW_clean, 'BoundingBox');

%% Determining the Target Coordinates and Dynamic Distance Calculation
if TargetFound
    
    % ====================================================================
    % CALIBRATED FOCAL LENGTH
    % Replace this value using the math formula provided above once you 
    % measure your 118-inch baseline. (Roughly estimated here as ~660 or 696).
    f_x = 696.0;  
    % ====================================================================
    
    Center_X = 640 / 2;
    
    if NumTargets >= 2
        % --- MULTI-TARGET MODE (Finds the max diagonal distance) ---
        max_pixel_spacing = 0;
        
        % Iterate through all pairs to find the largest centroid gap
        for i = 1:NumTargets
            for j = (i+1):NumTargets
                C1 = SortedTargets(i).Centroid;
                C2 = SortedTargets(j).Centroid;
                dist = sqrt((C2(1) - C1(1))^2 + (C2(2) - C1(2))^2);
                if dist > max_pixel_spacing
                    max_pixel_spacing = dist;
                end
            end
        end
        
        Real_Spacing_Inches = 10; % The known physical diagonal Default:10
        Real_Spacing_Meters = Real_Spacing_Inches * 0.0254;
        
        Distance_meters = (Real_Spacing_Meters * f_x) / max_pixel_spacing;
        fprintf('Multi-Target Mode Active (%d dots).\n', NumTargets);
        fprintf('Max Pixel Spacing (Diagonal): %.2f px\n', max_pixel_spacing);
        fprintf('Calculated Distance: %.3f meters (%.2f inches)\n', Distance_meters, Distance_meters / 0.0254);
        
    else
        % --- SINGLE-TARGET MODE (Fallback for 1 dot) ---
        W_real_inches = (pi/4); % 1.57 inches
        W_real_meters = W_real_inches * 0.0254;
        
        TargetArea = PrimaryDot.Area;
        W_pixel_sub = 2 * sqrt(TargetArea / pi);
        
        Distance_meters = (W_real_meters * f_x) / W_pixel_sub;
        fprintf('Single-Target Mode Active (1 dot).\n');
        fprintf('Calculated Sub-Pixel Width: %.2f px\n', W_pixel_sub);
        fprintf('Calculated Distance: %.3f meters (%.2f inches)\n', Distance_meters, Distance_meters / 0.0254);
    end


    % ====================================================================
    % INDIVIDUAL FIDUCIAL ANGLE CALCULATION
    % Convention: Camera Center = 0 deg, Left = Positive (+), Right = Negative (-)
    % ====================================================================
    fprintf('\n--- Fiducial Angles (From Camera Center) ---\n');

    % Initialize array to store angles if you need them for downstream kinematics
    Fiducial_Angles_deg = zeros(1, NumTargets); 

    for k = 1:NumTargets
        % Extract the X-coordinate of the current fiducial's centroid
        Target_X = SortedTargets(k).Centroid(1);

        % Calculate pixel delta
        % Center_X (320) - Target_X flips the sign so Left is + and Right is -
        Delta_X = Center_X - Target_X; 

        % Calculate angle using inverse tangent (atand returns degrees)
        angle_deg = atand(Delta_X / f_x);

        % Store and display
        Fiducial_Angles_deg(k) = angle_deg;
        fprintf('Fiducial %d: %+.2f degrees\n', k, angle_deg);
    end

    % If using the Primary Dot (largest) to drive the stepper motor:
    Primary_Angle = Fiducial_Angles_deg(1);
    
    % --> PASTE KINEMATICS/MOVEMENT BLOCK HERE <--
    % Use Spotx for pan/stepper, and Distance_meters for tilt/servo
end