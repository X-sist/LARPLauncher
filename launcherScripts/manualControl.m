function manualControl(aimServo, firingServo, stepper, a, fireButton, settings)
    % Aim with the direction buttons and return after firing one ball.
    aimPosition = readPosition(aimServo);
    previousDirection = 0;
    clock = tic;
    nextAimAt = 0;
    stopStepper = onCleanup(@() stepper.stoprun());
    stopFireCapture = onCleanup(@() fireButton.enableCapture(false));
    stepper.setSpeed(0);
    stepper.startrunSpeed();
    fireButton.enableCapture(true);
    disp('[Player] Hold a direction to aim. Release Fire, then press it to shoot.');
    reportedReady = false;

    while true
        % The Arduino latches taps that finish between MATLAB reads.
        [newShots, ~, ready] = fireButton.takePresses();
        if newShots > 0
            fireButton.enableCapture(false);
            stepper.stoprun();
            disp('[Player] Fresh Fire press accepted. Shooting.');
            fireBall(firingServo, settings);
            return
        end
        if ready && ~reportedReady
            disp('[Player] READY: press Fire once to shoot.');
            reportedReady = true;
        end

        left = readDigitalPin(a, settings.buttonPins{1}) == settings.pressedValue;
        up = readDigitalPin(a, settings.buttonPins{2}) == settings.pressedValue;
        down = readDigitalPin(a, settings.buttonPins{4}) == settings.pressedValue;
        right = readDigitalPin(a, settings.buttonPins{5}) == settings.pressedValue;

        direction = double(right) - double(left);
        if direction ~= previousDirection
            stepper.setSpeed(direction * settings.stepperSpeed);
            previousDirection = direction;
        end

        aimDirection = double(up) - double(down);
        nextPosition = aimPosition + aimDirection * settings.aimStep;
        nextPosition = max(settings.movementLimits(1), min(settings.movementLimits(2), nextPosition));
        if toc(clock) >= nextAimAt && nextPosition ~= aimPosition
            writePosition(aimServo, nextPosition);
            aimPosition = nextPosition;
            nextAimAt = toc(clock) + settings.aimPause;
        end
        pause(settings.loopPause);
    end
end
