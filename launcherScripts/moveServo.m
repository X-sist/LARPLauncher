function moveServo(distanceInches, aimServo, movementLimits)
    % Convert distance in inches to the calibrated servo position.
    if nargin < 3
        movementLimits = [0.1, 0.6];
    end
    validateattributes(distanceInches, {'numeric'}, {'real', 'finite', 'scalar', 'nonnegative'});
    validateattributes(movementLimits, {'numeric'}, ...
        {'real', 'finite', 'vector', 'numel', 2, '>=', 0, '<=', 1, 'nondecreasing'});

    position = -0.00005 * distanceInches^2 + 0.0072 * distanceInches + 0.247;
    position = max(movementLimits(1), min(movementLimits(2), position));
    writePosition(aimServo, position);
    fprintf('[Aim] Distance %.2f in -> servo position %.3f.\n', distanceInches, position);
end
