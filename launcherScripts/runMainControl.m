function runMainControl(cameraInput)
    port = '/dev/cu.usbmodemACA70432EE782';
    stepperPins = {'A1', 'A2', 'A3', 'A4'}; % Driver IN1, IN2, IN3, IN4
    registerPins = {'D2', 'D3', 'D4'}; % 74HC595 data, clock, latch
    settings.buttonPins = {'D5', 'D6', 'D7', 'D8', 'D11'};
    buttonNames = {'Left', 'Up', 'Fire', 'Down', 'Right'};
    usePullups = false;

    settings.stepperSpeed = 100;
    settings.aimStep = 0.030;
    settings.aimPause = 0.02;
    settings.movementLimits = [0, 1];
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
    stepper.setMaxSpeed(settings.stepperSpeed);
    stepper.setSpeed(0);

    aimServo = servo(a, 'D12', 'MinPulseDuration', 700e-6, 'MaxPulseDuration', 2300e-6);
    firingServo = servo(a, 'D13', 'MinPulseDuration', 700e-6, 'MaxPulseDuration', 2300e-6);
    resetFiringServo = onCleanup(@() writePosition(firingServo, settings.fireHome));
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
        fprintf('[Setup] %s button on %s, mode %s.\n', buttonNames{index}, pin, inputMode);
        configurePin(a, pin, inputMode);
    end
    fireButton = addon(a, 'FireButton/FireButton', settings.buttonPins{3}, settings.pressedValue);
    stopFireCapture = onCleanup(@() fireButton.enableCapture(false));

    
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
            disp('[Player] Hold a direction to aim. Tap Fire to shoot.');
            manualControl(aimServo, firingServo, stepper, a, fireButton, settings);
        
        else
            disp('[CPU] Tap Fire to detect and aim.');
            
            waitForFireButtonPress(fireButton, settings.loopPause);
            
            [distance, angle] = detectDistanceAngle(cameraInput);
            
            moveServo(distance, aimServo);
            moveStepper(angle, stepper);
            
            disp('[CPU] Tap Fire again to shoot.');
            waitForFireButtonPress(fireButton, settings.loopPause);
            fireBall(firingServo, settings);
        end



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
