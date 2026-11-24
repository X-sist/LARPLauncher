function moveStepper(angle, stepper, stepsPerRevolution)
    % Aim at an absolute heading measured by the stationary camera.
    % Position zero must face the camera's center direction at startup.
    % Default assumes a 28BYJ-48 in FULL4WIRE mode with direct drive.
    if nargin < 3
        stepsPerRevolution = 2048;
    end
    validateattributes(angle, {'numeric'}, {'real', 'finite', 'scalar'});
    validateattributes(stepsPerRevolution, {'numeric'}, {'real', 'finite', 'scalar', 'positive'});

    % Camera angles are positive left; positive motor steps turn right.
    targetSteps = round(-angle * stepsPerRevolution / 360);
    stepper.stoprun();
    stopStepper = onCleanup(@() stepper.stoprun());

    % Manual runSpeed() movement leaves the old automatic target behind.
    % Reset the planner at the SAME coordinate, preserving the startup zero.
    % This also forces moveTo() to prepare motion when revisiting an old target.
    currentSteps = double(stepper.currentPosition());
    stepper.setCurrentPosition(currentSteps);

    speed = double(stepper.maxSpeed());
    validateattributes(speed, {'numeric'}, {'real', 'finite', 'scalar', 'positive'});
    acceleration = speed;
    stepper.setAcceleration(acceleration);
    stepper.moveTo(targetSteps);
    remainingSteps = abs(double(stepper.distanceToGo()));
    if remainingSteps == 0
        return;
    end
    fprintf('[Aim] Stepper position %d -> %d (%d steps), max speed %.1f steps/s.\n', ...
        currentSteps, targetSteps, remainingSteps, speed);
    stepper.startrun();

    % Wait for aiming to finish before allowing the CPU to fire.
    % Include acceleration/deceleration and allow for Arduino/USB overhead.
    timeout = 2 * (remainingSteps / speed + speed / acceleration) + 5;
    clock = tic;
    remaining = double(stepper.distanceToGo());
    while remaining ~= 0
        if toc(clock) > timeout
            error('moveStepper:Timeout', ...
                ['Stepper did not finish aiming within %.1f seconds. ' ...
                 'Start: %d, target: %d, reported position: %d, remaining: %d, ' ...
                 'reported speed: %.2f steps/s.'], ...
                timeout, currentSteps, targetSteps, targetSteps - remaining, ...
                remaining, double(stepper.speed()));
        end
        pause(0.05);
        remaining = double(stepper.distanceToGo());
    end
    fprintf('[Aim] Fixed-camera angle %+.2f deg -> absolute position %d steps.\n', angle, targetSteps);
end
