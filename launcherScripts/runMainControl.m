function runMainControl(cameraInput)
    port = '/dev/cu.usbmodemACA70432EE782';
    stepperPins = {'A1', 'A2', 'A3', 'A4'}; % Driver IN1, IN2, IN3, IN4
    registerPins = {'D2', 'D3', 'D4'}; % 74HC595 data, clock, latch
    settings.buttonPins = {'D5', 'D6', 'D7', 'D8', 'D11'};
    buttonNames = {'Left', 'Up', 'Fire', 'Down', 'Right'};
    usePullups = false; % Direction buttons retain their existing input mode.
    settings.firePressedValue = 1; % Fire connects D7 to 5V; external pull-down holds it LOW when released.

    settings.stepperSpeed = 100;
    settings.stepperStepsPerRevolution = 2048; % Calibrate for the launcher's gearing.
    settings.aimStep = 0.030;
    settings.aimPause = 0.02;
    settings.movementLimits = [0.1, 0.6];
    settings.fireHome = 1;
    settings.firePosition = 0;
    settings.fireDwell = 0.30;
    settings.fireReturnTime = 0.30;
    settings.loopPause = 0.005;
    startupLedPause = 0.2;
    winningScore = 3;
    goalDetectionTime = 5; % Integer number of seconds for future detection logic.

    previousPauseState = pause('on');
    restorePause = onCleanup(@() pause(previousPauseState));
    fprintf('[Setup] Connecting to Uno R4 WiFi on %s and refreshing the Arduino server.\n', port);
    a = arduino(port, 'UnoR4Wifi', ...
        'Libraries', {'Servo', 'AccelStepperAddon/AccelStepperAddon', 'ShiftRegister', ...
                      'FireButton/FireButton'}, ...
        'ForceBuildOn', true);

    % Use the same IN1, IN3, IN2, IN4 coil order as stepperScript.m.
    stepper = addon(a, 'AccelStepperAddon/AccelStepperAddon', stepperPins([1 3 2 4]));
    stopStepper = onCleanup(@() stepper.stoprun());
    stepper.stoprun();
    % No homing sensor: align the launcher with the fixed camera's center
    % direction before starting. Manual motor movements then retain this zero.
    stepper.setCurrentPosition(0);
    disp('[Setup] Current launcher heading recorded as zero for the fixed camera.');
    stepper.setMaxSpeed(settings.stepperSpeed);
    stepper.setSpeed(0);

    aimServo = servo(a, 'D13', 'MinPulseDuration', 700e-6, 'MaxPulseDuration', 2300e-6);
    firingServo = servo(a, 'D12', 'MinPulseDuration', 700e-6, 'MaxPulseDuration', 2300e-6);
    resetFiringServo = onCleanup(@() writePosition(firingServo, settings.fireHome));
    disp('[Setup] Centering the aiming servo and returning the firing servo home.');
    writePosition(aimServo, mean(settings.movementLimits));
    writePosition(firingServo, settings.fireHome);

    register = shiftRegister(a, '74HC595', registerPins{:});
    write(register, uint8(0), 'uint8');
    inputMode = 'DigitalInput';
    settings.pressedValue = 1;
    if usePullups
        inputMode = 'Pullup';
        settings.pressedValue = 0;
    end
    for index = 1:numel(settings.buttonPins)
        pin = settings.buttonPins{index};
        buttonInputMode = inputMode;
        if index == 3
            buttonInputMode = 'DigitalInput';
        end
        fprintf('[Setup] %s button on %s, mode %s.\n', buttonNames{index}, pin, buttonInputMode);
        configurePin(a, pin, buttonInputMode);
    end
    fireButton = addon(a, 'FireButton/FireButton', settings.buttonPins{3}, settings.firePressedValue);
    stopFireCapture = onCleanup(@() fireButton.enableCapture(false));
    [~, fireLevel] = fireButton.takePresses(); % Also checks the firmware protocol.
    fprintf('[Setup] Fire D7 reads %d. Active-HIGH: released = 0, pressed = 1.\n', fireLevel);

    
    scores = [0, 0]; % Player, CPU
    currentPlayer = 1;
    
    
    
    disp('[Setup] LED test starting. Watch the two alternating patterns.');
    for pattern = [170, 85, 170, 85]
        write(register, pattern);
        pause(startupLedPause);
    end
    updateLEDs(register, scores, currentPlayer);

    
    
    
    while true
        
        
        if currentPlayer == 1
            manualControl(aimServo, firingServo, stepper, a, fireButton, settings);
        
        else
            waitForFireButtonPress(fireButton, settings.loopPause, '[CPU: aim]');
            disp('[CPU] Aiming confirmed. Fire is inactive until aiming finishes.');
            
            [distance, angle] = detectDistanceAngle(cameraInput);
            if ~isscalar(distance) || ~isscalar(angle) || ...
                    ~isfinite(distance) || ~isfinite(angle) || distance <= 0
                disp('[CPU] No valid target. Tap Fire to retry aiming.');
                continue;
            end
            
            moveServo(distance / 0.0254, aimServo, settings.movementLimits);
            moveStepper(angle, stepper, settings.stepperStepsPerRevolution);
            
            disp('[CPU] Aiming complete.');
            waitForFireButtonPress(fireButton, settings.loopPause, '[CPU: shoot]');
            disp('[CPU] Second Fire press confirmed. Shooting.');
            fireBall(firingServo, settings);
        end



        disp('[Game] Shot complete. Fire is inactive during goal verification.');
        if detectGoal(cameraInput, goalDetectionTime)
            scores = scorePoint(scores, currentPlayer);
        end





        if scores(currentPlayer) == winningScore
            celebrateWin(register, scores, currentPlayer);
            scores = [0, 0];
            currentPlayer = 1;
        else
            currentPlayer = changePlayer(currentPlayer);
        end
        
        
        
        updateLEDs(register, scores, currentPlayer);
    end
end
